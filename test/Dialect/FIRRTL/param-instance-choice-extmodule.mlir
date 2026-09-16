// RUN: circt-opt --canonicalize --mlir-print-op-generic %s | FileCheck %s --check-prefix=CANON
// RUN: circt-opt --firrtl-materialize-choice-parameters --lower-firrtl-to-hw %s | FileCheck %s
// RUN: circt-opt --firrtl-materialize-choice-parameters --lower-firrtl-to-hw --export-verilog %s | FileCheck %s --check-prefix=SV

// CANON: "firrtl.param_instance_choice"
// CANON: "firrtl.instance"
// CANON-SAME: moduleName = @ExtAlternative

// CHECK-LABEL: hw.module @ExtLeaf<impl: i2>
// CHECK:         sv.generate.case #hw.param.decl.ref<"impl"> : i2 [
// CHECK-NEXT:      case (0 : i2, "case_Alt") {
// CHECK:             hw.instance "selected_case_Alt" @ExtAlternative<WIDTH: i32 = 16>()
// CHECK:           case (1 : i2, "case_Other") {
// CHECK:             hw.instance "selected_case_Other" @InternalImpl()
// CHECK:           case (-2 : i2, "case_Plain") {
// CHECK:             hw.instance "selected_case_Plain" @ExtPlain()
// CHECK:           case (unit, "default") {
// CHECK:             hw.instance "selected_default" @ExtDefault<WIDTH: i32 = 8>()
// CHECK-LABEL: hw.module @ExtLiteralLeaf
// CHECK:         hw.instance "selected" @ExtAlternative<WIDTH: i32 = 16>()
// CHECK-NOT:     sv.generate

// SV-LABEL: module ExtLeaf
// SV:       #(parameter [1:0] impl)
// SV:       case (impl)
// SV:           0: begin: case_Alt
// SV:             ExtAlternative #(
// SV:             .WIDTH(16)
// SV:             ) selected_case_Alt (
// SV:             .out (selected_out)
// SV:           1: begin: case_Other
// SV:             InternalImpl selected_case_Other (
// SV:             .out (selected_out)
// SV:           2: begin: case_Plain
// SV:             ExtPlain selected_case_Plain (
// SV:             .out (selected_out)
// SV:           default: begin: default
// SV:             ExtDefault #(
// SV:             .WIDTH(8)
// SV:             ) selected_default (
// SV:             .out (selected_out)
// SV-LABEL: module ExtLiteralLeaf
// SV:       ExtAlternative #(
// SV:       .WIDTH(16)
// SV:       ) selected (

firrtl.circuit "ExtModuleParamInstanceChoice" {
  firrtl.choice_domain @Impl width 2 {
    firrtl.choice_case @Alt = 0
    firrtl.choice_case @Other = 1
    firrtl.choice_case @Plain = 2
  }
  firrtl.extmodule @ExtDefault<WIDTH: i32 = 8>(out out: !firrtl.uint<8>)
  firrtl.extmodule @ExtAlternative<WIDTH: i32 = 16>(out out: !firrtl.uint<8>)
  firrtl.module @InternalImpl(out %out: !firrtl.uint<8>) {}
  firrtl.extmodule @ExtPlain(out out: !firrtl.uint<8>)

  firrtl.module @ExtLeaf(in %impl: !firrtl.choice<@Impl>, out %out: !firrtl.uint<8>) {
    %selected = "firrtl.param_instance_choice"(%impl) <{
      moduleNames = [@ExtDefault, @ExtAlternative, @InternalImpl, @ExtPlain],
      caseNames = [@Impl::@Alt, @Impl::@Other, @Impl::@Plain], name = "selected",
      nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"],
      domainInfo = [[]], annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }

  firrtl.module @ExtLiteralLeaf(out %out: !firrtl.uint<8>) {
    %alt = firrtl.choice.constant @Impl::@Alt : !firrtl.choice<@Impl>
    %selected = "firrtl.param_instance_choice"(%alt) <{
      moduleNames = [@ExtDefault, @ExtAlternative, @InternalImpl, @ExtPlain],
      caseNames = [@Impl::@Alt, @Impl::@Other, @Impl::@Plain], name = "selected",
      nameKind = #firrtl<name_kind droppable_name>,
      portDirections = array<i1: true>, portNames = ["out"],
      domainInfo = [[]], annotations = [], portAnnotations = [[]], layers = []
    }> : (!firrtl.choice<@Impl>) -> !firrtl.uint<8>
    firrtl.connect %out, %selected : !firrtl.uint<8>
  }

  firrtl.module @ExtModuleParamInstanceChoice() {}
}
