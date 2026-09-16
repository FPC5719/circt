# Phase 0: Semantics and IR Contract

**Status:** proposed V1 contract.  Once accepted in review, this document is
the contract for the remaining phases; changes then require revisiting the
later-phase designs and tests.

## Goal

Freeze the meaning and scope of the feature before changing ODS or lowering code.

The parameter is an elaboration-time value. It is not a runtime hardware signal and must not affect normal FIRRTL dataflow, widths, aggregate shapes, memories, or port types.

## Required semantics

- A module may declare one or more elaboration-only choice inputs.
- A module instance may receive a literal choice or forward a choice from its containing module.
- A choice may select among internal or external FIRRTL modules with
  identical hardware interfaces.
- A default target is required, or the verifier must require exhaustive cases.
- Different instances of the same module may use different choice values.
- Forwarding through arbitrary hierarchy depth must preserve one definition of each wrapper module.
- A known literal selector should be canonicalizable to an ordinary FIRRTL instance.
- An unresolved selector must survive to HW/SV and become a Verilog parameter/generate construct.

## Explicit non-goals for V1

- Runtime signal-controlled module selection.
- Parameter-dependent FIRRTL widths or aggregate types.
- General FIRRTL parameter arithmetic.
- Automatic factoring of already-duplicated `Outer_1`/`Outer_2` modules.
- Parameters on FIRRTL classes, memories, or arbitrary external metadata properties.
- New semantics for existing global `firrtl.option`/`firrtl.instance_choice`.

## Accepted decisions

1. A choice domain is a circuit-scoped symbol table with named case symbols.
   It is a new declaration family; it does **not** reuse `firrtl.option` or
   `firrtl.option_case`.  The latter already represent global,
   macro/specialization-controlled options, while a choice domain describes a
   per-instance elaboration parameter.  A `!firrtl.choice<@Domain>` therefore
   has nominal, not merely structural, type identity.

2. A choice value is an enumeration, represented for lowering by an explicitly
   sized unsigned integer encoding owned by its domain.  Each named case has a
   unique explicit encoding that fits the domain width.  V1 accepts named case
   constants only: it does not provide a general integer-to-choice cast or
   choice arithmetic.  This gives generated Verilog a stable fixed-width
   parameter representation without making ordinary FIRRTL integers into
   parameters.

3. `firrtl.param_instance_choice` has a separate, mandatory default target.
   The default is not a domain case and is selected for every encoding that has
   no listed alternative, including unused encodings.  V1 does not support an
   exhaustive-without-default form.  This makes selection total even if a
   parameter is supplied by an external Verilog instantiation.

4. V1 forwarding is direct only.  A choice parameter may be sourced by a
   `firrtl.choice.constant` or by the corresponding input property of the
   containing module.  It may be transferred only with a direct
   `firrtl.propassign` to a child parameter input, or consumed directly as the
   selector of a `firrtl.param_instance_choice`.  Transparent property wires,
   aliases, casts, computations, and fan-in/fan-out forwarding are outside the
   contract.  Each parameter-port sink has exactly one assignment.

5. MLIR assembly may expose the new operations as soon as their dialect
   implementation lands.  Textual `.fir` syntax is gated by
   `missingSpecFIRVersion` (currently the unreleased 7.0.0 gate) until an
   upstream FIRRTL specification version defines it.  It must not be silently
   accepted for an older declared FIRRTL version.

## Representative examples

The following is schematic MLIR, using the names intended for later phases;
the exact assembly is deliberately not fixed by Phase 0.

```mlir
firrtl.circuit @C {
  firrtl.choice_domain @ImplKind width 2 {
    firrtl.choice_case @ID1 = 1
    firrtl.choice_case @ID2 = 2
  }

  firrtl.module @Outer(in %impl: !firrtl.choice<@ImplKind>,
                       in %in: !firrtl.uint<8>,
                       out out: !firrtl.uint<8>) {
    %inner_in, %inner_out = firrtl.param_instance_choice inner %impl
      @InnerDefault alternatives @ImplKind {
        @ID1 -> @Inner_1, @ID2 -> @Inner_2
      } (in: %in) -> (out: !firrtl.uint<8>)
    firrtl.connect %out, %inner_out : !firrtl.uint<8>
  }

  firrtl.module @Top(...) {
    %id1 = firrtl.choice.constant @ImplKind::@ID1
    %id2 = firrtl.choice.constant @ImplKind::@ID2
    // Each ordinary instance of the one @Outer definition receives a distinct
    // elaboration-time actual.  No @Outer_ID1/@Outer_ID2 modules are created.
    // The exact instance-property syntax is defined in Phase 2.
    // outer1.impl <- %id1; outer2.impl <- %id2
  }
}
```

After materialization and lowering, this must correspond structurally to one
shared `Outer` SystemVerilog module with an `impl` parameter, two `Top`
instances with different parameter actuals, and a `generate case (impl)` in
`Outer` that instantiates `InnerDefault`, `Inner_1`, or `Inner_2`.

The following is rejected because it makes the selector a runtime value rather
than an elaboration parameter:

```mlir
%impl = firrtl.bits %runtime_select : (!firrtl.uint<1>) -> !firrtl.uint<1>
firrtl.param_instance_choice inner %impl ...
```

Likewise rejected are `firrtl.connect` or `firrtl.mux` involving a choice,
using a choice in a width/type/memory expression, and forwarding through a
property wire.  These cases must diagnose rather than acquire hardware
semantics.

## Verification and exit criteria

- This document records the accepted semantics and rejected examples.
- The positive hierarchy and negative runtime-selection examples above are
  normative test seeds for Phases 1--6.
- Confirm that the design can be represented without changing ordinary FIRRTL connect semantics.
- Confirm that the generated Verilog is expected to contain one shared wrapper module and per-instance parameter actuals.

No implementation should begin until these decisions are stable.
