# FIRRTL Choice-Parameter Implementation Plan

This directory breaks the restricted FIRRTL parameter proposal into independently reviewable phases.

The target use case is per-instance structural selection without duplicating wrapper modules:

```text
Top
|- Outer<impl = ID1> -> Inner_1
`- Outer<impl = ID2> -> Inner_2
```

The FIRRTL representation uses an elaboration-only choice property and `propassign` for parameter forwarding. The choice is materialized into HW module/instance parameters and emitted as an SV `generate.case`.

## Phase order

1. [Semantics and IR contract](Phase0-Semantics.md)
2. [Choice domain and choice type](Phase1-ChoiceType.md)
3. [Parameterized instances and `ParamInstChoice`](Phase2-ParamInstChoice.md)
4. [Property-to-parameter materialization](Phase3-MaterializeParameters.md)
5. [HW/SV lowering](Phase4-HW-SV-Lowering.md)
6. [Pipeline and pass compatibility](Phase5-PassIntegration.md)
7. [Frontend, parser, API, and end-to-end validation](Phase6-IntegrationValidation.md)

Each phase has an explicit exit criterion. A later phase should not silently expand the semantics of an earlier one.
