# Elaboration-Time Choice Parameters

Choice parameters select the structure of a module *per instance* at
elaboration time.  They share one module definition between instances that
instantiate different child implementations, instead of duplicating the module
once per implementation:

```text
Top
|- Outer<impl = Inner1> -> Inner_1
`- Outer<impl = Inner2> -> Inner_2
```

This document describes the FIRRTL source syntax and the restrictions that
apply to it.  The compiled representation is described in the
[parameterization plan](../../FIRRTLParameterization/README.md).

[TOC]

## Source syntax

The syntax is gated behind the unreleased FIRRTL 7.0.0 feature version.  A
`.fir` file must declare `FIRRTL version 7.0.0` (or later) to use any of the
constructs below; older declared versions are rejected with a diagnostic.

### Choice domains

A choice domain declares a circuit-scoped set of named cases.  Every case has
an explicit, unique unsigned encoding that must fit in the domain width:

```firrtl
circuit Top:
  choice_domain Impl width 2:
    choice_case Inner1 = 0
    choice_case Inner2 = 1
```

A domain name is unique within the circuit, case names are unique within the
domain, and the width must be between 1 and 64.

### Choice parameters

A choice parameter is an input port whose type names a domain:

```firrtl
  module Outer:
    input impl: Choice of Impl
    output value: UInt<8>
```

Choice parameters are elaboration-only: they may be forwarded with
`propassign` and used as selectors, but they are never values that hardware
operations can consume.  Only input ports may have a choice type; output
choice ports, choice values in `connect`, arithmetic, muxes, memories, and
aggregates are all rejected.

### Literal choices and forwarding

`choice(Domain, Case)` produces a literal choice value, and `propassign`
forwards choice values between a module parameter and instance parameters:

```firrtl
  public module Top:
    inst firstOuter of Outer
    inst secondOuter of Outer
    propassign firstOuter.impl, choice(Impl, Inner1)
    propassign secondOuter.impl, choice(Impl, Inner2)
```

### Parameterized instance choices

`paraminstchoice` selects the child module that an instance elaborates to.  The
module after `of` is the default; each `Case => Module` line maps a case of the
selector's domain to an alternative:

```firrtl
  module Outer:
    input impl: Choice of Impl
    output value: UInt<8>
    paraminstchoice selected impl of Inner_1:
      Inner2 => Inner_2
    connect value, selected.value
```

The selector must be a choice value, and all candidate modules must have
identical port names, directions, types, and layer requirements.  The
candidates must be internal modules or external modules; `intmodule`, class,
and intrinsic targets, probe ports, inner symbols, annotations, and unsupported
path-sensitive constructs are rejected in the current version.  A literal
selector is folded to a plain `firrtl.instance` during canonicalization.

## Elaboration-only restriction

Choice parameters do not exist in hardware.  `firtool` materializes every
choice parameter into an HW module parameter before the design is lowered, and
the parameterized instance choice becomes an SV `generate.case` with one case
per alternative plus a default case:

```systemverilog
module Outer
  #(parameter [0:0] impl) (
  output [7:0] value
);
  generate
  begin: selected
    case (impl)
      1: begin: case_Inner2
        Inner_2 selected_case_Inner2 (.value (value));
      end
      default: begin: default_0
        Inner_1 selected_default (.value (value));
      end
    endcase
  end
  endgenerate
endmodule
```

Consequently:

- no choice property or parameter port appears in the emitted hardware port
  list;
- the selection is resolved at elaboration time by `generate.case`, never by
  a runtime multiplexer;
- one module definition is emitted per module *definition* in the source, no
  matter how many instances pass different choice actuals;
- the inliner forwards a choice parameter into an inline parent by substituting
  the choice input port with the value driving it, a choice constant or a
  containing-module parameter, so no property wire is needed; a port driven any
  other way is retained with a targeted diagnostic;
- passes that cannot preserve an unresolved choice, such as
  `firrtl-lower-classes` and `firrtl-extract-instances`, emit a targeted
  diagnostic instead of silently dropping or mistranslating the parameter.

## Producer APIs

Producers can construct the IR through the regular MLIR builders.  The
FIRRTL dialect provides dedicated builders for choice domains, choice
constants, and parameterized instance choices:

```c++
auto domain = ChoiceDomainOp::create(builder, loc, "Impl", 2,
                                     ArrayRef<std::pair<StringRef, uint64_t>>{
                                         {"Inner1", 0}, {"Inner2", 1}});
auto constant = ChoiceConstantOp::create(builder, loc, domain.lookupCase("Inner2"));
auto choice = ParamInstanceChoiceOp::create(builder, loc, selector, inner1,
                                            {{domain.lookupCase("Inner2"), inner2}},
                                            "selected");
```

`ChoiceDomainOp::getEncodingType()` returns the integer type that the
materialized parameter uses, and `ChoiceDomainOp::getCaseValue()` looks up an
encoding by case name.  The FIRRTL C API exposes the choice type to
non-MLIR producers via `firrtlTypeGetChoice`, `firrtlTypeIsAChoice`, and
`firrtlTypeGetChoiceDomain`.  The CIRCT Python bindings do not expose FIRRTL
operations or types, so no Python API is added.

Chisel and PyCDE emit the FIRRTL text form or build the IR through the FIRRTL
API, matching how other FIRRTL constructs are produced; no intermediate
annotation is required.
