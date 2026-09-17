// RUN: circt-opt --pass-pipeline='builtin.module(firrtl.circuit(any(firrtl-expand-whens)))' --verify-diagnostics %s

// An unconnected input port of a parameterized instance choice must be caught
// by the initialization check, like one of a plain instance.
firrtl.circuit "UnconnectedParamChoice" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(in %i: !firrtl.uint<1>,
                                     out %o: !firrtl.uint<1>) {
    firrtl.connect %o, %i : !firrtl.uint<1>
  }
  firrtl.module private @FastImpl(in %i: !firrtl.uint<1>,
                                  out %o: !firrtl.uint<1>) {
    firrtl.connect %o, %i : !firrtl.uint<1>
  }

  firrtl.module @UnconnectedParamChoice(in %impl: !firrtl.choice<@Impl>,
                                        out %out: !firrtl.uint<1>) {
    // expected-error @+1 {{sink "sel.i" not fully initialized in "UnconnectedParamChoice"}}
    %i, %o = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl], caseNames = [@Impl::@Fast],
      name = "sel", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: false, true>, portNames = ["i", "o"],
      domainInfo = [[], []], annotations = [], portAnnotations = [[], []],
      layers = []
    }> : (!firrtl.choice<@Impl>) -> (!firrtl.uint<1>, !firrtl.uint<1>)
    firrtl.connect %out, %o : !firrtl.uint<1>
  }
}
