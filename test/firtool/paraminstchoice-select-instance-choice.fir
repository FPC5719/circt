; RUN: firtool %s --verilog --select-instance-choice=Platform=FPGA | FileCheck %s --check-prefix=SELECT
; RUN: firtool %s --verilog | FileCheck %s --check-prefix=DEFAULT

; Specializing a global option-based instance choice must not affect
; elaboration-time parameter choices.  The global `Platform` option is resolved
; by `--select-instance-choice`, while the `Impl` parameter choice remains a
; parameter and a `generate case` construct.

FIRRTL version 7.0.0
circuit Top:
  option Platform:
    FPGA

  choice_domain Impl width 2:
    choice_case Default = 0
    choice_case Fast = 1

  module DefaultTarget:
    input i: UInt<8>
    output result: UInt<8>
    connect result, UInt<8>(0)

  module FPGATarget:
    input i: UInt<8>
    output result: UInt<8>
    connect result, i

  module DefaultImpl:
    output out: UInt<8>
    connect out, UInt<8>(2)

  module FastImpl:
    output out: UInt<8>
    connect out, UInt<8>(3)

  module Leaf:
    input impl: Choice of Impl
    output out: UInt<8>
    paraminstchoice selected impl of DefaultImpl:
      Fast => FastImpl
    connect out, selected.out

  module Outer:
    input impl: Choice of Impl
    output out: UInt<8>
    inst leaf of Leaf
    propassign leaf.impl, impl
    connect out, leaf.out

  public module Top:
    input i: UInt<8>
    output legacy: UInt<8>
    output first: UInt<8>
    output second: UInt<8>

    instchoice proc of DefaultTarget, Platform:
      FPGA => FPGATarget
    connect proc.i, i
    connect legacy, proc.result

    inst firstOuter of Outer
    inst secondOuter of Outer
    propassign firstOuter.impl, choice(Impl, Fast)
    propassign secondOuter.impl, choice(Impl, Default)
    connect first, firstOuter.out
    connect second, secondOuter.out

; The parameter choice is unaffected by the selection: one shared `Outer`/`Leaf`
; wrapper with a parameter and a generate case, and distinct parameter actuals.
; SELECT-LABEL: module Leaf
; SELECT: #(parameter [1:0] impl)
; SELECT: case (impl)
; SELECT: FastImpl selected_case_Fast (
; SELECT: DefaultImpl selected_default (
; SELECT-LABEL: module Outer
; SELECT: #(parameter [1:0] impl)
; SELECT-LABEL: module Top
; The global option is resolved to its selected target.
; SELECT-NOT: `ifdef
; SELECT: FPGATarget proc (
; SELECT-NOT: DefaultTarget proc
; SELECT: .impl(1)
; SELECT: .impl(0)

; DEFAULT-LABEL: module Leaf
; DEFAULT: #(parameter [1:0] impl)
; DEFAULT: case (impl)
; DEFAULT: FastImpl selected_case_Fast (
; DEFAULT: DefaultImpl selected_default (
; DEFAULT-LABEL: module Top
; Without the command-line selection the option is still a macro.
; DEFAULT: `ifdef targets$Platform$FPGA
; DEFAULT: FPGATarget proc_FPGA (
; DEFAULT: .impl(1)
; DEFAULT: .impl(0)
