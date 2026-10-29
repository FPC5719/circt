//===- MaterializeChoiceParameters.cpp - Materialize choice parameters ---===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "circt/Dialect/FIRRTL/FIRRTLOps.h"
#include "circt/Dialect/FIRRTL/FIRRTLUtils.h"
#include "circt/Dialect/FIRRTL/Passes.h"
#include "mlir/IR/SymbolTable.h"

namespace circt {
namespace firrtl {
#define GEN_PASS_DEF_MATERIALIZECHOICEPARAMETERS
#include "circt/Dialect/FIRRTL/Passes.h.inc"
} // namespace firrtl
} // namespace circt

using namespace circt;
using namespace firrtl;
using namespace mlir;

namespace {

struct ChoiceParameter {
  StringAttr name;
  IntegerType type;
  unsigned port;
};

struct ModuleRewrite {
  SmallVector<Attribute> parameters;
  SmallVector<ChoiceParameter> choiceParameters;
  BitVector portsToErase;
};

struct InstanceRewrite {
  FInstanceLike instance;
  SmallVector<Attribute> parameters;
  BitVector portsToErase;
  SmallVector<PropAssignOp> assignments;
  ParamDeclAttr selectorParameter;
};

static FailureOr<IntegerAttr> getChoiceValue(ChoiceConstantOp constant,
                                             SymbolTableCollection &symbols) {
  auto caseRef = constant.getCaseSymbol();
  auto domain = symbols.lookupNearestSymbolFrom<ChoiceDomainOp>(
      constant, FlatSymbolRefAttr::get(caseRef.getRootReference()));
  if (!domain)
    return failure();
  auto choiceCase =
      symbols.lookupNearestSymbolFrom<ChoiceCaseOp>(constant, caseRef);
  if (!choiceCase)
    return failure();
  auto type = IntegerType::get(constant.getContext(), domain.getWidth());
  return IntegerAttr::get(type, choiceCase.getValue());
}

static PropAssignOp getUniquePropertyAssignment(FIRRTLPropertyValue value) {
  PropAssignOp assignment;
  for (auto *user : value.getUsers()) {
    auto propassign = dyn_cast<PropAssignOp>(user);
    if (!propassign || propassign.getDest() != value)
      return {};
    if (assignment)
      return {};
    assignment = propassign;
  }
  return assignment;
}

struct MaterializeChoiceParametersPass
    : public firrtl::impl::MaterializeChoiceParametersBase<
          MaterializeChoiceParametersPass> {
  using Base::Base;

  void runOnOperation() override;

private:
  LogicalResult analyzeModules(CircuitOp circuit,
                               SymbolTableCollection &symbols);
  LogicalResult analyzeInstances(CircuitOp circuit,
                                 SymbolTableCollection &symbols);
  LogicalResult analyzeInstance(FInstanceLike instance,
                                SymbolTableCollection &symbols);
  LogicalResult applyInstanceRewrites();
  LogicalResult eraseModulePorts(CircuitOp circuit);
  void cleanup(CircuitOp circuit);
  FailureOr<Attribute> resolveChoice(Value value, FModuleOp containingModule,
                                     SymbolTableCollection &symbols);
  LogicalResult fail(Operation *op, const Twine &message) {
    op->emitOpError(message);
    return failure();
  }

  DenseMap<FModuleOp, ModuleRewrite> moduleRewrites;
  SmallVector<InstanceRewrite> instanceRewrites;
};

FailureOr<Attribute> MaterializeChoiceParametersPass::resolveChoice(
    Value value, FModuleOp containingModule, SymbolTableCollection &symbols) {
  if (auto constant = value.getDefiningOp<ChoiceConstantOp>())
    return getChoiceValue(constant, symbols);

  auto argument = dyn_cast<BlockArgument>(value);
  if (!argument || argument.getOwner() != containingModule.getBodyBlock())
    return failure();

  auto moduleRewrite = moduleRewrites.find(containingModule);
  if (moduleRewrite == moduleRewrites.end())
    return failure();
  for (auto parameter : moduleRewrite->second.choiceParameters)
    if (parameter.port == argument.getArgNumber())
      return ParamDeclRefAttr::get(parameter.name, parameter.type);
  return failure();
}

LogicalResult MaterializeChoiceParametersPass::analyzeModules(
    CircuitOp circuit, SymbolTableCollection &symbols) {
  for (auto module : circuit.getOps<FModuleOp>()) {
    ModuleRewrite rewrite;
    rewrite.parameters.append(module.getParameters().begin(),
                              module.getParameters().end());
    rewrite.portsToErase.resize(module.getNumPorts());
    for (auto [index, port] : llvm::enumerate(module.getPorts())) {
      auto choiceType = dyn_cast<ChoiceType>(port.type);
      if (!choiceType)
        continue;
      if (port.direction != Direction::In)
        return fail(module, "choice parameters must be input ports");
      auto domain = symbols.lookupNearestSymbolFrom<ChoiceDomainOp>(
          module, choiceType.getDomain());
      if (!domain)
        return fail(module,
                    "choice parameter references an unknown choice domain");
      auto integerType = IntegerType::get(&getContext(), domain.getWidth());
      auto name = module.getPortNameAttr(index);
      if (llvm::any_of(rewrite.parameters, [&](Attribute parameter) {
            return cast<ParamDeclAttr>(parameter).getName() == name;
          }))
        return fail(module, "choice parameter conflicts with an existing "
                            "module parameter");
      rewrite.parameters.push_back(ParamDeclAttr::get(name, integerType));
      rewrite.choiceParameters.push_back(
          ChoiceParameter{name, integerType, static_cast<unsigned>(index)});
      rewrite.portsToErase.set(index);
    }
    if (!rewrite.choiceParameters.empty())
      moduleRewrites.try_emplace(module, std::move(rewrite));
  }
  return success();
}

LogicalResult MaterializeChoiceParametersPass::analyzeInstance(
    FInstanceLike instance, SymbolTableCollection &symbols) {
  InstanceRewrite rewrite{instance};
  const ModuleRewrite *targetRewrite = nullptr;

  // A parameterized instance choice can reference multiple targets.  The
  // instance-graph verifier already requires matching target signatures, so
  // check the materialized parameter portions as well and use one port-erasure
  // vector for the operation.
  for (auto moduleNameAttr : instance.getReferencedModuleNamesAttr()) {
    auto moduleName = cast<StringAttr>(moduleNameAttr);
    auto target = symbols.lookupNearestSymbolFrom<FModuleOp>(
        instance, FlatSymbolRefAttr::get(moduleName));
    if (!target)
      continue;
    auto moduleRewrite = moduleRewrites.find(target);
    if (moduleRewrite == moduleRewrites.end())
      continue;
    auto &candidate = moduleRewrite->second;
    if (!targetRewrite) {
      targetRewrite = &candidate;
      rewrite.portsToErase = candidate.portsToErase;
      continue;
    }

    if (candidate.choiceParameters.size() !=
        targetRewrite->choiceParameters.size())
      return fail(instance, "instance choice targets have inconsistent choice "
                            "parameter signatures");
    for (auto [lhs, rhs] : llvm::zip(candidate.choiceParameters,
                                     targetRewrite->choiceParameters)) {
      if (lhs.port != rhs.port || lhs.name != rhs.name || lhs.type != rhs.type)
        return fail(instance,
                    "instance choice targets have inconsistent choice "
                    "parameter signatures");
    }
  }

  if (targetRewrite) {
    for (auto parameter : targetRewrite->choiceParameters) {
      if (parameter.port >= instance->getNumResults())
        return fail(instance, "choice parameter port is missing from instance");
      auto property =
          dyn_cast<FIRRTLPropertyValue>(instance->getResult(parameter.port));
      auto assignment =
          property ? getUniquePropertyAssignment(property) : PropAssignOp();
      if (!assignment)
        return fail(instance, "choice parameter input must have exactly one "
                              "firrtl.propassign assignment");
      auto value = resolveChoice(
          assignment.getSrc(), instance->getParentOfType<FModuleOp>(), symbols);
      if (failed(value))
        return fail(assignment,
                    "choice parameter must be driven by a choice "
                    "constant or containing-module choice parameter");
      if (cast<TypedAttr>(*value).getType() != parameter.type)
        return fail(assignment, "choice parameter actual has the wrong type");
      rewrite.parameters.push_back(ParamDeclAttr::get(
          &getContext(), parameter.name, parameter.type, *value));
      rewrite.assignments.push_back(assignment);
    }
  }

  // The selector is not a module port. Materialize it independently, even when
  // none of the referenced modules has a choice parameter.
  if (auto choice = dyn_cast<ParamInstanceChoiceOp>(instance.getOperation())) {
    if (auto selector = choice.getSelector()) {
      auto value = resolveChoice(
          selector, instance->getParentOfType<FModuleOp>(), symbols);
      if (failed(value))
        return fail(choice, "selector must be a choice constant or "
                            "containing-module choice parameter");
      auto domain = selector.getType().getDomain();
      auto domainOp =
          symbols.lookupNearestSymbolFrom<ChoiceDomainOp>(choice, domain);
      if (!domainOp)
        return fail(choice, "selector references an unknown choice domain");
      auto integerType = IntegerType::get(&getContext(), domainOp.getWidth());
      rewrite.selectorParameter = ParamDeclAttr::get(
          &getContext(), StringAttr::get(&getContext(), "selector"),
          integerType, *value);
    }
  }

  if (rewrite.portsToErase.any() || rewrite.selectorParameter)
    instanceRewrites.push_back(std::move(rewrite));
  return success();
}

LogicalResult MaterializeChoiceParametersPass::analyzeInstances(
    CircuitOp circuit, SymbolTableCollection &symbols) {
  for (auto containingModule : circuit.getOps<FModuleOp>()) {
    SmallVector<FInstanceLike> instances;
    containingModule.walk(
        [&](FInstanceLike instance) { instances.push_back(instance); });
    for (auto instance : instances)
      if (failed(analyzeInstance(instance, symbols)))
        return failure();
  }
  return success();
}

LogicalResult MaterializeChoiceParametersPass::applyInstanceRewrites() {
  for (auto &rewrite : instanceRewrites) {
    auto instance = rewrite.instance;
    if (rewrite.selectorParameter) {
      auto choice = cast<ParamInstanceChoiceOp>(instance.getOperation());
      choice->setOperands({});
      choice.setSelectorParameterAttr(rewrite.selectorParameter);
    }

    // Erasing the assignments removes all uses of erased choice results before
    // cloning, as required by cloneWithErasedPortsAndReplaceUses.
    for (auto assignment : rewrite.assignments)
      assignment.erase();

    if (rewrite.portsToErase.any()) {
      auto replacement =
          instance.cloneWithErasedPortsAndReplaceUses(rewrite.portsToErase);
      instance->erase();
      instance = replacement;
    }

    if (!rewrite.parameters.empty())
      instance->setAttr("parameters",
                        ArrayAttr::get(&getContext(), rewrite.parameters));
  }
  return success();
}

LogicalResult
MaterializeChoiceParametersPass::eraseModulePorts(CircuitOp circuit) {
  for (auto module : circuit.getOps<FModuleOp>()) {
    auto rewrite = moduleRewrites.find(module);
    if (rewrite == moduleRewrites.end())
      continue;
    module.setParametersAttr(
        ArrayAttr::get(&getContext(), rewrite->second.parameters));
    module.erasePorts(rewrite->second.portsToErase);
  }
  return success();
}

void MaterializeChoiceParametersPass::cleanup(CircuitOp circuit) {
  for (auto constant : circuit.getOps<FModuleOp>())
    constant.walk([&](ChoiceConstantOp choice) {
      if (choice.getResult().use_empty())
        choice.erase();
    });

  // Domains whose mappings are no longer needed by a parameterized instance
  // choice have no remaining FIRRTL meaning and would otherwise block the HW
  // lowering. Keep domains referenced by the materialized choice op for the
  // next phase, which still needs its case-to-target map.
  DenseSet<StringAttr> liveDomains;
  circuit.walk([&](ParamInstanceChoiceOp choice) {
    for (auto attr : choice.getCaseNamesAttr())
      liveDomains.insert(cast<SymbolRefAttr>(attr).getRootReference());
  });
  for (auto domain :
       llvm::make_early_inc_range(circuit.getOps<ChoiceDomainOp>()))
    if (!liveDomains.contains(domain.getSymNameAttr()))
      domain.erase();
}

void MaterializeChoiceParametersPass::runOnOperation() {
  auto circuit = getOperation();
  SymbolTableCollection symbols;
  moduleRewrites.clear();
  instanceRewrites.clear();

  if (failed(analyzeModules(circuit, symbols)) ||
      failed(analyzeInstances(circuit, symbols)) ||
      failed(applyInstanceRewrites()) || failed(eraseModulePorts(circuit))) {
    signalPassFailure();
    return;
  }
  cleanup(circuit);
}

} // namespace
