; RUN: firtool %s --format=fir --ir-fir | FileCheck %s --check-prefix=FIR
; RUN: firtool %s --format=fir --ir-hw | FileCheck %s --check-prefix=HW
; RUN: firtool %s --format=fir --verilog | FileCheck %s --check-prefix=SV
; RUN: firtool %s --format=fir --verilog --disable-opt | FileCheck %s --check-prefix=SV

; A choice parameter is forwarded through two wrapper modules before it
; reaches the parameterized instance choice.  Neither wrapper may be
; duplicated per choice, and each must forward the parameter to its child.
;
;   Top
;   |- outer1 (Outer, impl=Inner1)
;   |    `- mid (Mid) -> leaf (Leaf) -> Inner_1
;   `- outer2 (Outer, impl=Inner2)
;        `- mid (Mid) -> leaf (Leaf) -> Inner_2

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

  module Leaf:
    input impl: Choice of Impl
    output value: UInt<8>
    paraminstchoice selected impl of Inner_1:
      Inner2 => Inner_2
    connect value, selected.value

  module Mid:
    input impl: Choice of Impl
    output value: UInt<8>
    inst leaf of Leaf
    propassign leaf.impl, impl
    connect value, leaf.value

  module Outer:
    input impl: Choice of Impl
    output value: UInt<8>
    inst mid of Mid
    propassign mid.impl, impl
    connect value, mid.value

  public module Top:
    output first: UInt<8>
    output second: UInt<8>
    inst outer1 of Outer
    inst outer2 of Outer
    propassign outer1.impl, choice(Impl, Inner1)
    propassign outer2.impl, choice(Impl, Inner2)
    connect first, outer1.value
    connect second, outer2.value

; Both wrappers forward the choice parameter and keep the unresolved selector.
; FIR: "firrtl.param_instance_choice"(%impl)
; FIR: firrtl.module private @Mid(in %impl: !firrtl.choice<@Impl>
; FIR: firrtl.propassign %leaf_impl, %impl
; FIR: firrtl.module private @Outer(in %impl: !firrtl.choice<@Impl>
; FIR: firrtl.propassign %mid_impl, %impl
; FIR: firrtl.choice.constant @Impl::@Inner1
; FIR: firrtl.propassign %outer1_impl
; FIR: firrtl.choice.constant @Impl::@Inner2
; FIR: firrtl.propassign %outer2_impl

; Every wrapper is emitted exactly once, is parameterized, and forwards the
; parameter to its child.
; HW-COUNT-1: hw.module private @Leaf<impl: i1>
; HW: sv.generate.case #hw.param.decl.ref<"impl"> : i1
; HW: hw.instance "selected_case_Inner2" @Inner_2()
; HW: hw.instance "selected_default" @Inner_1()
; HW-COUNT-1: hw.module private @Mid<impl: i1>
; HW: hw.instance "leaf" @Leaf<impl: i1 = #hw.param.decl.ref<"impl">>()
; HW-COUNT-1: hw.module private @Outer<impl: i1>
; HW: hw.instance "mid" @Mid<impl: i1 = #hw.param.decl.ref<"impl">>()
; HW-LABEL: hw.module @Top
; HW: hw.instance "outer1" @Outer<impl: i1 = false>()
; HW: hw.instance "outer2" @Outer<impl: i1 = true>()
; HW-NOT: !firrtl.choice

; The wrappers are not duplicated and the choice remains an elaboration-time
; generate case.
; SV-COUNT-1: module Leaf
; SV: generate
; SV: case (impl)
; SV: endcase
; SV: endgenerate
; SV-COUNT-1: module Mid
; SV: #(parameter [0:0] impl)
; SV: Leaf #(
; SV: .impl(impl)
; SV-COUNT-1: module Outer
; SV: #(parameter [0:0] impl)
; SV: Mid #(
; SV: .impl(impl)
; SV-LABEL: module Top
; SV: Outer #(
; SV: .impl(0)
; SV: ) outer1
; SV: Outer #(
; SV: .impl(1)
; SV: ) outer2
; SV-NOT: mux
