// RUN: circt-opt --split-input-file --firrtl-materialize-choice-parameters --verify-diagnostics --allow-unregistered-dialect %s

firrtl.circuit "Missing" {
  firrtl.choice_domain @Impl width 1 { firrtl.choice_case @A = 0 }
  firrtl.module @Leaf(in %impl : !firrtl.choice<@Impl>) {}
  firrtl.module @Missing() {
    // expected-error @+1 {{choice parameter input must have exactly one firrtl.propassign assignment}}
    %inst = firrtl.instance inst @Leaf(in impl : !firrtl.choice<@Impl>)
  }
}

// -----

firrtl.circuit "Unsupported" {
  firrtl.choice_domain @Impl width 1 { firrtl.choice_case @A = 0 }
  firrtl.module @Leaf(in %impl : !firrtl.choice<@Impl>) {}
  firrtl.module @Unsupported() {
    %unknown = "test.choice"() : () -> !firrtl.choice<@Impl>
    %inst = firrtl.instance inst @Leaf(in impl : !firrtl.choice<@Impl>)
    // expected-error @+1 {{choice parameter must be driven by a choice constant or containing-module choice parameter}}
    firrtl.propassign %inst, %unknown : !firrtl.choice<@Impl>
  }
}

// -----

firrtl.circuit "Multiple" {
  firrtl.choice_domain @Impl width 1 { firrtl.choice_case @A = 0 }
  firrtl.module @Leaf(in %impl : !firrtl.choice<@Impl>) {}
  firrtl.module @Multiple() {
    %a = firrtl.choice.constant @Impl::@A : !firrtl.choice<@Impl>
    %inst = firrtl.instance inst @Leaf(in impl : !firrtl.choice<@Impl>)
    // expected-error @+1 {{destination cannot be driven by multiple operations}}
    firrtl.propassign %inst, %a : !firrtl.choice<@Impl>
    // expected-note @+1 {{other driver is here}}
    firrtl.propassign %inst, %a : !firrtl.choice<@Impl>
  }
}

// -----

firrtl.circuit "Output" {
  firrtl.choice_domain @Impl width 1 { firrtl.choice_case @A = 0 }
  // expected-error @+1 {{choice port 'impl' must be an input property}}
  firrtl.module @Output(out %impl : !firrtl.choice<@Impl>) {}
}
