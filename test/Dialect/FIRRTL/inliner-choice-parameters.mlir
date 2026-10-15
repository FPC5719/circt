// RUN: circt-opt --firrtl-inliner --split-input-file %s 2>&1 | FileCheck %s
// RUN: circt-opt --firrtl-inliner --canonicalize --split-input-file %s 2>&1 | FileCheck %s --check-prefix=FOLD

// A module with an elaboration-time choice parameter is inlined by substituting
// the choice port with the value driving it in the parent.  The value is a
// choice constant or a containing-module parameter, so no property wire is
// materialized and the parameterized instance remains valid until the choice
// parameters are materialized.

// -----

// A literal choice drives the port, so the inlined selector becomes a choice
// constant.

firrtl.circuit "InlineLiteralChoice" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module private @FastImpl(out %out: !firrtl.uint<8>) {}

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

  // CHECK-LABEL: firrtl.module @InlineLiteralChoice
  // CHECK-NOT: firrtl.wire : !firrtl.choice
  // CHECK-NOT: firrtl.instance leaf
  // CHECK: firrtl.param_instance_choice
 
  // FOLD-LABEL: firrtl.module @InlineLiteralChoice
  // FOLD-NOT: firrtl.wire : !firrtl.choice
  // FOLD-NOT: firrtl.param_instance_choice
  // FOLD: firrtl.instance leaf_selected @FastImpl
  firrtl.module @InlineLiteralChoice(out %out: !firrtl.uint<8>) {
    %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %leaf_impl, %leaf_out = firrtl.instance leaf @Leaf(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    firrtl.propassign %leaf_impl, %impl : !firrtl.choice<@Impl>
    firrtl.connect %out, %leaf_out : !firrtl.uint<8>
  }
}

// -----

// The parent forwards its own choice parameter through a wrapper into the
// parameterized instance.  Both wrappers are inlined and the selector becomes
// the parent's choice input port.

firrtl.circuit "InlineForwardedChoice" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module private @FastImpl(out %out: !firrtl.uint<8>) {}

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

  firrtl.module private @Mid(in %impl: !firrtl.choice<@Impl>,
                             out %out: !firrtl.uint<8>)
      attributes {annotations = [{class = "firrtl.passes.InlineAnnotation"}]} {
    %leaf_impl, %leaf_out = firrtl.instance leaf @Leaf(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    firrtl.propassign %leaf_impl, %impl : !firrtl.choice<@Impl>
    firrtl.connect %out, %leaf_out : !firrtl.uint<8>
  }

  // CHECK-LABEL: firrtl.module private @Outer(in %impl: !firrtl.choice<@Impl>
  // CHECK-NOT: firrtl.wire : !firrtl.choice
  // CHECK-NOT: firrtl.instance mid
  // CHECK-NOT: firrtl.instance leaf
  // CHECK: "firrtl.param_instance_choice"(%impl)
  firrtl.module private @Outer(in %impl: !firrtl.choice<@Impl>,
                               out %out: !firrtl.uint<8>) {
    %mid_impl, %mid_out = firrtl.instance mid @Mid(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    firrtl.propassign %mid_impl, %impl : !firrtl.choice<@Impl>
    firrtl.connect %out, %mid_out : !firrtl.uint<8>
  }

  firrtl.module @InlineForwardedChoice(in %impl: !firrtl.choice<@Impl>,
                                       out %out: !firrtl.uint<8>) {
    %outer_impl, %outer_out = firrtl.instance outer @Outer(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    firrtl.propassign %outer_impl, %impl : !firrtl.choice<@Impl>
    firrtl.connect %out, %outer_out : !firrtl.uint<8>
  }
}

// -----

// The driving choice constant may appear after the instance it drives.  The
// substituted selector must still dominate the inlined body, so a fresh
// constant is created at the instance.

firrtl.circuit "DominatedChoice" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module private @FastImpl(out %out: !firrtl.uint<8>) {}

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

  // CHECK-LABEL: firrtl.module @DominatedChoice
  // CHECK-NOT: firrtl.wire : !firrtl.choice
  // CHECK: %[[C:.*]] = firrtl.choice.constant @Impl::@Fast
  // CHECK: "firrtl.param_instance_choice"(%[[C]])
  firrtl.module @DominatedChoice(out %out: !firrtl.uint<8>) {
    %leaf_impl, %leaf_out = firrtl.instance leaf @Leaf(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    // The constant is defined after the instance it drives.
    %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    firrtl.propassign %leaf_impl, %impl : !firrtl.choice<@Impl>
    firrtl.connect %out, %leaf_out : !firrtl.uint<8>
  }
}

// -----

// An instance inside a layer block is inlined too.  The substituted selector
// must be defined inside the layer block, so the fresh choice constant is
// created at the inlined instance rather than where the original constant was.

firrtl.circuit "LayerChoice" {
  firrtl.layer @A bind {}
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl() {}
  firrtl.module private @FastImpl() {}

  firrtl.module private @Leaf(in %impl: !firrtl.choice<@Impl>)
      attributes {annotations = [{class = "firrtl.passes.InlineAnnotation"}]} {
    "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl],
      caseNames = [@Impl::@Fast],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1>, portNames = [], domainInfo = [],
      annotations = [], portAnnotations = [], layers = []
    }> : (!firrtl.choice<@Impl>) -> ()
  }

  // CHECK-LABEL: firrtl.module @P
  // CHECK: firrtl.layerblock @A
  // CHECK: firrtl.choice.constant @Impl::@Fast
  // CHECK: "firrtl.param_instance_choice"(%{{[0-9]+}})
  // CHECK-NOT: firrtl.wire : !firrtl.choice
  firrtl.module @P() {
    firrtl.layerblock @A {
      %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
      %leaf_impl = firrtl.instance leaf @Leaf(in impl: !firrtl.choice<@Impl>)
      firrtl.propassign %leaf_impl, %impl : !firrtl.choice<@Impl>
    }
  }

  firrtl.module @LayerChoice() {
    firrtl.instance p @P()
  }
}
