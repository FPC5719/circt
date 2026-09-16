// RUN: circt-opt --firrtl-extract-instances --split-input-file --verify-diagnostics %s

// A black box annotated for extraction may not be instantiated by a
// parameterized instance choice: the pass only extracts plain instances, so
// the extraction request would be silently dropped.
firrtl.circuit "ExtractChoiceParameter" attributes {annotations = [{class = "firrtl.transforms.BlackBoxTargetDirAnno", targetDir = "BlackBoxes"}]} {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.extmodule private @DefaultBB(out out: !firrtl.uint<8>) attributes {annotations = [{class = "sifive.enterprise.firrtl.ExtractBlackBoxAnnotation", filename = "BlackBoxes.txt", prefix = "bb"}], defname = "DefaultBB"}
  firrtl.extmodule private @FastBB(out out: !firrtl.uint<8>) attributes {defname = "FastBB"}

  firrtl.module private @Leaf(in %impl: !firrtl.choice<@Impl>,
                              out %out: !firrtl.uint<8>) {
    // expected-error @+1 {{cannot extract a parameterized instance choice of module 'DefaultBB'}}
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultBB, @FastBB],
      caseNames = [@Impl::@Fast],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }

  firrtl.module @ExtractChoiceParameter(out %out: !firrtl.uint<8>) {
    %impl = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %leaf_impl, %leaf_out = firrtl.instance leaf @Leaf(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    firrtl.propassign %leaf_impl, %impl : !firrtl.choice<@Impl>
    firrtl.connect %out, %leaf_out : !firrtl.uint<8>
  }
}
