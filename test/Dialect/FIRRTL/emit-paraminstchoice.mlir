// RUN: circt-translate --export-firrtl %s -o %t
// RUN: FileCheck %s < %t
// RUN: circt-translate --import-firrtl %t | FileCheck %s --check-prefix=ROUNDTRIP

// CHECK: FIRRTL version 7.0.0
// CHECK: circuit ParamInstChoiceEmit :
// CHECK: paraminstchoice selected impl of DefaultImpl :
// CHECK-NEXT: Fast => FastImpl
// CHECK-NEXT: Small => SmallImpl
// CHECK: paraminstchoice literal choice(Impl, Fast) of DefaultImpl :
// CHECK-NEXT: Fast => FastImpl
// CHECK-NEXT: Small => SmallImpl
// ROUNDTRIP: "firrtl.param_instance_choice"(%impl)
// ROUNDTRIP-SAME: caseNames = [@Impl::@Fast, @Impl::@Small]
// ROUNDTRIP-SAME: moduleNames = [@DefaultImpl, @FastImpl, @SmallImpl]
firrtl.circuit "ParamInstChoiceEmit" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
    firrtl.choice_case @Small = 2
  }
  firrtl.module @DefaultImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module @FastImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module @SmallImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module @ParamInstChoiceEmit(in %impl: !firrtl.choice<@Impl>) {
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl, @SmallImpl],
      caseNames = [@Impl::@Fast, @Impl::@Small], name = "selected",
      nameKind = #firrtl<name_kind interesting_name>,
      portDirections = array<i1: true>, portNames = ["out"],
      domainInfo = [[]], annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
  }
  firrtl.module private @LiteralParamInstChoiceEmit() {
    %fast = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %literal = "firrtl.param_instance_choice"(%fast) <{
      moduleNames = [@DefaultImpl, @FastImpl, @SmallImpl],
      caseNames = [@Impl::@Fast, @Impl::@Small], name = "literal",
      nameKind = #firrtl<name_kind interesting_name>,
      portDirections = array<i1: true>, portNames = ["out"],
      domainInfo = [[]], annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
  }
}
