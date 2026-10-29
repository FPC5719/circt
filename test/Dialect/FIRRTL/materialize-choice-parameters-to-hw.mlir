// RUN: circt-opt --firrtl-materialize-choice-parameters --lower-firrtl-to-hw %s | FileCheck %s

// CHECK: hw.module @Leaf<impl: i2>
// CHECK: hw.module @MaterializeChoiceParametersToHW
// CHECK: hw.instance "literal" @Leaf<impl: i2 = 1>

firrtl.circuit "MaterializeChoiceParametersToHW" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }
  firrtl.module @Leaf(in %impl : !firrtl.choice<@Impl>) {}
  firrtl.module @MaterializeChoiceParametersToHW() {
    %fast = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %literal = firrtl.instance literal @Leaf(in impl : !firrtl.choice<@Impl>)
    firrtl.propassign %literal, %fast : !firrtl.choice<@Impl>
  }
}
