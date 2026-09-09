// RUN: circt-opt -firrtl-lower-classes --verify-diagnostics %s

// Choice properties must survive until the future materialization pass rather
// than being silently erased by generic property lowering.
firrtl.circuit "ChoiceLoweringError" {
  firrtl.choice_domain @Implementation width 1 {
    firrtl.choice_case @A = 0
  }
  // expected-error @+1 {{cannot lower choice port 'impl' as OM metadata; run choice-parameter materialization first}}
  firrtl.module @ChoiceLoweringError(in %impl: !firrtl.choice<@Implementation>) {}
}
