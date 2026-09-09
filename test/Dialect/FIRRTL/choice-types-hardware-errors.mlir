// RUN: circt-opt --verify-diagnostics %s

// Choices are property values, not hardware values.  The normal FIRRTL
// operation constraints reject them before they can participate in dataflow.
firrtl.circuit "ChoiceHardwareErrors" {
  firrtl.choice_domain @Implementation width 1 {
    firrtl.choice_case @A = 0
  }
  firrtl.module @ChoiceHardwareErrors() {
    %choice = firrtl.choice.constant @Implementation::@A : !firrtl.choice<@Implementation>
    // expected-error @+1 {{operand #0 must be sint or uint type, but got '!firrtl.choice<@Implementation>'}}
    %bad = "firrtl.add"(%choice, %choice) : (!firrtl.choice<@Implementation>, !firrtl.choice<@Implementation>) -> !firrtl.choice<@Implementation>
  }
}
