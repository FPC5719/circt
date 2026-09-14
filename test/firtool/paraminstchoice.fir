; RUN: firtool %s --format=fir --ir-fir | FileCheck %s --check-prefix=FIR
; RUN: firtool %s --format=fir --ir-hw | FileCheck %s --check-prefix=HW
; RUN: firtool %s --format=fir --ir-sv | FileCheck %s --check-prefix=SVIR
; RUN: firtool %s --format=fir --verilog | FileCheck %s --check-prefix=SV

; Exercise the complete FIRRTL parser, choice-parameter materialization,
; FIRRTL-to-HW lowering, and HW-to-SV lowering path.  `Top` passes separate
; literal choice values to two instances of the same forwarding wrapper.

FIRRTL version 7.0.0
circuit Top:
  choice_domain Impl width 2:
    choice_case Default = 0
    choice_case Fast = 1
    choice_case Small = 2

  module DefaultImpl:
    output out: UInt<8>
    connect out, UInt<8>(0)

  module FastImpl:
    output out: UInt<8>
    connect out, UInt<8>(1)

  module SmallImpl:
    output out: UInt<8>
    connect out, UInt<8>(2)

  module Leaf:
    input impl: Choice of Impl
    output out: UInt<8>
    paraminstchoice selected impl of DefaultImpl:
      Fast => FastImpl
      Small => SmallImpl
    connect out, selected.out

  module Outer:
    input impl: Choice of Impl
    output out: UInt<8>
    inst leaf of Leaf
    propassign leaf.impl, impl
    connect out, leaf.out

  public module Top:
    output first: UInt<8>
    output second: UInt<8>
    inst firstOuter of Outer
    inst secondOuter of Outer
    propassign firstOuter.impl, choice(Impl, Fast)
    propassign secondOuter.impl, choice(Impl, Small)
    connect first, firstOuter.out
    connect second, secondOuter.out

; The frontend accepts and preserves the textual ParamInstChoice before the
; full lowering pipeline materializes choice properties.
; FIR: firrtl.choice_domain @Impl width 2
; FIR: "firrtl.param_instance_choice"(%impl)
; FIR: firrtl.propassign %firstOuter_impl
; FIR: firrtl.propassign %secondOuter_impl

; Materialization removes choice properties from hardware ports, turns them
; into HW parameters, and retains one shared `Outer` module.
; HW-LABEL: hw.module private @Leaf<impl: i2>
; HW: sv.generate.case #hw.param.decl.ref<"impl"> : i2
; HW-LABEL: hw.module private @Outer<impl: i2>
; HW-NOT: !firrtl.choice
; HW-LABEL: hw.module @Top
; HW: hw.instance "firstOuter" @Outer<impl: i2 = 1>()
; HW: hw.instance "secondOuter" @Outer<impl: i2 = -2>()

; SVIR-LABEL: hw.module private @Leaf<impl: i2>
; SVIR: sv.generate.case #hw.param.decl.ref<"impl"> : i2
; SVIR-LABEL: hw.module @Top
; SVIR-NOT: !firrtl.choice

; SV-LABEL: module Leaf
; SV: #(parameter [1:0] impl)
; SV: generate
; SV: case (impl)
; SV: FastImpl selected_case_Fast
; SV: SmallImpl selected_case_Small
; SV: DefaultImpl selected_default
; SV: endcase
; SV: endgenerate
; SV-LABEL: module Outer
; SV: #(parameter [1:0] impl)
; SV-LABEL: module Top
; SV: Outer #(
; SV: .impl(1)
; SV: ) firstOuter
; SV: Outer #(
; SV: .impl(2)
; SV: ) secondOuter
