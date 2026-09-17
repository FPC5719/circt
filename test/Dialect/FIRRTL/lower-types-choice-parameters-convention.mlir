// RUN: circt-opt --firrtl-lower-types='preserve-aggregate=all' %s | FileCheck %s

// Modules instantiated by a parameterized instance choice must use the
// scalarized convention, exactly like modules instantiated by an option-based
// instance choice: all candidates share a single port shape and aggregates are
// not preserved through the choice.
firrtl.circuit "LowerTypesChoiceConvention" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  // CHECK-LABEL: firrtl.module private @DefaultImpl
  // CHECK-SAME: out %out_a: !firrtl.uint<8>
  // CHECK-SAME: out %out_b: !firrtl.uint<8>
  firrtl.module private @DefaultImpl(
      out %out: !firrtl.bundle<a: uint<8>, b: uint<8>>) {}
  // CHECK-LABEL: firrtl.module private @FastImpl
  // CHECK-SAME: out %out_a: !firrtl.uint<8>
  // CHECK-SAME: out %out_b: !firrtl.uint<8>
  firrtl.module private @FastImpl(
      out %out: !firrtl.bundle<a: uint<8>, b: uint<8>>) {}

  // CHECK-LABEL: firrtl.module @LowerTypesChoiceConvention
  firrtl.module @LowerTypesChoiceConvention(in %impl: !firrtl.choice<@Impl>,
                                            out %out: !firrtl.uint<8>) {
    // CHECK: %sel_out_a, %sel_out_b = "firrtl.param_instance_choice"
    // CHECK-SAME: portNames = ["out_a", "out_b"]
    %sel = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl], caseNames = [@Impl::@Fast],
      name = "sel", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.bundle<a: uint<8>, b: uint<8>>
    %a = firrtl.subfield %sel[a] : !firrtl.bundle<a: uint<8>, b: uint<8>>
    firrtl.connect %out, %a : !firrtl.uint<8>
  }
}
