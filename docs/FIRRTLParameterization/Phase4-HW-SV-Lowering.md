# Phase 4: HW and SV Lowering

## Goal

Preserve unresolved formal/actual parameters in HW and select candidate instances with `sv.generate.case`.

## FIRRTL-to-HW changes

- Extend internal FIRRTL module lowering to create `hw.module` parameter declarations.
- Extend ordinary instance lowering to attach parameter actuals to `hw.instance`.
- Convert literals to `hw::ParamDeclAttr` values.
- Convert forwarded parameters to `#hw.param.decl.ref<...>` or the corresponding HW parameter expression.
- Keep parameterized types out of V1; all hardware port types must already be concrete.

The current lowerer maps external FIRRTL parameters to HW parameters; generalize that path for the materialized internal representation rather than adding a second incompatible parameter format.

## `ParamInstChoice` lowering

Lower an unresolved choice to:

1. shared output wires outside the generate block;
2. one `hw.instance` per candidate module;
3. a `sv.generate` containing `sv.generate.case` on the HW parameter reference;
4. assignments from each candidate’s outputs to the shared wires;
5. the existing FIRRTL result mapping to the shared wires.

If the selector is a literal, replace the operation with one ordinary `hw.instance` and do not emit a generate block.

The output must resemble:

```systemverilog
module Outer #(parameter [1:0] impl) (...);
  generate
    case (impl)
      2'd0: Inner_1 inner_1 (...);
      2'd1: Inner_2 inner_2 (...);
    endcase
  endgenerate
endmodule
```

## Name, hierarchy, and diagnostics

- Generate deterministic branch instance names.
- Preserve source locations on the generate block and branch instances.
- Diagnose missing/default cases before Verilog emission.
- Do not use the existing option-choice macro machinery for parameter choices.

## Tests and verification

Add conversion tests for:

- formal HW parameter declaration;
- literal and symbolic instance actuals;
- nested forwarding;
- `sv.generate.case` with two and several alternatives;
- default case behavior;
- identical-interface verification;
- literal specialization;
- emitted Verilog containing one shared parent module and per-instance `#(...)` actuals.

Run:

```sh
ninja -C build bin/circt-opt bin/firtool
```

Then run the FIRRTL-to-HW and Verilog-export lit tests. Compare generated Verilog structurally: no duplicate `Outer` definitions, distinct parameter actuals at `Top`, and no runtime mux or duplicated hardware implementation outside the generate construct.
