# Phase 5: Pipeline and Pass Compatibility

## Goal

Ensure parameter properties and parameter choices do not break existing FIRRTL analyses, hierarchy transforms, or metadata handling.

## Required audit

Audit every pass that recognizes `PropertyType`, `InstanceOp`, or `InstanceChoiceOp`, including:

- `LowerClasses`;
- `InstanceInfo`;
- `LowerSignatures` and `LowerTypes`;
- constant propagation and dead-code elimination;
- inlining and wire elimination;
- layer sink/lowering;
- XMR and path resolution;
- instance extraction;
- deduplication;
- FIRRTL visitors, reductions, parser, emitter, C API, and Python bindings.

## Policy

- Choice properties are consumed before `LowerClasses` and must not become OM metadata.
- Existing global option choices retain their current macro/specialization semantics.
- Parameter choices are either materialized early or explicitly supported; they must never be silently treated as global options.
- Passes that cannot preserve unresolved choices must emit a targeted diagnostic or require the materialization pass first.
- Deduplication must compare formal parameter declarations and selector mappings deterministically.
- Inlining/extraction must either forward parameter assignments correctly or reject the operation with a documented diagnostic.

## Analysis concerns

The current constant-propagation implementation treats unresolved instance choices as overdefined. That is acceptable for V1 if parameter choices are not expected to participate in FIRRTL hardware constant propagation, but the behavior must be documented and tested.

Hierarchy paths and inner symbols are especially sensitive because a generated case introduces branch scopes. Start by rejecting unsupported path-sensitive constructs and add support incrementally.

## Tests and verification

Run the full FIRRTL pass suite with parameterized fixtures. Add regression tests for:

- CSE/canonicalization around `propassign`;
- deduplication of identical parameterized modules;
- no accidental deduplication when formal parameters or selector mappings differ;
- inlining and extraction diagnostics;
- layer/XMR diagnostics;
- ordinary property metadata still lowering to OM correctly;
- `--select-instance-choice` not affecting parameter choices.

Use `ninja -C build check-circt` before declaring this phase complete. Any pass that cannot support unresolved choices must be listed in the diagnostics and compatibility documentation.

## Audit results

`firrtl.param_instance_choice` implements `FInstanceLike` and
`InstanceGraphInstanceOpInterface`, so the instance graph and every analysis
built on it (instance info, NLA tables, FIRRTL reductions, field sources)
already treat it as an instance-like operation which references all of its
candidate modules.  The remaining work is per-pass handling, summarized below.
Only `firrtl-lower-classes`, `firrtl-inliner`, and
`firrtl-extract-instances` cannot preserve an unresolved choice and diagnose
instead.

| Area | Passes | V1 behavior | Regression test |
| --- | --- | --- | --- |
| Elaboration-only consumption | `firrtl-materialize-choice-parameters` | Turns choice ports into module parameters, records instance actuals, resolves the selector, and removes the choice property values and ports before `firrtl-lower-classes`. | `materialize-choice-parameters*.mlir` |
| OM metadata | `firrtl-lower-classes` | Diagnoses a remaining choice port instead of lowering it as OM metadata; ordinary properties (classes, strings, integers) still lower to `om.*`. | `choice-types-lowering-errors.mlir`, `choice-parameters-to-om.mlir` |
| Deduplication | `firrtl-dedup` | Compares formal parameter declarations, selector mappings and candidate module lists structurally, and rewrites `moduleNames`/`portNames` when a candidate module is deduplicated away. | `dedup-choice-parameters.mlir` |
| Type lowering | `firrtl-lower-types` | Flattens aggregate ports of a parameterized choice like any other instance and preserves the selector or materialized selector parameter. | `lower-types-param-instance-choice.mlir` |
| Inlining | `firrtl-inliner` | A module with choice parameters is retained: forwarding a choice into the parent would need a property wire. Inline annotations produce a warning, flattening such a module is an error. | `inliner-choice-parameters.mlir`, `inliner-choice-parameters-errors.mlir` |
| Extraction | `firrtl-extract-instances` | Only plain instances are extracted, and the op rejects annotations. An extraction annotation on a candidate module of a parameterized choice is diagnosed rather than silently dropped. | `extract-instances-choice-parameters-errors.mlir` |
| Layers | `firrtl-layer-sink`, `firrtl-lower-layers`, `firrtl-check-layers` | Layer requirements are cleared on all instance-like operations, and the verifier rejects layer requirements on a parameterized choice that is instantiated directly in a layer. | `lower-layers-choice-parameters.mlir` |
| XMR and paths | `firrtl-lower-xmr`, `firrtl-resolve-paths`, `firrtl-resolve-traces`, `firrtl-probes-to-signals`, `firrtl-inner-symbol-dce` | A choice is a property value, and the op rejects probe ports, inner symbols and annotations, so no XMR, path or inner reference can target or traverse it. | `param-instance-choice-errors.mlir`, `choice-types-hardware-errors.mlir` |
| Constant propagation and DCE | `firrtl-imconstprop`, `firrtl-imdeadcodeelim` | An unresolved choice is overdefined: no candidate constant is propagated and neither the op nor its candidates are considered dead. | `choice-parameters-imconstprop.mlir` |
| Canonicalization and CSE | `canonicalize`, `cse` | A literal selector folds to a plain instance; symbolic forwarding (`firrtl.propassign`) and choice constants are preserved for materialization. | `choice-parameters-canonicalize.mlir`, `param-instance-choice.mlir` |
| Option specialization | `firrtl-specialize-option`, `firtool --select-instance-choice` | Only option-based `firrtl.instance_choice` operations are specialized; parameter choices keep their parameter and `generate case`. | `paraminstchoice-select-instance-choice.fir` |
| Parser and emitter | FIRRTL text parser/emitter | `paraminstchoice` and `choice_domain` are gated behind the unreleased 7.0.0 feature version. Public construction APIs, the C API and Python bindings remain Phase 6 work. | `parse-paraminstchoice.fir`, `emit-paraminstchoice.mlir` |

### Diagnostics for unsupported constructs

- `firrtl-lower-classes`: `cannot lower choice port '<port>' as OM metadata; run choice-parameter materialization first`.
- `firrtl-inliner`: `module marked inline has elaboration-time choice parameters and is retained until they are materialized`, and `cannot flatten instance` when a flatten annotation requires splicing such a module into its parent.
- `firrtl-extract-instances`: `cannot extract a parameterized instance choice of module '<module>'`.
- `firrtl-materialize-choice-parameters`: missing or duplicate `firrtl.propassign` for a choice parameter, and a selector that is neither a choice constant nor a containing-module parameter.
- `firrtl.param_instance_choice` verification: unknown choice domain or case, duplicate case, candidate modules that are not internal modules or external modules (including `firrtl.intmodule`), probe ports, inner symbols, annotations, and a selector produced by a hardware operation.

### Deferred

- Inlining does not yet forward choice parameters into the parent; inline-marked
  modules are retained (with a warning) until the choice parameters are
  materialized.
- `firrtl-lower-signatures` is not scheduled by `firtool` and has no
  choice-specific handling.  It is left unsupported in V1.
