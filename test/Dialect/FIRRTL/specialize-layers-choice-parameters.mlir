// RUN: circt-opt --pass-pipeline='builtin.module(firrtl.circuit(firrtl-specialize-layers))' %s | FileCheck %s

// Enabling a layer inlines its layer block contents.  The enable-layer
// requirements of a parameterized instance choice must be specialized with the
// op, otherwise it disagrees with the (now layer-free) module it instantiates.
firrtl.circuit "SpecializeLayersChoiceParameter" attributes {
  enable_layers = [@A]
} {
  firrtl.layer @A bind {}

  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  // CHECK-LABEL: firrtl.module private @DefaultImpl
  firrtl.module private @DefaultImpl() attributes {layers = [@A]} {}
  // CHECK-LABEL: firrtl.module private @FastImpl
  firrtl.module private @FastImpl() attributes {layers = [@A]} {}

  // CHECK-LABEL: firrtl.module @SpecializeLayersChoiceParameter
  // CHECK-NOT: firrtl.layerblock
  firrtl.module @SpecializeLayersChoiceParameter() {
    firrtl.layerblock @A {
      %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
      // CHECK: "firrtl.param_instance_choice"(%{{[^)]*}})
      // CHECK-SAME: layers = []
      "firrtl.param_instance_choice"(%impl) <{
        moduleNames = [@DefaultImpl, @FastImpl], caseNames = [@Impl::@Fast],
        name = "sel", nameKind = #firrtl<name_kind droppable_name>,
        portDirections = array<i1>, portNames = [], domainInfo = [],
        annotations = [], portAnnotations = [], layers = [@A]
      }> : (!firrtl.choice<@Impl>) -> ()
    }
  }
}
