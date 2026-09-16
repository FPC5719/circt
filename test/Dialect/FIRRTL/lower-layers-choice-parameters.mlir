// RUN: circt-opt --firrtl-lower-layers %s | FileCheck %s

// Layer lowering must clear the layer requirements of every instance-like
// operation, including parameterized instance choices.  Otherwise the lowered
// instances disagree with the (now layer-free) modules they instantiate.
firrtl.circuit "LowerLayersChoiceParameter" {
  firrtl.layer @A bind {}

  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.uint<8>)
      attributes {layers = [@A]} {
    %c = firrtl.constant 0 : !firrtl.uint<8>
    firrtl.connect %out, %c : !firrtl.uint<8>
  }
  firrtl.module private @FastImpl(out %out: !firrtl.uint<8>)
      attributes {layers = [@A]} {
    %c = firrtl.constant 1 : !firrtl.uint<8>
    firrtl.connect %out, %c : !firrtl.uint<8>
  }

  // CHECK-LABEL: firrtl.module private @Leaf
  firrtl.module private @Leaf(in %impl: !firrtl.choice<@Impl>,
                              out %out: !firrtl.uint<8>)
      attributes {layers = [@A]} {
    // CHECK: %selected_out = "firrtl.param_instance_choice"(%impl)
    // CHECK-SAME: layers = []
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl],
      caseNames = [@Impl::@Fast],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = [@A]
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }

  firrtl.module @LowerLayersChoiceParameter() {
    firrtl.layerblock @A {
      %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
      %leaf_impl, %leaf_out = firrtl.instance leaf {layers = [@A]} @Leaf(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
      firrtl.propassign %leaf_impl, %impl : !firrtl.choice<@Impl>
    }
  }
}

// The layer block is lowered into a module which keeps the layer-free instance.
// CHECK-LABEL: firrtl.module private @LowerLayersChoiceParameter_A
// CHECK: firrtl.instance leaf @Leaf
