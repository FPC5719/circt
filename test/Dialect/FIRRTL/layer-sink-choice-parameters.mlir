// RUN: circt-opt -pass-pipeline="builtin.module(firrtl.circuit(firrtl-layer-sink))" -allow-unregistered-dialect --split-input-file %s | FileCheck %s

// A pure parameterized instance choice whose selector is a choice constant can
// be sunk into the layer block that demands it, together with its selector.
firrtl.circuit "PureParamChoice" {
  firrtl.layer @A bind {}

  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @Pure(in %i: !firrtl.uint<1>, out %o: !firrtl.uint<1>) {
    firrtl.matchingconnect %o, %i : !firrtl.uint<1>
  }
  firrtl.module private @PureFast(in %i: !firrtl.uint<1>,
                                  out %o: !firrtl.uint<1>) {
    firrtl.matchingconnect %o, %i : !firrtl.uint<1>
  }

  // CHECK: firrtl.module @PureParamChoice
  // CHECK:   firrtl.layerblock @A {
  // CHECK:     %{{.*}} = firrtl.choice.constant @Impl::@Fast
  // CHECK:     %pure_i, %pure_o = "firrtl.param_instance_choice"
  // CHECK:     firrtl.matchingconnect %pure_i, %c0_ui1
  // CHECK:     "unknown"(%pure_o)
  // CHECK:   }
  firrtl.module @PureParamChoice() {
    %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %c0_ui1 = firrtl.constant 0 : !firrtl.uint<1>
    %pure_i, %pure_o = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@Pure, @PureFast], caseNames = [@Impl::@Fast],
      name = "pure", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: false, true>, portNames = ["i", "o"],
      domainInfo = [[], []], annotations = [], portAnnotations = [[], []],
      layers = []
    }> : (!firrtl.choice<@Impl>) -> (!firrtl.uint<1>, !firrtl.uint<1>)
    firrtl.matchingconnect %pure_i, %c0_ui1 : !firrtl.uint<1>
    firrtl.layerblock @A {
      "unknown"(%pure_o) : (!firrtl.uint<1>) -> ()
    }
  }
}

// -----

// An effectful parameterized instance choice cannot be sunk into the layer
// block that demands it.
firrtl.circuit "EffectfulParamChoice" {
  firrtl.layer @A bind {}

  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @Pure(in %i: !firrtl.uint<1>, out %o: !firrtl.uint<1>) {
    firrtl.matchingconnect %o, %i : !firrtl.uint<1>
  }
  firrtl.module private @Effectful(in %i: !firrtl.uint<1>,
                                   out %o: !firrtl.uint<1>) {
    firrtl.matchingconnect %o, %i : !firrtl.uint<1>
    "unknown"() : () -> ()
  }

  // CHECK: firrtl.module @EffectfulParamChoice
  // CHECK: %effectful_i, %effectful_o = "firrtl.param_instance_choice"
  // CHECK: firrtl.layerblock @A {
  // CHECK:   "unknown"(%effectful_o)
  // CHECK: }
  firrtl.module @EffectfulParamChoice() {
    %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %c0_ui1 = firrtl.constant 0 : !firrtl.uint<1>
    %effectful_i, %effectful_o = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@Pure, @Effectful], caseNames = [@Impl::@Fast],
      name = "effectful", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: false, true>, portNames = ["i", "o"],
      domainInfo = [[], []], annotations = [], portAnnotations = [[], []],
      layers = []
    }> : (!firrtl.choice<@Impl>) -> (!firrtl.uint<1>, !firrtl.uint<1>)
    firrtl.matchingconnect %effectful_i, %c0_ui1 : !firrtl.uint<1>
    firrtl.layerblock @A {
      "unknown"(%effectful_o) : (!firrtl.uint<1>) -> ()
    }
  }
}

// -----

// A parameterized instance choice whose selector is a module input port cannot
// be sunk: a layer block cannot capture a property value.
firrtl.circuit "PortSelectorParamChoice" {
  firrtl.layer @A bind {}

  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @Pure(in %i: !firrtl.uint<1>, out %o: !firrtl.uint<1>) {
    firrtl.matchingconnect %o, %i : !firrtl.uint<1>
  }
  firrtl.module private @PureFast(in %i: !firrtl.uint<1>,
                                  out %o: !firrtl.uint<1>) {
    firrtl.matchingconnect %o, %i : !firrtl.uint<1>
  }

  // CHECK: firrtl.module @PortSelectorParamChoice
  // CHECK: %pure_i, %pure_o = "firrtl.param_instance_choice"
  // CHECK: firrtl.layerblock @A {
  // CHECK:   "unknown"(%pure_o)
  // CHECK: }
  firrtl.module @PortSelectorParamChoice(in %impl: !firrtl.choice<@Impl>) {
    %c0_ui1 = firrtl.constant 0 : !firrtl.uint<1>
    %pure_i, %pure_o = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@Pure, @PureFast], caseNames = [@Impl::@Fast],
      name = "pure", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: false, true>, portNames = ["i", "o"],
      domainInfo = [[], []], annotations = [], portAnnotations = [[], []],
      layers = []
    }> : (!firrtl.choice<@Impl>) -> (!firrtl.uint<1>, !firrtl.uint<1>)
    firrtl.matchingconnect %pure_i, %c0_ui1 : !firrtl.uint<1>
    firrtl.layerblock @A {
      "unknown"(%pure_o) : (!firrtl.uint<1>) -> ()
    }
  }
}
