// RUN: circt-opt --firrtl-materialize-choice-parameters --verify-each %s \
// RUN:   | FileCheck %s --implicit-check-not='!firrtl.choice' \
// RUN:       --implicit-check-not='firrtl.propassign'

// CHECK: firrtl.module @ParamChoiceDefault<impl: i2>(out %out: !firrtl.uint<1>)
// CHECK: firrtl.module @ParamChoiceFast<impl: i2>(out %out: !firrtl.uint<1>)
// CHECK: %choice_out = "firrtl.param_instance_choice"()
// CHECK-SAME: parameters = [#firrtl.param.decl<"impl": i2 = 0> : i2]
// CHECK-SAME: selectorParameter = #firrtl.param.decl<"selector": i2 = 1> : i2

firrtl.circuit "ParamChoiceTop" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }
  firrtl.module @ParamChoiceDefault(in %impl : !firrtl.choice<@Impl>,
                                    out %out : !firrtl.uint<1>) {}
  firrtl.module @ParamChoiceFast(in %impl : !firrtl.choice<@Impl>,
                                 out %out : !firrtl.uint<1>) {}
  firrtl.module @ParamChoiceTop() {
    %selector = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %impl = firrtl.choice.constant @Impl::@Default : !firrtl.choice<@Impl>
    %choice, %out = "firrtl.param_instance_choice"(%selector) <{
      moduleNames = [@ParamChoiceDefault, @ParamChoiceFast],
      caseNames = [@Impl::@Fast], name = "choice",
      nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: false, true>, portNames = ["impl", "out"],
      domainInfo = [[], []], annotations = [], portAnnotations = [[], []],
      layers = []
    }> : (!firrtl.choice<@Impl>) -> (!firrtl.choice<@Impl>, !firrtl.uint<1>)
    firrtl.propassign %choice, %impl : !firrtl.choice<@Impl>
  }
}
