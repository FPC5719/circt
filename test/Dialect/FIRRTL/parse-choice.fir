; RUN: circt-translate -import-firrtl -verify-diagnostics -split-input-file %s | circt-opt | FileCheck %s

FIRRTL version 7.0.0
circuit ChoiceText :
  choice_domain Impl width 2 :
    choice_case Default = 0
    choice_case Fast = 1
    choice_case Small = 2

  ; CHECK-LABEL: firrtl.module @ChoiceText(in %impl: !firrtl.choice<@Impl>)
  public module ChoiceText :
    input impl : Choice of Impl

;// -----

FIRRTL version 6.0.0
circuit TooOld :
  ; expected-error @below {{choice domains are a FIRRTL 7.0.0+ feature}}
  choice_domain Impl width 1 :
    choice_case A = 0

;// -----

FIRRTL version 7.0.0
circuit UnknownDomain :
  module UnknownDomain :
    ; expected-error @below {{unknown choice domain 'Missing'}}
    input impl : Choice of Missing

;// -----

FIRRTL version 7.0.0
circuit UnknownCase :
  choice_domain Impl width 1 :
    choice_case A = 0
  public module UnknownCase :
    ; expected-error @below {{unknown choice case 'Missing' in domain 'Impl'}}
    node bad = choice(Impl, Missing)

;// -----

FIRRTL version 7.0.0
circuit ChoiceExpression :
  choice_domain Impl width 1 :
    choice_case A = 0
  public module ChoiceExpression :
    ; expected-error @below {{Node cannot be analog and must be passive or passive under a flip '!firrtl.choice<@Impl>'}}
    node bad = choice(Impl, A)
