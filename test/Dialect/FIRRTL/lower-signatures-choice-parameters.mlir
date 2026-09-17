// RUN: circt-opt -pass-pipeline='builtin.module(firrtl.circuit(firrtl-lower-signatures))' %s | FileCheck %s

// `firrtl-lower-signatures` rewrites the ports of every instance-like operation.
// A parameterized instance choice is rewritten like an option-based one, and the
// property assignments which forward its choice parameter are preserved.
firrtl.circuit "LowerSignaturesChoiceParameter" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  // CHECK-LABEL: firrtl.module private @DefaultImpl
  // CHECK-SAME: out %out_a: !firrtl.uint<8>
  // CHECK-SAME: out %out_b: !firrtl.uint<8>
  firrtl.module private @DefaultImpl(
      in %impl: !firrtl.choice<@Impl>,
      out %out: !firrtl.bundle<a: uint<8>, b: uint<8>>) {}
  // CHECK-LABEL: firrtl.module private @FastImpl
  // CHECK-SAME: out %out_a: !firrtl.uint<8>
  // CHECK-SAME: out %out_b: !firrtl.uint<8>
  firrtl.module private @FastImpl(
      in %impl: !firrtl.choice<@Impl>,
      out %out: !firrtl.bundle<a: uint<8>, b: uint<8>>) {}

  // CHECK-LABEL: firrtl.module @LowerSignaturesChoiceParameter
  firrtl.module @LowerSignaturesChoiceParameter(
      in %impl: !firrtl.choice<@Impl>, out %a: !firrtl.uint<8>) {
    // CHECK: %sel_impl, %sel_out_a, %sel_out_b = "firrtl.param_instance_choice"
    // CHECK-SAME: portNames = ["impl", "out_a", "out_b"]
    %sel_impl, %sel = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl], caseNames = [@Impl::@Fast],
      name = "sel", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: false, true>, portNames = ["impl", "out"],
      domainInfo = [[], []], annotations = [], portAnnotations = [[], []],
      layers = []
    }> : (!firrtl.choice<@Impl>) -> (!firrtl.choice<@Impl>, !firrtl.bundle<a: uint<8>, b: uint<8>>)
    // The choice forwarding keeps its property assignment.
    // CHECK: firrtl.propassign %sel_impl, %impl
    firrtl.propassign %sel_impl, %impl : !firrtl.choice<@Impl>
    %a_ref = firrtl.subfield %sel[a] : !firrtl.bundle<a: uint<8>, b: uint<8>>
    firrtl.connect %a, %a_ref : !firrtl.uint<8>
  }
}
