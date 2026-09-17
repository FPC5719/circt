//===- ChoiceOpsTest.cpp - Choice op construction tests -------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains unit tests for the public construction APIs of the
// elaboration-time choice operations: the choice domain, choice constants,
// and parameterized instance choices.
//
//===----------------------------------------------------------------------===//

#include "circt/Dialect/FIRRTL/FIRRTLAttributes.h"
#include "circt/Dialect/FIRRTL/FIRRTLDialect.h"
#include "circt/Dialect/FIRRTL/FIRRTLOps.h"
#include "circt/Dialect/FIRRTL/FIRRTLTypes.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/Verifier.h"

#include "gtest/gtest.h"

using namespace mlir;
using namespace circt;
using namespace firrtl;

namespace {

class ChoiceOpsTest : public ::testing::Test {
protected:
  void SetUp() override { context.loadDialect<FIRRTLDialect>(); }

  /// Create a circuit which contains an empty module of the same name, as
  /// required by the circuit verifier.
  CircuitOp createCircuit(StringRef name) {
    auto circuit = CircuitOp::create(builder, loc, builder.getStringAttr(name));
    auto body = circuit.getBodyBuilder();
    FModuleOp::create(body, loc, builder.getStringAttr(name),
                      ConventionAttr::get(&context, Convention::Internal), {});
    return circuit;
  }

  /// Create an internal module with the given ports.
  FModuleOp createModule(OpBuilder &body, StringRef name,
                         ArrayRef<PortInfo> ports) {
    return FModuleOp::create(
        body, loc, builder.getStringAttr(name),
        ConventionAttr::get(&context, Convention::Internal), ports);
  }

  ChoiceType getChoiceType(StringRef domain) {
    return ChoiceType::get(
        &context, FlatSymbolRefAttr::get(builder.getStringAttr(domain)));
  }

