; RUN: firtool %s --format=fir --ir-fir | FileCheck %s --check-prefix=FIR
; RUN: firtool %s --format=fir --ir-hw | FileCheck %s --check-prefix=HW
; RUN: firtool %s --format=fir --ir-sv | FileCheck %s --check-prefix=SVIR
; RUN: firtool %s --format=fir --verilog | FileCheck %s --check-prefix=SV
; RUN: firtool %s --format=fir --verilog --disable-opt | FileCheck %s --check-prefix=SV
; RUN: firtool %s --format=fir --verilog > %t.1.v
; RUN: firtool %s --format=fir --verilog > %t.2.v
; RUN: diff %t.1.v %t.2.v

; The original hierarchy-sharing use case: one `Outer` module definition
; contains the parameterized instance choice and is instantiated twice by
; `Top` with different choice actuals.  The selection is resolved at
; elaboration time and must not duplicate `Outer` or leak the choice into the
; hardware port list.
;
;   Top
;   |- Outer_1 -> Inner_1
;   `- Outer_2 -> Inner_2

FIRRTL version 7.0.0
circuit Top:
  choice_domain Impl width 1:
    choice_case Inner1 = 0
    choice_case Inner2 = 1

  module Inner_1:
    output value: UInt<8>
    connect value, UInt<8>(1)

  module Inner_2:
    output value: UInt<8>
    connect value, UInt<8>(2)

  module Outer:
    input impl: Choice of Impl
    output value: UInt<8>
    paraminstchoice inner impl of Inner_1:
      Inner2 => Inner_2
    connect value, inner.value

  public module Top:
    output first: UInt<8>
    output second: UInt<8>
    inst Outer_1 of Outer
    inst Outer_2 of Outer
    propassign Outer_1.impl, choice(Impl, Inner1)
    propassign Outer_2.impl, choice(Impl, Inner2)
    connect first, Outer_1.value
    connect second, Outer_2.value

; The frontend keeps the parameterized choice and the choice parameters.
; FIR: firrtl.choice_domain @Impl width 1
; FIR: "firrtl.param_instance_choice"(%impl)
; FIR: firrtl.choice.constant @Impl::@Inner1
; FIR: firrtl.propassign %Outer_1_impl
; FIR: firrtl.choice.constant @Impl::@Inner2
; FIR: firrtl.propassign %Outer_2_impl

; Materialization turns the choice property into an integer parameter.  Exactly
; one `Outer` module survives and carries the forwarding `generate.case`.
; HW-COUNT-1: hw.module private @Inner_1(
; HW-COUNT-1: hw.module private @Inner_2(
; HW-COUNT-1: hw.module private @Outer<impl: i1>
; HW: sv.generate.case #hw.param.decl.ref<"impl"> : i1
; HW-LABEL: hw.module @Top
; HW: hw.instance "Outer_1" @Outer<impl: i1 = false>()
; HW: hw.instance "Outer_2" @Outer<impl: i1 = true>()
; HW-NOT: !firrtl.choice

; SVIR-COUNT-1: hw.module private @Outer<impl: i1>
; SVIR: sv.generate.case #hw.param.decl.ref<"impl"> : i1
; SVIR-NOT: !firrtl.choice

; The choice never becomes a hardware port, and the selection stays a
; `generate.case` instead of a runtime multiplexer.
; SV-COUNT-1: module Inner_1
; SV-COUNT-1: module Inner_2
; SV-COUNT-1: module Outer
; SV-NOT: input impl
; SV: #(parameter [0:0] impl)
; SV: generate
; SV: case (impl)
; SV: Inner_2 inner
; SV: default
; SV: Inner_1 inner
; SV: endcase
; SV-NOT: mux
; SV-LABEL: module Top
; SV: Outer #(
; SV: .impl(0)
; SV: ) Outer_1
; SV: Outer #(
; SV: .impl(1)
; SV: ) Outer_2
