# Phase 2: Parameterized Instances and `ParamInstChoice`

## Goal

Represent per-instance parameter selection in FIRRTL while preserving the existing `firrtl.instance_choice` option-based behavior.

## Proposed operation

Add a dedicated operation, tentatively:

```mlir
%in, %out = firrtl.param_instance_choice inner %impl
  @InnerDefault alternatives @ImplKind {
    @ID1 -> @Inner_1,
    @ID2 -> @Inner_2
  } (in: %data) -> (out: !firrtl.uint<8>)
```

The selector is an explicit `ChoiceType` operand, not a synthetic hardware port. The operation should implement the same instance/instance-graph interfaces as `InstanceChoiceOp` where practical.

For now, custom textual FIRRTL parser/printer syntax and external APIs are
deliberately deferred.  The operation is available through generic MLIR syntax;
the semantic verifier, instance-graph interface, literal canonicalization, and
lowering diagnostic are the Phase 2 scope.

## Verifier requirements

- Selector domain matches the case domain.
- Every case references a valid case and module.
- Candidate modules have identical port names, directions, types, domains, and layer requirements.
- Candidate modules are legal internal targets for V1.
- Default or exhaustive selection is present.
- The selector is elaboration-only and cannot be produced by hardware operations.
- Unsupported inner symbols, probes, and path-sensitive annotations are rejected initially.

The current implementation uses generic MLIR assembly.  It rejects inner
symbols, non-empty operation/port annotations, probe ports, external/class
targets, missing or duplicate choice cases, and mismatched selector domains.
Literal `firrtl.choice.constant` selectors canonicalize directly to
`firrtl.instance`; forwarded or otherwise unresolved choice values remain in
the parameterized operation and produce a deliberate hardware-lowering error.

## Canonicalization choice

Prefer canonicalizing the operation to a shared instance-choice implementation with explicit selector/case-value metadata. This reuses instance graph, cloning, port verification, and result mapping logic without conflating the operation with global option macros.

Do not make `SpecializeOption` select this operation. A literal selector may be folded by a separate parameter-specialization pass; an unresolved selector must remain parameter-driven.

## Tests and verification

Add tests for:

- one default plus two alternatives;
- different selectors on two instances of the same parent;
- forwarding a selector through two or more wrappers;
- literal selector folding;
- selector-domain mismatch;
- duplicate/missing cases;
- candidate port mismatch;
- illegal runtime selector and unsupported symbol/path cases.

Run FIRRTL verifier, parser, and instance-graph tests after each IR change. Add `FileCheck` assertions that ordinary `firrtl.instance_choice` remains unchanged.

Exit when the operation verifies, prints, participates in the instance graph, and can be folded to a normal `firrtl.instance`, but still emits a clear “not lowered” diagnostic for the unresolved case.
