// RUN: circt-opt %s | FileCheck %s

// CHECK-LABEL: firrtl.circuit "ChoiceRoundTrip"
// CHECK: firrtl.choice_domain @Implementation width 3 {
// CHECK-NEXT: firrtl.choice_case @Default = 0
// CHECK-NEXT: firrtl.choice_case @Fast = 3
// CHECK-NEXT: firrtl.choice_case @Small = 7
// CHECK: firrtl.module @ChoiceRoundTrip(in %impl: !firrtl.choice<@Implementation>)
// CHECK: firrtl.choice.constant @Implementation::@Fast : !firrtl.choice<@Implementation>
firrtl.circuit "ChoiceRoundTrip" {
  firrtl.choice_domain @Implementation width 3 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 3
    firrtl.choice_case @Small = 7
  }

  firrtl.module @ChoiceRoundTrip(in %impl: !firrtl.choice<@Implementation>) {
    %fast = firrtl.choice.constant @Implementation::@Fast : !firrtl.choice<@Implementation>
  }
}
