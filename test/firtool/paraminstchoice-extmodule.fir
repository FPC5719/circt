; RUN: firtool %s --format=fir --ir-hw | FileCheck %s --check-prefix=HW
; RUN: firtool %s --format=fir --verilog | FileCheck %s --check-prefix=SV

FIRRTL version 7.0.0
circuit ExtParamInstChoice:
  choice_domain Impl width 2:
    choice_case Default = 0
    choice_case Fast = 1

  extmodule ExternalDefault:
    output out: UInt<8>
    parameter WIDTH = 8

  extmodule ExternalFast:
    output out: UInt<8>
    parameter WIDTH = 16

  module ExtLeaf:
    input impl: Choice of Impl
    output out: UInt<8>
    paraminstchoice selected impl of ExternalDefault:
      Fast => ExternalFast
    connect out, selected.out

  public module ExtParamInstChoice:
    output out: UInt<8>
    inst leaf of ExtLeaf
    propassign leaf.impl, choice(Impl, Fast)
    connect out, leaf.out

; HW-LABEL: hw.module.extern private @ExternalDefault<WIDTH: ui32>
; HW-LABEL: hw.module.extern private @ExternalFast<WIDTH: ui32>
; HW-LABEL: hw.module private @ExtLeaf<impl: i2>
; HW:       sv.generate.case #hw.param.decl.ref<"impl"> : i2
; HW:       hw.instance "selected_case_Fast" @ExternalFast<WIDTH: ui32 = 16>()
; HW:       hw.instance "selected_default" @ExternalDefault<WIDTH: ui32 = 8>()
; HW-LABEL: hw.module @ExtParamInstChoice
; HW:       hw.instance "leaf" @ExtLeaf<impl: i2 = 1>()

; SV-LABEL: module ExtLeaf
; SV:       #(parameter [1:0] impl)
; SV:       case (impl)
; SV:       1: begin: case_Fast
; SV:       ExternalFast #(
; SV:       .WIDTH(16)
; SV:       ) selected_case_Fast (
; SV:       default: begin: default
; SV:       ExternalDefault #(
; SV:       .WIDTH(8)
; SV:       ) selected_default (
; SV-LABEL: module ExtParamInstChoice
; SV:       ExtLeaf #(
; SV:       .impl(1)
; SV:       ) leaf (
