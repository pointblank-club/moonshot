# OxCaml MLIR Backend

Experimental `-mlir-backend` pipeline.

Pipeline stages:
```
Typedtree
  --[ dialect/ ]--> Hight level dialect for MLIR
      --[ ir/ ]--> Tablegen definitions
  --[ frontend/ ]--> Lowers typedtree to high-level dialect
  --[ lowering  ]--> Hight level dialect to mid-level/llvm dialect
      --[ direct  ]--> Direct lowering to llvm
      --[ through_mlir  ]--> Lowering through MLIR standard dialects like arith, memref, etc.
```

Entry point: `Mlirize.compile_from_typed` (hooked from `optcomp/optcompile.ml`).

## Layout

All files live flat in `backend/mlir/` because OxCaml's root `dune`
concatenates sources into a single unwrapped library. The filename prefix
is the contract:

- `mlir_dialect_<name>.{ml,mli}`  — a dialect definition
- `mlir_lower_<from>_to_<to>.{ml,mli}` — a pass between dialects
- `mlirize.{ml,mli}`  — pipeline orchestrator

## Contribution rule

**One dialect per file, one pass per file.** Do not mix dialect definitions
with lowering passes, and do not merge two passes into a single file. New
contributors must be able to read a single `mlir_dialect_*.ml` to learn
that dialect and a single `mlir_lower_*_to_*.ml` to learn that transition.

When adding a new module, remember two wiring steps:
1. Add the module name to the `ocamloptcomp` library's `modules` list in
   the root `dune` (next to the other `mlir_*` entries).
2. If the new module introduces a new stage in the pipeline, update
   `Mlirize.compile_from_typed` to call it — do not invent a second entry
   point.

## Testing

End-to-end test: `oxcaml/tests/backend/mlirize/`.
Run with `make runtest-mlirize`.
