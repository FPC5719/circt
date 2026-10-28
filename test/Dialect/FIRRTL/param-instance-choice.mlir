// RUN: circt-opt --canonicalize --mlir-print-op-generic %s | FileCheck %s

// CHECK: "firrtl.instance"
// CHECK-SAME: moduleName = @FastImpl
// CHECK-NOT: "firrtl.param_instance_choice"
// CHECK: "firrtl.instance_choice"
// CHECK: "firrtl.param_instance_choice"
firrtl.circuit "ParamInstanceChoice" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
    firrtl.choice_case @Small = 2
  }
  firrtl.module @DefaultImpl(out %out : !firrtl.uint<8>) {}
  firrtl.module @FastImpl(out %out : !firrtl.uint<8>) {}
  firrtl.module @SmallImpl(out %out : !firrtl.uint<8>) {}
  firrtl.option @Legacy { firrtl.option_case @Enabled }
  firrtl.module @LegacyDefault() {}
  firrtl.module @LegacyAlternative() {}
  firrtl.module @ParamInstanceChoice() {
    %fast = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %result = "firrtl.param_instance_choice"(%fast) <{
      moduleNames = [@DefaultImpl, @FastImpl, @SmallImpl],
      caseNames = [@Impl::@Fast, @Impl::@Small],
      name = "inner",
      nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>,
      portNames = ["out"], domainInfo = [[]], annotations = [],
      portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.instance_choice legacy @LegacyDefault alternatives @Legacy
      { @Enabled -> @LegacyAlternative } ()
  }
}

// Two independent choice inputs can select different implementations in one
// parent. A choice is forwarded across the Mid-to-Leaf module boundary with
// propassign; it remains unresolved because only literal selectors fold.
firrtl.circuit "Forwarding" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @A = 0
    firrtl.choice_case @B = 1
  }
  firrtl.module @Default() {}
  firrtl.module @AImpl() {}
  firrtl.module @BImpl() {}
  firrtl.module @Leaf(in %impl : !firrtl.choice<@Impl>) {
    "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@Default, @AImpl, @BImpl],
      caseNames = [@Impl::@A, @Impl::@B], name = "impl",
      nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1>, portNames = [], domainInfo = [],
      annotations = [], portAnnotations = [], layers = []
    }> : (!firrtl.choice<@Impl>) -> ()
  }
  firrtl.module @Mid(in %first : !firrtl.choice<@Impl>,
                     in %second : !firrtl.choice<@Impl>) {
    %firstImpl = firrtl.instance first @Leaf(in impl : !firrtl.choice<@Impl>)
    %secondImpl = firrtl.instance second @Leaf(in impl : !firrtl.choice<@Impl>)
    firrtl.propassign %firstImpl, %first : !firrtl.choice<@Impl>
    firrtl.propassign %secondImpl, %second : !firrtl.choice<@Impl>
  }
  firrtl.module @Forwarding() {}
}
