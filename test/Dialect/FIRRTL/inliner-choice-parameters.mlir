// RUN: circt-opt --firrtl-inliner %s 2>&1 | FileCheck %s

// A module with elaboration-time choice parameters is retained: forwarding the
// choice into the parent module would require a property wire, which the choice
// contract does not allow.
// CHECK: warning: module marked inline has elaboration-time choice parameters and is retained

firrtl.circuit "InlineChoiceParameter" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module private @FastImpl(out %out: !firrtl.uint<8>) {}

  // CHECK: firrtl.module private @Leaf
  firrtl.module private @Leaf(in %impl: !firrtl.choice<@Impl>,
                              out %out: !firrtl.uint<8>)
      attributes {annotations = [{class = "firrtl.passes.InlineAnnotation"}]} {
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl],
      caseNames = [@Impl::@Fast],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }

  // CHECK-LABEL: firrtl.module @InlineChoiceParameter
  // CHECK: firrtl.instance leaf
  firrtl.module @InlineChoiceParameter(out %out: !firrtl.uint<8>) {
    %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %leaf_impl, %leaf_out = firrtl.instance leaf @Leaf(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    firrtl.propassign %leaf_impl, %impl : !firrtl.choice<@Impl>
    firrtl.connect %out, %leaf_out : !firrtl.uint<8>
  }
}
