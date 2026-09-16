// RUN: circt-opt --firrtl-lower-types %s | FileCheck %s

// Aggregate ports of a parameterized instance choice are flattened like those
// of any other instance-like operation, and the selector is preserved.
firrtl.circuit "LowerParamInstanceChoice" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.bundle<a: uint<8>, b: uint<8>>) {}
  firrtl.module private @FastImpl(out %out: !firrtl.bundle<a: uint<8>, b: uint<8>>) {}

  // CHECK-LABEL: firrtl.module private @Leaf
  firrtl.module private @Leaf(in %impl: !firrtl.choice<@Impl>,
                              out %out: !firrtl.bundle<a: uint<8>, b: uint<8>>) {
    // CHECK: %selected_out_a, %selected_out_b = "firrtl.param_instance_choice"
    // CHECK-SAME: (%impl)
    // CHECK-SAME: moduleNames = [@DefaultImpl, @FastImpl]
    // CHECK-SAME: portNames = ["out_a", "out_b"]
    // CHECK-SAME: (!firrtl.choice<@Impl>) -> (!firrtl.uint<8>, !firrtl.uint<8>)
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl],
      caseNames = [@Impl::@Fast],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.bundle<a: uint<8>, b: uint<8>>
    firrtl.connect %out, %selected : !firrtl.bundle<a: uint<8>, b: uint<8>>
  }

  firrtl.module @LowerParamInstanceChoice(out %a: !firrtl.uint<8>,
                                          out %b: !firrtl.uint<8>) {
    %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %leaf_impl, %leaf_out = firrtl.instance leaf @Leaf(in impl: !firrtl.choice<@Impl>, out out: !firrtl.bundle<a: uint<8>, b: uint<8>>)
    firrtl.propassign %leaf_impl, %impl : !firrtl.choice<@Impl>
    %a_ref = firrtl.subfield %leaf_out[a] : !firrtl.bundle<a: uint<8>, b: uint<8>>
    %b_ref = firrtl.subfield %leaf_out[b] : !firrtl.bundle<a: uint<8>, b: uint<8>>
    firrtl.connect %a, %a_ref : !firrtl.uint<8>
    firrtl.connect %b, %b_ref : !firrtl.uint<8>
  }
}

// -----

// A materialized selector parameter survives type lowering.
// CHECK-LABEL: firrtl.circuit "LowerMaterializedSelector"
firrtl.circuit "LowerMaterializedSelector" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.bundle<a: uint<8>>) {}
  firrtl.module private @FastImpl(out %out: !firrtl.bundle<a: uint<8>>) {}

  firrtl.module private @Leaf(out %out: !firrtl.bundle<a: uint<8>>) {
    // CHECK: %selected_out_a = "firrtl.param_instance_choice"
    // CHECK-SAME: portNames = ["out_a"]
    // CHECK-SAME: selectorParameter = #firrtl.param.decl<"selector": i2 = 1>
    %selected = "firrtl.param_instance_choice"() <{
      selectorParameter = #firrtl.param.decl<"selector": i2 = 1>,
      moduleNames = [@DefaultImpl, @FastImpl],
      caseNames = [@Impl::@Fast],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : () -> !firrtl.bundle<a: uint<8>>
    firrtl.connect %out, %selected : !firrtl.bundle<a: uint<8>>
  }

  firrtl.module @LowerMaterializedSelector(out %a: !firrtl.uint<8>) {
    %leaf_out = firrtl.instance leaf @Leaf(out out: !firrtl.bundle<a: uint<8>>)
    %a_ref = firrtl.subfield %leaf_out[a] : !firrtl.bundle<a: uint<8>>
    firrtl.connect %a, %a_ref : !firrtl.uint<8>
  }
}