  MLIRContext context;
  OpBuilder builder{&context};
  UnknownLoc loc = UnknownLoc::get(&context);
};

/// Build the domain used by all of the tests below.
static ChoiceDomainOp buildDomain(OpBuilder &builder, Location loc) {
  SmallVector<std::pair<StringAttr, uint64_t>> cases;
  cases.emplace_back(builder.getStringAttr("Default"), 0);
  cases.emplace_back(builder.getStringAttr("Fast"), 1);
  cases.emplace_back(builder.getStringAttr("Small"), 2);
  return ChoiceDomainOp::create(builder, loc, builder.getStringAttr("Impl"), 2u,
                                cases);
}

TEST_F(ChoiceOpsTest, BuildChoiceDomain) {
  auto circuit = createCircuit("ChoiceDomain");
  auto body = circuit.getBodyBuilder();

  auto domain = buildDomain(body, loc);
  ASSERT_TRUE(domain);
  EXPECT_EQ(domain.getSymName(), "Impl");
  EXPECT_EQ(domain.getWidth(), 2u);
  EXPECT_EQ(domain.getEncodingType(), IntegerType::get(&context, 2));

  // The cases are created in declaration order with their encodings.
  SmallVector<StringRef> names;
  for (auto choiceCase : domain.getBody().getOps<ChoiceCaseOp>())
    names.push_back(choiceCase.getSymName());
  EXPECT_EQ(llvm::ArrayRef<StringRef>(names),
            ArrayRef<StringRef>({"Default", "Fast", "Small"}));
  EXPECT_EQ(domain.getCaseValue("Default"), 0u);
  EXPECT_EQ(domain.getCaseValue("Fast"), 1u);
  EXPECT_EQ(domain.getCaseValue("Small"), 2u);
  EXPECT_FALSE(domain.getCaseValue("Missing").has_value());
  EXPECT_TRUE(succeeded(mlir::verify(circuit)));
}

TEST_F(ChoiceOpsTest, BuildChoiceConstantAndForward) {
  auto circuit = createCircuit("ChoiceFlow");
  auto body = circuit.getBodyBuilder();
  auto domain = buildDomain(body, loc);

  auto choiceType = getChoiceType("Impl");
  auto leaf = createModule(
      body, "Leaf",
      {PortInfo(builder.getStringAttr("impl"), choiceType, Direction::In)});
  auto parent = createModule(
      body, "Parent",
      {PortInfo(builder.getStringAttr("impl"), choiceType, Direction::In)});
  auto parentBody = OpBuilder::atBlockEnd(parent.getBodyBlock());

  // A choice constant names a case in the domain and forwards it to the choice
  // parameter port of an instance.
  auto fast =
      ChoiceConstantOp::create(parentBody, loc, domain.lookupCase("Fast"));
  EXPECT_EQ(fast.getType(), choiceType);
  EXPECT_EQ(fast.getCaseSymbol(),
            SymbolRefAttr::get(
                builder.getStringAttr("Impl"),
                {FlatSymbolRefAttr::get(builder.getStringAttr("Fast"))}));

  // Forward the containing module's choice parameter to the instance, and
  // forward a literal choice to a second instance.
  auto forwarded = InstanceOp::create(parentBody, loc, leaf, "forwarded",
                                      NameKindEnum::InterestingName);
  PropAssignOp::create(parentBody, loc, forwarded.getResult(0),
                       parent.getArgument(0));
  auto literal = InstanceOp::create(parentBody, loc, leaf, "literal",
                                    NameKindEnum::InterestingName);
  PropAssignOp::create(parentBody, loc, literal.getResult(0), fast);

  EXPECT_TRUE(succeeded(mlir::verify(circuit)));
}

TEST_F(ChoiceOpsTest, BuildParamInstanceChoice) {
  auto circuit = createCircuit("ParamChoice");
  auto body = circuit.getBodyBuilder();
  auto domain = buildDomain(body, loc);

  auto ports = {PortInfo(builder.getStringAttr("out"),
                         UIntType::get(&context, 8), Direction::Out)};
  auto defaultModule = createModule(body, "DefaultImpl", ports);
  auto fastModule = createModule(body, "FastImpl", ports);

  auto choiceType = getChoiceType("Impl");
  auto leaf = createModule(
      body, "Leaf",
      {PortInfo(builder.getStringAttr("impl"), choiceType, Direction::In)});
  auto leafBody = OpBuilder::atBlockEnd(leaf.getBodyBlock());

  SmallVector<std::pair<ChoiceCaseOp, FModuleLike>> cases;
  cases.emplace_back(domain.lookupCase("Fast"), fastModule);
  auto choice = ParamInstanceChoiceOp::create(
      leafBody, loc, leaf.getArgument(0), defaultModule, cases, "selected",
      NameKindEnum::InterestingName);

  EXPECT_EQ(choice.getName(), "selected");
  EXPECT_EQ(choice.getSelector(), leaf.getArgument(0));
  EXPECT_EQ(choice.getDefaultTargetAttr(),
            FlatSymbolRefAttr::get(builder.getStringAttr("DefaultImpl")));
  EXPECT_EQ(choice.getModuleNames(),
            builder.getArrayAttr(
                {FlatSymbolRefAttr::get(builder.getStringAttr("DefaultImpl")),
                 FlatSymbolRefAttr::get(builder.getStringAttr("FastImpl"))}));
  EXPECT_EQ(choice.getCaseNames(),
            builder.getArrayAttr({SymbolRefAttr::get(
                builder.getStringAttr("Impl"),
                {FlatSymbolRefAttr::get(builder.getStringAttr("Fast"))})}));

  // The selector resolves to the expected target.
  EXPECT_EQ(choice.getTargetOrDefaultAttr(domain.lookupCase("Fast")),
            FlatSymbolRefAttr::get(builder.getStringAttr("FastImpl")));
  EXPECT_EQ(choice.getTargetOrDefaultAttr(domain.lookupCase("Default")),
            FlatSymbolRefAttr::get(builder.getStringAttr("DefaultImpl")));

  EXPECT_TRUE(succeeded(mlir::verify(circuit)));
}

} // namespace
