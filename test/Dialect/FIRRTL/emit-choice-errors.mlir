// RUN: circt-translate --export-firrtl --firrtl-version=6.0.0 --verify-diagnostics %s

firrtl.circuit "ChoiceEmitOld" {
  // expected-error @+1 {{choice domains requires FIRRTL 7.0.0}}
  firrtl.choice_domain @Impl width 1 {
    firrtl.choice_case @A = 0
  }
  firrtl.module @ChoiceEmitOld() {}
}
