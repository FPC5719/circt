# Phase 3: Property-to-Parameter Materialization

## Goal

Convert choice properties and `propassign` dataflow into explicit formal/actual parameter metadata before generic property lowering erases property ports.

## Pass responsibilities

Add a pass tentatively named `firrtl-materialize-choice-parameters` that:

1. Finds input `ChoiceType` ports on FIRRTL modules.
2. Validates that they are formal elaboration parameters.
3. Finds each instance input result of `ChoiceType`.
4. Resolves its single `propassign` source to a choice constant or containing-module parameter reference.
5. Creates formal parameter declarations and instance actual descriptors.
6. Preserves symbolic forwarding, rather than prematurely requiring an integer literal.
7. Rewrites `ParamInstChoice` selectors to literal or symbolic parameter references.
8. Removes choice ports, instance choice-property results, and their `propassign` operations.
9. Leaves ordinary FIRRTL properties for `LowerClasses`.

The materialized representation uses FIRRTL-side `#firrtl.param.decl` and
`#firrtl.param.decl.ref` attributes until FIRRTL-to-HW converts them to
`hw::ParamDeclAttr` and `hw::ParamDeclRefAttr`.

## Current implementation

`firrtl-materialize-choice-parameters` is implemented and scheduled by
`firtool` immediately before `firrtl-lower-classes`.  It turns each input
choice port into a same-named integer module parameter, records each instance
actual in its `parameters` attribute, and removes the property port/result and
its `propassign`.  A choice constant becomes its explicit domain encoding;
forwarding from a containing module input becomes `#firrtl.param.decl.ref`.

The pass changes `firrtl.param_instance_choice` from an SSA choice selector to
a `selectorParameter` declaration.  That declaration contains either the
integer literal or symbolic parameter reference.  This leaves the
case-to-module mapping intact for Phase 4 while making its selector independent
of FIRRTL property ports.  The lowering bridge maps the materialized formal and
actual declarations to HW parameter declarations/references.  Choice domains
with no remaining parameterized choice are removed; domains still referenced by
the unresolved selection mapping are retained for Phase 4.

The following remain deliberately delayed: lowering unresolved
`firrtl.param_instance_choice` to HW/SV generate constructs, custom
parser/printer syntax for the materialized selector, and frontend/external API
support.  Those belong to Phases 4 and 6.

## Deferred implementation cleanup

The initial materialization implementation intentionally prioritizes direct
representation and diagnostics over traversal consolidation. Two follow-up
improvements are deferred:

- consolidate repeated module, instance, and parameterized-choice traversals;
  in particular, avoid scanning all instances once for every parameterized
  module during port removal;
- factor the pass's coherent workflow stages into helper functions with
  explicit `LogicalResult` propagation.

The `InstanceOp` collection before translating actuals remains deliberate: its
processing erases `firrtl.propassign` operations, so the snapshot avoids
invalidating a walk over the containing module.

## Placement

Run this pass before `firrtl-lower-classes`, because `LowerClasses` currently treats property ports as OM metadata and erases property ports from hardware modules. The pass must also run before transformations that clone, extract, or rewrite instances in ways that lose the parameter assignment relationship.

The initial integration point is immediately before `createLowerClasses()` in the low-FIRRTL-to-HW pipeline, with an earlier placement if later FIRRTL passes need to see a parameter-free IR.

## Failure conditions

- missing or multiple assignments to a parameter sink;
- conditional/ambiguous assignment;
- unsupported property expression;
- forwarding from a non-parameter property;
- parameter used as ordinary RTL data;
- parameter-dependent port/type shape;
- unresolved instance or choice domain.

## Tests and verification

Add pass tests for:

- literal actuals;
- direct forwarding;
- multi-level forwarding;
- two instances with different actuals;
- ordinary properties remaining untouched;
- all negative conditions above.

Use `-verify-diagnostics` for invalid graphs and `FileCheck` for the parameter-free FIRRTL after materialization. Verify that no `ChoiceType`, choice property port, or choice `propassign` remains before `LowerClasses`.

The phase is complete when `LowerClasses` no longer classifies choice parameters as OM metadata and the materialized IR is deterministic under canonicalization and symbol renaming.
