// RUN: circt-opt --split-input-file --verify-diagnostics %s

// Choice domains are circuit-scoped symbols and choice values are nominal
// property values. The exact type is retained by propassign's SameType rule.
firrtl.circuit "ChoiceTypes" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
    firrtl.choice_case @Small = 2
  }

  firrtl.module @ChoiceTypes(in %impl: !firrtl.choice<@Impl>) {
    %fast = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
  }
}

// -----

firrtl.circuit "ZeroWidth" {
  // expected-error @+1 {{width must be between 1 and 64}}
  firrtl.choice_domain @Impl width 0 {
    firrtl.choice_case @Default = 0
  }
}

// -----

firrtl.circuit "TooWide" {
  firrtl.choice_domain @Impl width 2 {
    // expected-error @+1 {{value 4 does not fit domain width 2}}
    firrtl.choice_case @Bad = 4
  }
}

// -----

firrtl.circuit "Duplicate" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @A = 1
    // expected-error @+1 {{duplicate choice encoding 1}}
    firrtl.choice_case @B = 1
  }
}

// -----

firrtl.circuit "ChoiceOutput" {
  // expected-error @+1 {{choice port 'impl' must be an input property}}
  firrtl.module @ChoiceOutput(out %impl: !firrtl.choice<@Impl>) {}
}

// -----

firrtl.circuit "UnknownDomain" {
  // expected-error @+1 {{choice port 'impl' references undefined choice domain 'Missing'}}
  firrtl.module @UnknownDomain(in %impl: !firrtl.choice<@Missing>) {}
}

// -----

firrtl.circuit "WrongDomain" {
  firrtl.option @NotAChoiceDomain {
    firrtl.option_case @Case
  }
  // expected-error @+1 {{choice port 'impl' references symbol 'NotAChoiceDomain' which is not a choice domain}}
  firrtl.module @WrongDomain(in %impl: !firrtl.choice<@NotAChoiceDomain>) {}
}

// -----

firrtl.circuit "UnknownCase" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Known = 0
  }
  firrtl.module @Use() {
    // expected-error @+1 {{choice domain "Impl" does not contain choice case @Impl::@Missing}}
    %unknown = firrtl.choice.constant @Impl::@Missing : !firrtl.choice<@Impl>
  }
}

// -----

firrtl.circuit "MismatchedDomain" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @A = 0
  }
  firrtl.choice_domain @Other width 2 {
    firrtl.choice_case @A = 0
  }
  firrtl.module @Use() {
    // expected-error @+1 {{result type '!firrtl.choice<@Impl>' does not match choice domain "Other"}}
    %wrongType = firrtl.choice.constant @Other::@A : !firrtl.choice<@Impl>
  }
}

// -----

firrtl.circuit "UnknownChoice" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @A = 0
  }
  firrtl.module @Use() {
    // expected-error @+1 {{cannot produce an unknown choice value}}
    %unknown = firrtl.unknown : !firrtl.choice<@Impl>
  }
}

// -----

firrtl.circuit "ChoiceList" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @A = 0
  }
  firrtl.module @Use(
    // expected-error @+1 {{choice types cannot be list elements}}
    in %choices: !firrtl.list<choice<@Impl>>) {}
}

// -----

firrtl.circuit "ChoiceClass" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @A = 0
  }
  // expected-error @+1 {{choice properties are not allowed on classes}}
  firrtl.class @ChoiceClass(in %impl: !firrtl.choice<@Impl>) {}
}
