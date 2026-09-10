// RUN: circt-opt --firrtl-materialize-choice-parameters --verify-each %s | FileCheck %s

// CHECK-NOT: !firrtl.choice
// CHECK-NOT: firrtl.propassign
// CHECK: firrtl.module @Leaf<impl: i2>()
// CHECK: selectorParameter = #firrtl.param.decl<"selector": i2 = #firrtl.param.decl.ref<"impl">>
// CHECK: firrtl.module @Parent<impl: i2>()
// CHECK: firrtl.instance child {parameters = [#firrtl.param.decl<"impl": i2 = #firrtl.param.decl.ref<"impl">> : i2]} @Leaf()
// CHECK: firrtl.instance literal {parameters = [#firrtl.param.decl<"impl": i2 = 1> : i2]} @Leaf()
// CHECK: firrtl.module @Top<impl: i2>()
// CHECK: firrtl.instance parent {parameters = [#firrtl.param.decl<"impl": i2 = #firrtl.param.decl.ref<"impl">> : i2]} @Parent()
// CHECK: firrtl.module @Plain(in %label: !firrtl.string)

firrtl.circuit "MaterializeChoiceParameters" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }
  firrtl.module @DefaultImpl() {}
  firrtl.module @FastImpl() {}
  firrtl.module @Leaf(in %impl : !firrtl.choice<@Impl>) {
    "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl], caseNames = [@Impl::@Fast],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1>, portNames = [], domainInfo = [],
      annotations = [], portAnnotations = [], layers = []
    }> : (!firrtl.choice<@Impl>) -> ()
  }
  firrtl.module @Parent(in %impl : !firrtl.choice<@Impl>) {
    %child = firrtl.instance child @Leaf(in impl : !firrtl.choice<@Impl>)
    firrtl.propassign %child, %impl : !firrtl.choice<@Impl>
    %fast = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %literal = firrtl.instance literal @Leaf(in impl : !firrtl.choice<@Impl>)
    firrtl.propassign %literal, %fast : !firrtl.choice<@Impl>
  }
  firrtl.module @Top(in %impl : !firrtl.choice<@Impl>) {
    %parent = firrtl.instance parent @Parent(in impl : !firrtl.choice<@Impl>)
    firrtl.propassign %parent, %impl : !firrtl.choice<@Impl>
  }
  firrtl.module @Plain(in %label : !firrtl.string) {}
  firrtl.module @MaterializeChoiceParameters() {}
}
