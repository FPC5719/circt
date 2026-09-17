// RUN: circt-opt --firrtl-probes-to-signals %s | FileCheck %s

// Parameterized instance choices participate in probe-to-signal conversion like
// any other instance-like operation.  Probe ports are rejected by the op
// verifier, so only the handling path is exercised here.
firrtl.circuit "ProbesToSignalsChoiceParameter" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module private @FastImpl(out %out: !firrtl.uint<8>) {}

  // CHECK-LABEL: firrtl.module @ProbesToSignalsChoiceParameter
  firrtl.module @ProbesToSignalsChoiceParameter(in %impl: !firrtl.choice<@Impl>,
                                                out %out: !firrtl.uint<8>) {
    // CHECK: %sel_out = "firrtl.param_instance_choice"(%impl)
    %sel = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl], caseNames = [@Impl::@Fast],
      name = "sel", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %sel : !firrtl.uint<8>

    // Probes are still converted to signals alongside the choice.
    // CHECK: %source_p = firrtl.instance source
    // CHECK: firrtl.matchingconnect %p, %source_p
    %source_p = firrtl.instance source @ProbeSource(out p: !firrtl.probe<uint<8>>)
    %p = firrtl.wire : !firrtl.probe<uint<8>>
    firrtl.ref.define %p, %source_p : !firrtl.probe<uint<8>>
    %r = firrtl.ref.resolve %p : !firrtl.probe<uint<8>>
    %w = firrtl.wire : !firrtl.uint<8>
    firrtl.connect %w, %r : !firrtl.uint<8>
  }

  firrtl.module private @ProbeSource(out %p: !firrtl.probe<uint<8>>) {
    %c = firrtl.constant 0 : !firrtl.uint<8>
    %r = firrtl.ref.send %c : !firrtl.uint<8>
    firrtl.ref.define %p, %r : !firrtl.probe<uint<8>>
  }
}
