; RUN: firtool %s --format=fir --ir-fir | FileCheck %s --check-prefix=FIR
; RUN: firtool %s --format=fir --ir-hw | FileCheck %s --check-prefix=HW
; RUN: firtool %s --format=fir --verilog | FileCheck %s --check-prefix=SV

; A choice parameter is forwarded through two wrappers before it reaches the
; parameterized instance choice.  Marking both wrappers inline must forward the
; parameter into the parent by substituting the choice ports, not by
; materializing a property wire.  The wrappers disappear; the choice stays an
; elaboration-time generate case in the surviving module.
;
;   Top
;   |- outer1 (Outer, impl=Inner1)
;   `- outer2 (Outer, impl=Inner2)
;        Outer carries the parameterized instance choice directly.

FIRRTL version 7.0.0
circuit Top: %[[
  { "class": "firrtl.passes.InlineAnnotation", "target": "~Top|Mid" },
  { "class": "firrtl.passes.InlineAnnotation", "target": "~Top|Leaf" }
]]
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

; The wrappers are inlined away and the selector is forwarded as the surviving
; module's choice input port.
; FIR-NOT: firrtl.module private @Leaf
; FIR-NOT: firrtl.module private @Mid
; FIR: firrtl.module private @Outer(in %impl: !firrtl.choice<@Impl>
; FIR-NOT: firrtl.wire : !firrtl.choice
; FIR: "firrtl.param_instance_choice"(%impl)

; One Outer survives and the selection is a generate case over its parameter.
; HW-NOT: hw.module private @Leaf
; HW-NOT: hw.module private @Mid
; HW-COUNT-1: hw.module private @Outer<impl: i1>
; HW: sv.generate.case #hw.param.decl.ref<"impl"> : i1
; HW: hw.instance "mid_leaf_selected_case_Inner2" @Inner_2()
; HW: hw.instance "mid_leaf_selected_default" @Inner_1()
; HW-LABEL: hw.module @Top
; HW: hw.instance "outer1" @Outer<impl: i1 = false>()
; HW: hw.instance "outer2" @Outer<impl: i1 = true>()
; HW-NOT: !firrtl.choice

; The choice never becomes a hardware port, and selection stays a generate case.
; SV-NOT: module Leaf
; SV-NOT: module Mid
; SV-COUNT-1: module Outer
; SV: #(parameter [0:0] impl)
; SV: case (impl)
; SV: Inner_2
; SV: default
; SV: Inner_1
; SV: endcase
; SV-LABEL: module Top
; SV: .impl(0)
; SV: .impl(1)
