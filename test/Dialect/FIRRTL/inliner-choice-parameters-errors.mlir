// RUN: circt-opt --firrtl-inliner --split-input-file --verify-diagnostics %s

// Flattening must splice the child into the parent, which is not possible for a
// module with elaboration-time choice parameters.  Diagnose instead of
// producing invalid IR.
firrtl.circuit "FlattenChoiceParameter" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module private @FastImpl(out %out: !firrtl.uint<8>) {}

  // expected-note @+1 {{module has elaboration-time choice parameters}}
  firrtl.module private @Leaf(in %impl: !firrtl.choice<@Impl>,
                              out %out: !firrtl.uint<8>) {
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl],
      caseNames = [@Impl::@Fast],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }

  firrtl.module @FlattenChoiceParameter(out %out: !firrtl.uint<8>)
      attributes {annotations = [{class = "firrtl.transforms.FlattenAnnotation"}]} {
    %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    // expected-error @+1 {{cannot flatten instance}}
    %leaf_impl, %leaf_out = firrtl.instance leaf @Leaf(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    firrtl.propassign %leaf_impl, %impl : !firrtl.choice<@Impl>
    firrtl.connect %out, %leaf_out : !firrtl.uint<8>
  }
}
