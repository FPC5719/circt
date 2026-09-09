// RUN: circt-opt --split-input-file --verify-diagnostics --allow-unregistered-dialect %s

firrtl.circuit "Mismatch" {
  firrtl.choice_domain @Impl width 1 { firrtl.choice_case @A = 0 }
  firrtl.choice_domain @Other width 1 { firrtl.choice_case @A = 0 }
  firrtl.module @Default(out %out : !firrtl.uint<1>) {}
  firrtl.module @Alternative(out %out : !firrtl.uint<1>) {}
  firrtl.module @Mismatch(in %impl : !firrtl.choice<@Impl>) {
    // expected-error @+1 {{is not in selector domain "Impl"}}
    %result = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@Default, @Alternative], caseNames = [@Other::@A],
      name = "inner", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"],
      domainInfo = [[]], annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<1>
  }
}

// -----

firrtl.circuit "Duplicate" {
  firrtl.choice_domain @Impl width 1 { firrtl.choice_case @A = 0 }
  firrtl.module @Default(out %out : !firrtl.uint<1>) {}
  firrtl.module @Alternative(out %out : !firrtl.uint<1>) {}
  firrtl.module @Duplicate(in %impl : !firrtl.choice<@Impl>) {
    // expected-error @+1 {{duplicate choice case @Impl::@A}}
    %result = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@Default, @Alternative, @Alternative],
      caseNames = [@Impl::@A, @Impl::@A], name = "inner",
      nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"],
      domainInfo = [[]], annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<1>
  }
}

// -----

firrtl.circuit "PortMismatch" {
  firrtl.choice_domain @Impl width 1 { firrtl.choice_case @A = 0 }
  firrtl.module @Default(out %out : !firrtl.uint<1>) {}
  // expected-note @+1 {{original module declared here}}
  firrtl.module @Alternative(out %different : !firrtl.uint<1>) {}
  firrtl.module @PortMismatch(in %impl : !firrtl.choice<@Impl>) {
    // expected-error @+1 {{name for port 0 must be "different", but got "out"}}
    %result = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@Default, @Alternative], caseNames = [@Impl::@A],
      name = "inner", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"],
      domainInfo = [[]], annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<1>
  }
}

// -----

firrtl.circuit "RuntimeSelector" {
  firrtl.choice_domain @Impl width 1 { firrtl.choice_case @A = 0 }
  firrtl.module @Default(out %out : !firrtl.uint<1>) {}
  firrtl.module @Alternative(out %out : !firrtl.uint<1>) {}
  firrtl.module @RuntimeSelector() {
    %runtime = "test.runtime_choice"() : () -> !firrtl.choice<@Impl>
    // expected-error @+1 {{selector must be an elaboration-time choice value, not the result of a hardware operation}}
    %result = "firrtl.param_instance_choice"(%runtime) <{
      moduleNames = [@Default, @Alternative], caseNames = [@Impl::@A],
      name = "inner", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"],
      domainInfo = [[]], annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<1>
  }
}
