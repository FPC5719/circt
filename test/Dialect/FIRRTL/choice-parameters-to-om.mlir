// RUN: circt-opt --firrtl-materialize-choice-parameters --firrtl-lower-classes %s | FileCheck %s

// Ordinary property metadata must keep lowering to OM classes alongside
// parameterized instance choices.  Materialization consumes the choice
// properties before `firrtl-lower-classes` runs, so no choice port or choice
// value can be mistaken for OM metadata.
firrtl.circuit "ChoiceAndMetadata" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
  }

  firrtl.module private @DefaultImpl(out %out: !firrtl.uint<8>) {}
  firrtl.module private @FastImpl(out %out: !firrtl.uint<8>) {}

  firrtl.class private @Metadata(out %value: !firrtl.integer) {
    %c = firrtl.integer 3
    firrtl.propassign %value, %c : !firrtl.integer
  }

  // CHECK-LABEL: firrtl.module private @Leaf
  // CHECK-SAME: <impl: i2>
  firrtl.module private @Leaf(in %impl: !firrtl.choice<@Impl>,
                              out %out: !firrtl.uint<8>) {
    // CHECK: "firrtl.param_instance_choice"
    // CHECK-SAME: selectorParameter = #firrtl.param.decl<"selector": i2 = #firrtl.param.decl.ref<"impl">>
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl],
      caseNames = [@Impl::@Fast],
      name = "selected", nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"], domainInfo = [[]],
      annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }

  // CHECK-LABEL: firrtl.module @ChoiceAndMetadata
  firrtl.module @ChoiceAndMetadata(out %out: !firrtl.uint<8>) {
    %fast = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    // CHECK: firrtl.instance leaf
    // CHECK-SAME: parameters = [#firrtl.param.decl<"impl": i2 = 1> : i2]
    %leaf_impl, %leaf_out = firrtl.instance leaf @Leaf(in impl: !firrtl.choice<@Impl>, out out: !firrtl.uint<8>)
    firrtl.propassign %leaf_impl, %fast : !firrtl.choice<@Impl>
    firrtl.connect %out, %leaf_out : !firrtl.uint<8>
  }
}

// The class is lowered to OM metadata even though the circuit also contains
// choice parameters.  `firrtl-lower-classes` emits the classes at the end.
// CHECK-LABEL: om.class private @Metadata
// CHECK: %[[C:.+]] = om.constant #om.integer<3
// CHECK: om.class.fields %[[C]] : !om.integer
// No choice property may survive to the OM lowering.
// CHECK-NOT: !firrtl.choice
