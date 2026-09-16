// RUN: circt-opt --firrtl-imconstprop %s | FileCheck %s

// V1 treats an unresolved instance choice as overdefined: the selector is an
// elaboration-time parameter, so the result is not a hardware constant even
// when every candidate implementation drives a constant.
firrtl.circuit "ConstPropChoiceParameters" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.uint<8>) {
    %c = firrtl.constant 0 : !firrtl.uint<8>
    firrtl.connect %out, %c : !firrtl.uint<8>
  }
  firrtl.module private @FastImpl(out %out: !firrtl.uint<8>) {
    %c = firrtl.constant 1 : !firrtl.uint<8>
    firrtl.connect %out, %c : !firrtl.uint<8>
  }

  // CHECK-LABEL: firrtl.module @ConstPropChoiceParameters
  firrtl.module @ConstPropChoiceParameters(in %impl: !firrtl.choice<@Impl>,
                                           out %out: !firrtl.uint<8>) {
    // CHECK: %selected_out = "firrtl.param_instance_choice"(%impl)
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl],
      caseNames = [@Impl::@Fast],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    // The selected value stays unknown: no candidate constant is propagated.
    // CHECK-NOT: firrtl.constant
    // CHECK: firrtl.connect %out, %selected_out
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }
}
