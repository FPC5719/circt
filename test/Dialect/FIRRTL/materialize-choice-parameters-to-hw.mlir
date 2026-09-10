// RUN: circt-opt --firrtl-materialize-choice-parameters --lower-firrtl-to-hw %s | FileCheck %s
// RUN: circt-opt --firrtl-materialize-choice-parameters --lower-firrtl-to-hw --export-verilog %s | FileCheck %s --check-prefix=SV

// CHECK-LABEL: hw.module @DefaultImpl
// CHECK-LABEL: hw.module @FastImpl
// CHECK-LABEL: hw.module @SmallImpl
// CHECK-LABEL: hw.module @Leaf<impl: i2>
// CHECK:         %selected.out = sv.wire : !hw.inout<i8>
// CHECK:         sv.generate "selected" : {
// CHECK-NEXT:      sv.generate.case #hw.param.decl.ref<"impl"> : i2 [
// CHECK-NEXT:        case (1 : i2, "case_Fast") {
// CHECK:               {{.*}} = hw.instance "selected_case_Fast" @FastImpl() -> (out: i8)
// CHECK:               sv.assign {{.*}}, {{.*}}
// CHECK:             }
// CHECK:             case (-2 : i2, "case_Small") {
// CHECK:               {{.*}} = hw.instance "selected_case_Small" @SmallImpl() -> (out: i8)
// CHECK:             }
// CHECK:             case (unit, "default") {
// CHECK:               {{.*}} = hw.instance "selected_default" @DefaultImpl() -> (out: i8)
// CHECK:             }
// CHECK:           ]
// CHECK-LABEL: hw.module @LiteralLeaf
// CHECK:         {{.*}} = hw.instance "selected" @FastImpl() -> (out: i8)
// CHECK-NOT:     sv.generate
// CHECK-LABEL: hw.module @MaterializeChoiceParametersToHW
// CHECK:         hw.instance "literal" @Leaf<impl: i2 = 1>() -> (out: i8)

// SV-LABEL: module Leaf
// SV:       #(parameter [1:0] impl)
// SV:       generate
// SV:       begin: selected
// SV:         case (impl)
// SV:           1: begin: case_Fast
// SV:             FastImpl selected_case_Fast (
// SV:             .out (selected_out)
// SV:           2: begin: case_Small
// SV:             SmallImpl selected_case_Small (
// SV:             .out (selected_out)
// SV:           default: begin: default
// SV:             DefaultImpl selected_default (
// SV:             .out (selected_out)
// SV:           endcase
// SV:         end: selected
// SV:       endgenerate
// SV-LABEL: module MaterializeChoiceParametersToHW
// SV:       Leaf #(
// SV:       .impl(1)
// SV:       ) literal (

firrtl.circuit "MaterializeChoiceParametersToHW" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Default = 0
    firrtl.choice_case @Fast = 1
    firrtl.choice_case @Small = 2
  }
  firrtl.module @DefaultImpl(out %out : !firrtl.uint<8>) {
    %value = firrtl.constant 0 : !firrtl.uint<8>
    firrtl.connect %out, %value : !firrtl.uint<8>
  }
  firrtl.module @FastImpl(out %out : !firrtl.uint<8>) {
    %value = firrtl.constant 1 : !firrtl.uint<8>
    firrtl.connect %out, %value : !firrtl.uint<8>
  }
  firrtl.module @SmallImpl(out %out : !firrtl.uint<8>) {
    %value = firrtl.constant 2 : !firrtl.uint<8>
    firrtl.connect %out, %value : !firrtl.uint<8>
  }
  firrtl.module @Leaf(in %impl : !firrtl.choice<@Impl>, out %out : !firrtl.uint<8>) {
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@DefaultImpl, @FastImpl, @SmallImpl],
      caseNames = [@Impl::@Fast, @Impl::@Small], name = "selected",
      nameKind = #firrtl<name_kind droppable_name>, portDirections = array<i1: true>,
      portNames = ["out"], domainInfo = [[]], annotations = [], portAnnotations = [[]],
      layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }
  firrtl.module @LiteralLeaf(out %out : !firrtl.uint<8>) {
    %fast = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %selected = "firrtl.param_instance_choice"(%fast) <{
      moduleNames = [@DefaultImpl, @FastImpl, @SmallImpl],
      caseNames = [@Impl::@Fast, @Impl::@Small], name = "selected",
      nameKind = #firrtl<name_kind droppable_name>, portDirections = array<i1: true>,
      portNames = ["out"], domainInfo = [[]], annotations = [], portAnnotations = [[]],
      layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }
  firrtl.module @MaterializeChoiceParametersToHW() {
    %fast = firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
    %literal_impl, %literal_out = firrtl.instance literal @Leaf(in impl : !firrtl.choice<@Impl>, out out : !firrtl.uint<8>)
    firrtl.propassign %literal_impl, %fast : !firrtl.choice<@Impl>
  }
}
