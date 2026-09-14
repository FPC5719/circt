// RUN: circt-translate --export-firrtl %s -o %t
// RUN: FileCheck %s < %t

// CHECK: FIRRTL version 7.0.0
// CHECK: circuit ChoiceEmit :
// CHECK-NEXT:   choice_domain Impl width 2 :
// CHECK-NEXT:     choice_case Default = 0
// CHECK-NEXT:     choice_case Fast = 1
// CHECK:   public module ChoiceEmit :
// CHECK-NEXT:     input impl : Choice of Impl
firrtl.circuit "ChoiceEmit" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }
  firrtl.module @ChoiceEmit(in %impl: !firrtl.choice<@Impl>) {}
}
