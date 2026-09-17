// UNSUPPORTED: system-windows
// RUN: circt-reduce %s --include=module-name-sanitizer --test /usr/bin/env --test-arg true --keep-best=0 | FileCheck %s

// The module name sanitizer renames modules and their ports, and must update
// the debug instance name and the port names of a parameterized instance
// choice, exactly like it does for an option-based instance choice.

// CHECK: firrtl.module private @[[TARGET:[A-Za-z]+]]
// CHECK: "firrtl.param_instance_choice"{{.*}}moduleNames = [@[[TARGET:[A-Za-z]+]], @{{[A-Za-z]+}}]{{.*}}name = "[[TARGET]]"{{.*}}portNames = ["a", "b"]
firrtl.circuit "Top" {
  firrtl.choice_domain @Impl width 1 {
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @Default(in %i: !firrtl.uint<1>,
                                 in %j: !firrtl.uint<1>) {}
  firrtl.module private @Alternative(in %i: !firrtl.uint<1>,
                                     in %j: !firrtl.uint<1>) {}

  firrtl.module @Top(in %impl: !firrtl.choice<@Impl>) {
    %sel_i, %sel_j = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@Default, @Alternative], caseNames = [@Impl::@Fast],
      name = "sel", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: false, false>, portNames = ["i", "j"],
      domainInfo = [[], []], annotations = [], portAnnotations = [[], []],
      layers = []
    }> : (!firrtl.choice<@Impl>) -> (!firrtl.uint<1>, !firrtl.uint<1>)
  }
}
