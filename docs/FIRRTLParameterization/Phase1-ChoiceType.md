# Phase 1: Choice Domain and Choice Type

## Goal

Add the FIRRTL-side type and constants used to carry an elaboration-only implementation choice through module ports and `propassign`.

## IR work

- Add a circuit-scoped choice-domain declaration, preferably reusing the symbol-table shape of `firrtl.option`/`firrtl.option_case`.
- Give every case an explicit, unique integer encoding.
- Add `!firrtl.choice<@Domain>` as a distinct property type.
- Add a `firrtl.choice.constant` operation that produces a value of the choice type.
- Make `ChoiceType` a `PropertyType` for `propassign`, but keep it distinguishable from metadata properties.
- Reject choice values in ordinary hardware operations.
- Reject choice aggregates, output properties, class ports, and unbounded/untyped values in V1.

Do not infer parameter semantics from existing `!firrtl.integer`. Existing property integers are unlimited-width metadata values and already support property arithmetic.

## Verifier requirements

- Domain references resolve to a choice-domain declaration.
- Case values fit the selected encoding type.
- Case values are unique.
- A choice constant references a case in the matching domain.
- `propassign` requires equal choice types, as it does for other properties.

## Parser, printer, and API

- MLIR assembly syntax is part of this phase.
- FIRRTL text (`.fir`) parser/emitter syntax is deliberately deferred.  When it
  is implemented, it must be gated by `missingSpecFIRVersion` until the
  external specification is agreed; older declared FIRRTL versions must reject
  the syntax.
- Public construction APIs beyond generated MLIR builders, visitors, C API,
  and Python bindings are deferred to Phase 6, when the producer-facing API
  surface is designed alongside the end-to-end frontend integration.

## Tests and verification

Add unit/lit tests for:

- parsing and printing a domain, case, type, and constant;
- unresolved domains and unknown cases;
- duplicate and out-of-range encodings;
- `propassign` between matching choice types;
- rejection by `connect`, arithmetic, mux, memory, and aggregate operations;
- MLIR round-tripping; `.fir` round-tripping is deferred with the textual
  frontend work above.

Run the relevant dialect tests (or the full CIRCT suite while the test target is being established):

```sh
ninja -C build check-circt -j 32
```

If a narrower target is available in the build, run the FIRRTL dialect parser/verifier lit tests directly. The phase is complete when the new type is fully verified but has no HW lowering yet; unsupported lowering should fail with a deliberate diagnostic rather than an unknown-type crash.
