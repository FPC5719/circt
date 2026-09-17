# Phase 6: Frontend, API, and End-to-End Validation

## Goal

Make the feature usable by FIRRTL producers and validate the original hierarchy-sharing use case through firtool.

## Frontend and API work

- Add construction APIs for choice domains, choice constants, parameter ports, forwarding, and `ParamInstChoice`.
- Update FIRRTL text parser/emitter and feature-version handling.
- Update MLIR C API/Python bindings if the affected FIRRTL types and operations are exposed there.
- Document the source-level syntax and the restriction that choices are elaboration-only.
- Decide whether Chisel/PyCDE integration emits this representation directly or uses an intermediate annotation first.

## End-to-end fixture

Build a complete hierarchy:

```text
Top
|- Outer_1 -> Inner_1
`- Outer_2 -> Inner_2
```

The source should contain one `Outer` definition and two instances with different choice actuals. Add a second fixture with at least two forwarding wrappers between `Top` and the selected `Inner`.

## Required output checks

- Exactly one emitted `Outer` module definition.
- Exactly one emitted `Inner_1` and `Inner_2` definition.
- `Top` passes distinct parameter values to its two `Outer` instances.
- `Outer` forwards the parameter to its child selection.
- No choice property appears in the emitted hardware port list.
- The selected implementation is elaboration-time `generate.case`, not a runtime mux.
- Verilog compiles with a supported simulator/synthesis frontend.

## Test matrix

Add tests at each boundary:

1. FIRRTL parser/printer round trip.
2. `circt-opt` verifier and materialization.
3. FIRRTL-to-HW IR checks.
4. HW-to-SV IR checks.
5. `firtool --ir-fir`, `--ir-hw`, `--ir-sv`, and Verilog output checks.
6. External Verilog compilation and, where practical, a small simulation proving `Inner_1` and `Inner_2` behavior differs per `Top` instance.
7. Negative tests for invalid values, missing assignments, mismatched ports, and runtime selectors.

## Performance and stability checks

- Compare compile time and IR size against the duplicated-module baseline.
- Confirm that hierarchy depth does not multiply wrapper module count.
- Test deterministic output names across repeated runs.
- Test both optimization enabled and `--disable-optimization` configurations.
- Test normal designs containing ordinary FIRRTL properties/classes to ensure no regression.

Recommended commands after a configured build:

```sh
ninja -C build check-circt
ninja -C build bin/circt-opt bin/firtool
```

The feature is ready for review only when the end-to-end fixture, negative diagnostics, ordinary-property regressions, and generated-Verilog compilation all pass.

## Status

### Construction APIs

Public builders are available for every producer-facing construct:

- `ChoiceDomainOp` builds a domain together with its cases from
  `(name, encoding)` pairs, and exposes `getEncodingType()`,
  `lookupCase()`, and `getCaseValue()` for parameter-port construction and
  encoding lookups.
- `ChoiceConstantOp` builds a constant from a `ChoiceCaseOp` and infers the
  result type, and exposes `getChoiceCase()`.
- `ParamInstanceChoiceOp` gained the same builder shapes as
  `InstanceChoiceOp`: a symbolic selector plus default module and
  `ChoiceCaseOp`/module pairs, the same with a materialized selector
  parameter, and a port-based builder for transforms.

Parameter ports are ordinary module ports of `!firrtl.choice<@Domain>` type and
forwarding is an ordinary `firrtl.propassign`; both already had public builders,
which are exercised by the new tests.  The FIRRTL text parser and the
materialization pass were migrated to the new builders so that they are
covered by the existing end-to-end tests.  `ChoiceOpsTest` unit tests build a
domain, a constant, a forwarded parameter, and a parameterized instance choice
and verify the resulting circuit.

### C API and Python bindings

The FIRRTL C API now exposes the choice type for non-MLIR producers:
`firrtlTypeIsAChoice`, `firrtlTypeGetChoice`, and `firrtlTypeGetChoiceDomain`,
covered by `test/CAPI/firrtl.c`.  The CIRCT Python bindings do not expose
FIRRTL operations or types at all, so there is no Python surface to update.

### Frontend and documentation

The FIRRTL parser and emitter already handled choice domains, choice
parameters, choice expressions, forwarding, and `paraminstchoice`; they are
gated behind `missingSpecFIRVersion` (7.0.0) and reject older declared
versions.  Negative text tests were added for out-of-range encodings, duplicate
encodings, duplicate alternatives, and undefined candidate modules.

`docs/Dialects/FIRRTL/ChoiceParameters.md` documents the source syntax, the
elaboration-only restriction, the generated `generate.case`, and the producer
APIs.  Chisel and PyCDE emit this representation directly through the FIRRTL
text form or the FIRRTL construction API; no intermediate annotation is
introduced.

### End-to-end fixtures

- `test/firtool/paraminstchoice-hierarchy.fir` builds the original
  `Top -> Outer -> Inner_1/Inner_2` use case with one `Outer` definition and
  two instances that pass different choice actuals.  It checks exactly one
  emitted `Outer`, `Inner_1`, and `Inner_2`, distinct parameter actuals,
  parameter forwarding, the absence of choice properties in the hardware ports,
  `generate.case` instead of a runtime mux, `--disable-opt`, and deterministic
  output across repeated runs.
- `test/firtool/paraminstchoice-forwarding.fir` forwards the choice through two
  wrapper modules and checks that neither wrapper is duplicated and that both
  forward the parameter to their child.

Both fixtures were compiled with Verilator 5.048 and simulated with a small
testbench; `Top` selects `Inner_1` for the first and `Inner_2` for the second
instance (`first=1 second=2`), proving behavior differs per instance of the
shared module.

### Performance and stability

Against the duplicated-module baseline (`utils/bench-choice-params.sh`) with 256
instances, three choice cases, and two wrapper levels:

| Design | Modules | `generate` blocks | Verilog bytes | HW IR bytes | Compile time |
| --- | --- | --- | --- | --- | --- |
| Choice parameters | 7 | 1 | 37108 | 31322 | 181 ms |
| Duplicated modules | 13 | 0 | 32642 | 28395 | 172 ms |

The wrapper module count is constant in the number of instances and equal to
the hierarchy depth, while the duplicated baseline needs one wrapper chain per
case.  Compile time is within a few percent and the emitted Verilog is slightly
larger only because of the shared `generate.case`.

### Validation

Run on the current revision:

| Command | Result |
| --- | --- |
| `ninja -C build check-circt` | 1580 passed, 0 failed (6 expectedly failed, 62 unsupported) |
| `CIRCTFIRRTLTests` | 26 passed, including the three new `ChoiceOpsTest` cases |
| `build/bin/circt-capi-firrtl-test` | passed |
| `verilator --lint-only` and simulation for both fixtures | passed; `first=1 second=2` |

The unit test target is not part of `check-circt` in this configuration
(`LLVM_BUILD_TESTS=OFF`), so it is built and run explicitly with
`ninja -C build CIRCTFIRRTLTests`.

### Remaining

- The Verilog compilation check is currently a documented manual step
  (`verilator --lint-only` plus a simulation testbench).  Making it an
  automated lit test needs a `verilator` feature in `test/lit.cfg.py`.
- Chisel/PyCDE emission is producer-side work outside CIRCT; the decision is
  recorded above.
