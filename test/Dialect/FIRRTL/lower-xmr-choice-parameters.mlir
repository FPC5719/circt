// RUN: circt-opt --firrtl-lower-xmr %s | FileCheck %s

// Values defined by a parameterized instance choice are named with their
// instance and port, so paths, probes and XMRs built from them keep the
// instance hop.
firrtl.circuit "LowerXMRChoiceParameter" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %o: !firrtl.uint<1>) {
    %c = firrtl.constant 0 : !firrtl.uint<1>
    firrtl.connect %o, %c : !firrtl.uint<1>
  }
  firrtl.module private @FastImpl(out %o: !firrtl.uint<1>) {
    %c = firrtl.constant 1 : !firrtl.uint<1>
    firrtl.connect %o, %c : !firrtl.uint<1>
  }

  firrtl.module @LowerXMRChoiceParameter(out %p: !firrtl.probe<uint<1>>) {
    %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %sel = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl], caseNames = [@Impl::@Fast],
      name = "sel", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["o"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<1>
    // CHECK: %sel_o_probe = firrtl.node sym @sym interesting_name
    %r = firrtl.ref.send %sel : !firrtl.uint<1>
    firrtl.ref.define %p, %r : !firrtl.probe<uint<1>>
  }
}
