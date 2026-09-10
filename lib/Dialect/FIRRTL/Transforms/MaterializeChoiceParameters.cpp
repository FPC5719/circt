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
      continue;
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
  FailureOr<Attribute> resolveChoice(Value value, FModuleOp containingModule,
                                     SymbolTableCollection &symbols);
  void fail(Operation *op, const Twine &message) {
    op->emitOpError(message);
    signalPassFailure();
  }

  DenseMap<FModuleOp, SmallVector<ChoiceParameter>> moduleParameters;
};

FailureOr<Attribute> MaterializeChoiceParametersPass::resolveChoice(
    Value value, FModuleOp containingModule, SymbolTableCollection &symbols) {
  if (auto constant = value.getDefiningOp<ChoiceConstantOp>())
    return getChoiceValue(constant, symbols);

  auto argument = dyn_cast<BlockArgument>(value);
  if (!argument || argument.getOwner() != containingModule.getBodyBlock())
    return failure();

  for (auto parameter : moduleParameters[containingModule])
    if (parameter.port == argument.getArgNumber())
      return ParamDeclRefAttr::get(parameter.name, parameter.type);
  return failure();
}

void MaterializeChoiceParametersPass::runOnOperation() {
  auto circuit = getOperation();
  SymbolTableCollection symbols;

  // First turn every choice input port into a formal parameter declaration.
  for (auto module : circuit.getOps<FModuleOp>()) {
    SmallVector<Attribute> parameters(module.getParameters().begin(),
                                      module.getParameters().end());
    for (auto [index, port] : llvm::enumerate(module.getPorts())) {
      auto choiceType = dyn_cast<ChoiceType>(port.type);
      if (!choiceType)
        continue;
      if (port.direction != Direction::In) {
        fail(module, "choice parameters must be input ports");
        return;
      }
      auto domain = symbols.lookupNearestSymbolFrom<ChoiceDomainOp>(
          module, choiceType.getDomain());
      if (!domain) {
        fail(module, "choice parameter references an unknown choice domain");
        return;
      }
      auto integerType = IntegerType::get(&getContext(), domain.getWidth());
      auto name = module.getPortNameAttr(index);
      parameters.push_back(ParamDeclAttr::get(name, integerType));
      moduleParameters[module].push_back(
          ChoiceParameter{name, integerType, static_cast<unsigned>(index)});
    }
    module.setParametersAttr(ArrayAttr::get(&getContext(), parameters));
  }

  // Translate instance property assignments to parameter actuals.  This must
  // happen before removing the property results from the instances.
  for (auto containingModule : circuit.getOps<FModuleOp>()) {
    SmallVector<InstanceOp> instances;
    containingModule.walk(
        [&](InstanceOp instance) { instances.push_back(instance); });
    for (auto instance : instances) {
      auto target = symbols.lookupNearestSymbolFrom<FModuleOp>(
          instance, instance.getModuleNameAttr());
      if (!target)
        continue;
      auto targetParameters = moduleParameters.lookup(target);
      if (targetParameters.empty())
        continue;

      SmallVector<Attribute> actuals;
      for (auto parameter : targetParameters) {
        auto property =
            dyn_cast<FIRRTLPropertyValue>(instance.getResult(parameter.port));
        auto assignment =
            property ? getUniquePropertyAssignment(property) : PropAssignOp();
        if (!assignment) {
          fail(instance, "choice parameter input must have exactly one "
                         "firrtl.propassign assignment");
          return;
        }
        auto value =
            resolveChoice(assignment.getSrc(), containingModule, symbols);
        if (failed(value)) {
          fail(assignment, "choice parameter must be driven by a choice "
                           "constant or containing-module choice parameter");
          return;
        }
        actuals.push_back(ParamDeclAttr::get(&getContext(), parameter.name,
                                             parameter.type, *value));
        assignment.erase();
      }
      instance->setAttr("parameters", ArrayAttr::get(&getContext(), actuals));
    }

    auto walkResult = containingModule.walk([&](ParamInstanceChoiceOp choice) {
      auto selector = choice.getSelector();
      auto value = resolveChoice(selector, containingModule, symbols);
      if (failed(value)) {
        fail(choice, "selector must be a choice constant or containing-module "
                     "choice parameter");
        return WalkResult::interrupt();
      }
      auto domain = selector.getType().getDomain();
      auto domainOp =
          symbols.lookupNearestSymbolFrom<ChoiceDomainOp>(choice, domain);
      auto integerType = IntegerType::get(&getContext(), domainOp.getWidth());
      choice->setOperands({});
      choice.setSelectorParameterAttr(ParamDeclAttr::get(
          &getContext(), StringAttr::get(&getContext(), "selector"),
          integerType, *value));
      return WalkResult::advance();
    });
    if (walkResult.wasInterrupted())
      return;
  }

  // Remove the now-materialized ports and the corresponding instance results.
  for (auto module : circuit.getOps<FModuleOp>()) {
    auto parameters = moduleParameters.lookup(module);
    if (parameters.empty())
      continue;
    BitVector ports(module.getNumPorts());
    for (auto parameter : parameters)
      ports.set(parameter.port);

    SmallVector<InstanceOp> users;
    circuit.walk([&](InstanceOp instance) {
      if (instance.getModuleName() == module.getModuleNameAttr())
        users.push_back(instance);
    });
    for (auto instance : users) {
      (void)instance.cloneWithErasedPortsAndReplaceUses(ports);
      instance.erase();
    }
    module.erasePorts(ports);
  }

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

} // namespace
