; RUN: circt-translate -import-firrtl -verify-diagnostics -split-input-file %s | circt-opt | FileCheck %s

FIRRTL version 7.0.0
circuit ParamInstChoiceText :
  choice_domain Impl width 2 :
    choice_case Default = 0
    choice_case Fast = 1
    choice_case Small = 2

  module DefaultImpl :
    input in : UInt<8>
    output out : UInt<8>

  module FastImpl :
    input in : UInt<8>
    output out : UInt<8>

  module SmallImpl :
    input in : UInt<8>
    output out : UInt<8>

  ; A literal choice is accepted directly as the selector as well.
  ; CHECK-LABEL: firrtl.module private @LiteralChoice
  ; CHECK: firrtl.choice.constant @Impl::@Fast : !firrtl.choice<@Impl>
  ; CHECK: "firrtl.param_instance_choice"(%{{.+}})
  module LiteralChoice :
    paraminstchoice selected choice(Impl, Fast) of DefaultImpl :
      Fast => FastImpl
      Small => SmallImpl

  ; CHECK-LABEL: firrtl.module @ParamInstChoiceText
  ; CHECK: "firrtl.param_instance_choice"(%impl)
  ; CHECK-SAME: caseNames = [@Impl::@Fast, @Impl::@Small]
  ; CHECK-SAME: moduleNames = [@DefaultImpl, @FastImpl, @SmallImpl]
  public module ParamInstChoiceText :
    input impl : Choice of Impl
    input in : UInt<8>
    output out : UInt<8>
    paraminstchoice selected impl of DefaultImpl :
      Fast => FastImpl
      Small => SmallImpl
    connect out, selected.out

;// -----

FIRRTL version 6.0.0
circuit ParamInstChoiceTooOld :
  public module ParamInstChoiceTooOld :
    input impl : UInt<1>
    ; expected-error @below {{parameterized instance choices are a FIRRTL 7.0.0+ feature}}
    paraminstchoice selected impl of ParamInstChoiceTooOld :
      A => ParamInstChoiceTooOld

;// -----

FIRRTL version 7.0.0
circuit ParamInstChoiceBadCase :
  choice_domain Impl width 1 :
    choice_case A = 0
  module DefaultImpl :
  public module ParamInstChoiceBadCase :
    input impl : Choice of Impl
    ; expected-error @below {{use of undefined choice case 'Missing' in domain 'Impl'}}
    paraminstchoice selected impl of DefaultImpl :
      Missing => DefaultImpl

;// -----

FIRRTL version 7.0.0
circuit ParamInstChoiceBadSelector :
  public module ParamInstChoiceBadSelector :
    input selector : UInt<1>
    ; expected-error @below {{parameterized instance selector must have choice type}}
    paraminstchoice selected selector of ParamInstChoiceBadSelector :
      A => ParamInstChoiceBadSelector
