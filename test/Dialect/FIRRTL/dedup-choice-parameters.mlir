// RUN: circt-opt --firrtl-dedup %s | FileCheck %s

// Identical parameterized modules are deduplicated, and the instance graph
// references of the merged candidates are updated to the surviving module.
// CHECK-LABEL: firrtl.circuit "DedupCandidates"
firrtl.circuit "DedupCandidates" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module private @FastImpl(out %out: !firrtl.uint<8>) {}
  // CHECK-NOT: firrtl.module private @FastImplCopy
  firrtl.module private @FastImplCopy(out %out: !firrtl.uint<8>) {}

  firrtl.module private @Leaf(in %impl: !firrtl.choice<@Impl>,
                              out %out: !firrtl.uint<8>) {
    // Both the default and the alternative must reference the surviving
    // module, and the port names of the instance must match it.
    // CHECK: firrtl.param_instance_choice
    // CHECK-SAME: caseNames = [@Impl::@Fast]
    // CHECK-SAME: moduleNames = [@DefaultImpl, @DefaultImpl]
    // CHECK-SAME: portNames = ["out"]
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImplCopy],
      caseNames = [@Impl::@Fast],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }

  firrtl.module @DedupCandidates(out %out: !firrtl.uint<8>) {
    %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %leaf_impl, %leaf_out = firrtl.instance leaf @Leaf(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    firrtl.propassign %leaf_impl, %impl : !firrtl.choice<@Impl>
    firrtl.connect %out, %leaf_out : !firrtl.uint<8>
  }
}

// -----

