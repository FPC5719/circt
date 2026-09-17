// RUN: circt-opt --split-input-file --verify-diagnostics %s

// A parameterized instance choice may only be instantiated under the layers its
// candidate modules require.
firrtl.circuit "MissingAmbientLayer" {
  firrtl.layer @A bind {}

  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %o: !firrtl.uint<1>)
      attributes {layers = [@A]} {}
  firrtl.module private @FastImpl(out %o: !firrtl.uint<1>)
      attributes {layers = [@A]} {}

  firrtl.module @MissingAmbientLayer(
      in %impl: !firrtl.choice<@Impl>, out %out: !firrtl.uint<1>) {
    // expected-note @+2 {{missing layer requirements: @A}}
    // expected-error @+1 {{ambient layers are insufficient to instantiate module}}
    %sel = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl], caseNames = [@Impl::@Fast],
      name = "sel", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["o"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = [@A]
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<1>
    firrtl.connect %out, %sel : !firrtl.uint<1>
  }
}

// -----

// The same instance inside its layer block is accepted.
firrtl.circuit "AmbientLayer" {
  firrtl.layer @A bind {}

  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl() attributes {layers = [@A]} {}
  firrtl.module private @FastImpl() attributes {layers = [@A]} {}

  firrtl.module @AmbientLayer() {
    firrtl.layerblock @A {
      %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
      "firrtl.param_instance_choice"(%impl) <{
        moduleNames = [@DefaultImpl, @FastImpl], caseNames = [@Impl::@Fast],
        name = "sel", nameKind = #firrtl<name_kind droppable_name>,
        portDirections = array<i1>, portNames = [], domainInfo = [],
        annotations = [], portAnnotations = [], layers = [@A]
      }> : (!firrtl.choice<@Impl>) -> ()
    }
  }
}
