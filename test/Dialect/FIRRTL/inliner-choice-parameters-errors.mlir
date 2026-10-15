// RUN: circt-opt --firrtl-inliner --split-input-file --verify-diagnostics %s

// A module with an elaboration-time choice parameter can be inlined only when
// every choice port is driven by a choice constant or a containing-module
// parameter.  Flattening must splice the child into the parent unconditionally,
// so an unsubstitutable port is diagnosed instead of producing invalid IR.

firrtl.circuit "FlattenChoiceParameter" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module private @FastImpl(out %out: !firrtl.uint<8>) {}

  // expected-note @+1 {{module has an elaboration-time choice parameter}}
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
    // A property wire is not a legal choice source: the parameterized choice
    // selector must be a constant or a containing-module parameter.
    %impl_wire = firrtl.wire : !firrtl.choice<@Impl>
    firrtl.propassign %impl_wire, %impl : !firrtl.choice<@Impl>
    // expected-error @+1 {{cannot flatten instance}}
    %leaf_impl, %leaf_out = firrtl.instance leaf @Leaf(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    firrtl.propassign %leaf_impl, %impl_wire : !firrtl.choice<@Impl>
    firrtl.connect %out, %leaf_out : !firrtl.uint<8>
  }
}

// -----

// An inline-marked module with an unsubstitutable choice port is retained with
// a warning rather than diagnosing the whole pass.

firrtl.circuit "RetainChoiceParameter" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module private @FastImpl(out %out: !firrtl.uint<8>) {}

  // expected-warning @+1 {{module marked inline has elaboration-time choice parameters that cannot be forwarded}}
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

  firrtl.module @RetainChoiceParameter(out %out: !firrtl.uint<8>) {
    %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %impl_wire = firrtl.wire : !firrtl.choice<@Impl>
    firrtl.propassign %impl_wire, %impl : !firrtl.choice<@Impl>
    // expected-note @+1 {{instantiated here}}
    %leaf_impl, %leaf_out = firrtl.instance leaf @Leaf(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    firrtl.propassign %leaf_impl, %impl_wire : !firrtl.choice<@Impl>
    firrtl.connect %out, %leaf_out : !firrtl.uint<8>
  }
}
