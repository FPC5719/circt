// RUN: circt-opt -pass-pipeline='builtin.module(firrtl.circuit(firrtl-check-comb-loops))' --verify-diagnostics --split-input-file %s

// Combinational paths through a parameterized instance choice must be
// considered for every alternative, like those through an option-based
// instance choice.

firrtl.circuit "ChoiceLoop" {
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

  // expected-error @below {{detected combinational cycle in a FIRRTL module, sample path: ChoiceLoop.{l.i <- l.o <- l.i}}}
  firrtl.module @ChoiceLoop(in %impl: !firrtl.choice<@Impl>) {
    %i, %o = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl], caseNames = [@Impl::@Fast],
      name = "l", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: false, true>, portNames = ["i", "o"],
      domainInfo = [[], []], annotations = [], portAnnotations = [[], []],
      layers = []
    }> : (!firrtl.choice<@Impl>) -> (!firrtl.uint<1>, !firrtl.uint<1>)
    firrtl.connect %i, %o : !firrtl.uint<1>
  }
}

// -----

// A parameterized choice without a cycle must be accepted.
firrtl.circuit "NoLoop" {
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

  firrtl.module @NoLoop(in %impl: !firrtl.choice<@Impl>,
                        out %out: !firrtl.uint<1>) {
    %i, %o = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl], caseNames = [@Impl::@Fast],
      name = "l", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: false, true>, portNames = ["i", "o"],
      domainInfo = [[], []], annotations = [], portAnnotations = [[], []],
      layers = []
    }> : (!firrtl.choice<@Impl>) -> (!firrtl.uint<1>, !firrtl.uint<1>)
    firrtl.connect %out, %o : !firrtl.uint<1>
  }
}
