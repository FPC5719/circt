// RUN: circt-opt --canonicalize --cse %s | FileCheck %s

// Canonicalization and CSE must not fold the property assignments that forward
// an unresolved choice into a parameterized instance.  Only a literal selector
// is folded, and only into the instance itself.
firrtl.circuit "CanonicalizeChoiceParameters" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
    firrtl.choice_case @Small = 2
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module private @FastImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module private @SmallImpl(out %out: !firrtl.uint<8>) {}

  // The unresolved selector stays on the parameterized instance.
  // CHECK-LABEL: firrtl.module private @Leaf
  firrtl.module private @Leaf(in %impl: !firrtl.choice<@Impl>,
                              out %out: !firrtl.uint<8>) {
    // CHECK: %selected_out = "firrtl.param_instance_choice"(%impl)
    // CHECK-SAME: moduleNames = [@DefaultImpl, @FastImpl, @SmallImpl]
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl, @SmallImpl],
      caseNames = [@Impl::@Fast, @Impl::@Small],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }

  // Forwarding from the containing module's choice parameter is preserved.
  // CHECK-LABEL: firrtl.module private @Outer
  firrtl.module private @Outer(in %impl: !firrtl.choice<@Impl>,
                               out %out: !firrtl.uint<8>) {
    // CHECK: %leaf_impl, %leaf_out = firrtl.instance leaf
    // CHECK: firrtl.propassign %leaf_impl, %impl
    %leaf_impl, %leaf_out = firrtl.instance leaf @Leaf(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    firrtl.propassign %leaf_impl, %impl : !firrtl.choice<@Impl>
    firrtl.connect %out, %leaf_out : !firrtl.uint<8>
  }

  // CHECK-LABEL: firrtl.module @CanonicalizeChoiceParameters
  firrtl.module @CanonicalizeChoiceParameters(out %first: !firrtl.uint<8>,
                                              out %second: !firrtl.uint<8>) {
    // CHECK: firrtl.choice.constant @Impl::@Fast
    // CHECK: firrtl.choice.constant @Impl::@Small
    %fast = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %small = firrtl.choice.constant @Impl::@Small : !firrtl.choice<@Impl>
    // CHECK: firrtl.propassign %firstOuter_impl,
    // CHECK: firrtl.propassign %secondOuter_impl,
    %firstOuter_impl, %firstOuter_out = firrtl.instance firstOuter @Outer(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    %secondOuter_impl, %secondOuter_out = firrtl.instance secondOuter @Outer(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    firrtl.propassign %firstOuter_impl, %fast : !firrtl.choice<@Impl>
    firrtl.propassign %secondOuter_impl, %small : !firrtl.choice<@Impl>
    firrtl.connect %first, %firstOuter_out : !firrtl.uint<8>
    firrtl.connect %second, %secondOuter_out : !firrtl.uint<8>
  }
}