// Candidate modules which only differ in their port names are deduplicated.
// The parameterized instance that referenced the erased module must be updated
// to the surviving port names, otherwise the result does not verify.
// CHECK-LABEL: firrtl.circuit "DedupCandidatePortNames"
firrtl.circuit "DedupCandidatePortNames" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module private @FastImpl(out %out: !firrtl.uint<8>) {}
  // CHECK-NOT: firrtl.module private @DefaultImplAlias
  firrtl.module private @DefaultImplAlias(out %result: !firrtl.uint<8>) {}
  // CHECK-NOT: firrtl.module private @FastImplAlias
  firrtl.module private @FastImplAlias(out %result: !firrtl.uint<8>) {}

  firrtl.module private @Leaf(out %out: !firrtl.uint<8>) {
    // CHECK: %selected_out = "firrtl.param_instance_choice"
    // CHECK-SAME: moduleNames = [@DefaultImpl, @DefaultImpl]
    // CHECK-SAME: portNames = ["out"]
    %selected = "firrtl.param_instance_choice"() <{
      selectorParameter = #firrtl.param.decl<"impl": i2 = 1>,
      moduleNames = [@DefaultImplAlias, @FastImplAlias],
      caseNames = [@Impl::@Fast],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["result"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : () -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }

  firrtl.module @DedupCandidatePortNames(out %out: !firrtl.uint<8>) {
    %leaf_out = firrtl.instance leaf @Leaf(out out: !firrtl.uint<8>)
    firrtl.connect %out, %leaf_out : !firrtl.uint<8>
  }
}

// -----

// Modules which only differ in their case-to-target mapping must not be merged.
// CHECK-LABEL: firrtl.circuit "DedupChoiceMappings"
firrtl.circuit "DedupChoiceMappings" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
    firrtl.choice_case @Slow = 2
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module private @FastImpl(out %out: !firrtl.uint<8>) {}

  // CHECK-LABEL: firrtl.module private @LeafFast
  firrtl.module private @LeafFast(in %impl: !firrtl.choice<@Impl>,
                                  out %out: !firrtl.uint<8>) {
    // CHECK: firrtl.param_instance_choice
    // CHECK-SAME: caseNames = [@Impl::@Fast]
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl],
      caseNames = [@Impl::@Fast],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }
  // CHECK-LABEL: firrtl.module private @LeafSlow
  firrtl.module private @LeafSlow(in %impl: !firrtl.choice<@Impl>,
                                  out %out: !firrtl.uint<8>) {
    // CHECK: firrtl.param_instance_choice
    // CHECK-SAME: caseNames = [@Impl::@Slow]
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl],
      caseNames = [@Impl::@Slow],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }

  firrtl.module @DedupChoiceMappings(out %fast: !firrtl.uint<8>,
                                     out %slow: !firrtl.uint<8>) {
    %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %fast_impl, %fast_out = firrtl.instance fast @LeafFast(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    %slow_impl, %slow_out = firrtl.instance slow @LeafSlow(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    firrtl.propassign %fast_impl, %impl : !firrtl.choice<@Impl>
    firrtl.propassign %slow_impl, %impl : !firrtl.choice<@Impl>
    firrtl.connect %fast, %fast_out : !firrtl.uint<8>
    firrtl.connect %slow, %slow_out : !firrtl.uint<8>
  }
}

// -----

// Modules which only differ in their formal parameter declarations must not be
// merged: deduplication does not rename module parameters.
// CHECK-LABEL: firrtl.circuit "DedupFormalParameters"
firrtl.circuit "DedupFormalParameters" {
  // CHECK: firrtl.module private @ParamA<impl: i2>
  firrtl.module private @ParamA<impl: i2>(out %out: !firrtl.uint<8>) {}
  // CHECK: firrtl.module private @ParamB<sel: i2>
  firrtl.module private @ParamB<sel: i2>(out %out: !firrtl.uint<8>) {}

  firrtl.module @DedupFormalParameters(out %a: !firrtl.uint<8>,
                                       out %b: !firrtl.uint<8>) {
    %pa_out = firrtl.instance pa @ParamA(out out: !firrtl.uint<8>)
    %pb_out = firrtl.instance pb @ParamB(out out: !firrtl.uint<8>)
    firrtl.connect %a, %pa_out : !firrtl.uint<8>
    firrtl.connect %b, %pb_out : !firrtl.uint<8>
  }
}

// -----

// The module names referenced by a parameterized instance choice take part in
// the structural hash, so two wrappers that only differ in which copy of an
// otherwise identical candidate module they reference are deduplicated once
// the candidates are merged.
// CHECK-LABEL: firrtl.circuit "DedupChoiceCandidates"
firrtl.circuit "DedupChoiceCandidates" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  // The two default modules and the two alternative modules are identical and
  // are deduplicated into one module each.
  firrtl.module private @DefaultImplA(out %out: !firrtl.uint<8>) {}
  firrtl.module private @DefaultImplB(out %out: !firrtl.uint<8>) {}
  firrtl.module private @FastImplA(out %out: !firrtl.uint<8>) {}
  firrtl.module private @FastImplB(out %out: !firrtl.uint<8>) {}

  firrtl.module private @LeafA(in %impl: !firrtl.choice<@Impl>,
                               out %out: !firrtl.uint<8>) {
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImplA, @FastImplA],
      caseNames = [@Impl::@Fast],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }
  firrtl.module private @LeafB(in %impl: !firrtl.choice<@Impl>,
                               out %out: !firrtl.uint<8>) {
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImplB, @FastImplB],
      caseNames = [@Impl::@Fast],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }

  firrtl.module @DedupChoiceCandidates(out %a: !firrtl.uint<8>,
                                       out %b: !firrtl.uint<8>) {
    %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    // Both wrappers are identical once their candidates are merged, so the two
    // instances must reference the same module.
    // CHECK: firrtl.instance a @[[LEAF:[A-Za-z]+]]
    // CHECK: firrtl.instance b @[[LEAF]]
    %a_impl, %a_out = firrtl.instance a @LeafA(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    %b_impl, %b_out = firrtl.instance b @LeafB(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    firrtl.propassign %a_impl, %impl : !firrtl.choice<@Impl>
    firrtl.propassign %b_impl, %impl : !firrtl.choice<@Impl>
    firrtl.connect %a, %a_out : !firrtl.uint<8>
    firrtl.connect %b, %b_out : !firrtl.uint<8>
  }
}
