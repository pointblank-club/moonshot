# MLIR OCaml Bindings

The MLIR backend requires OCaml code to construct and manipulate MLIR operations. This is done through a set of bindings to MLIR's C API. The bindings live in `external/omlir/` and are vendored into the Moonshot repository.

## Architecture of the bindings

The bindings have three layers, each with a different rule for editing:

### Layer 1: Auto-generated ctypes stubs

**Location:** `external/omlir/mlir_bindings/*.ml`

These are direct ctypes stubs of MLIR's C API (`mlirOperationStateGet`, `mlirIntegerTypeGet`, etc.). They are produced by the `ocaml_bindgen` tool reading the MLIR-C headers at `/usr/lib/llvm-22/include/mlir-c/*.h`.

**Rule:** Never edit by hand. Any edits will be lost on the next regeneration.

### Layer 2: Hand-written wrappers

**Location:** `external/omlir/mlir/ir/*.ml`, `external/omlir/mlir/dialects/*.ml`

These layers exist on top of the auto-generated stubs because there are three things bindgen cannot do:

1. **Lifetime / GC fixes.** For example, `mlir/ir/stringRef.ml` keeps a `_buf` field alive so OCaml's GC does not free the C buffer while MLIR is still pointing into it.

2. **Ergonomic OCaml shape.** Records with named fields, optional args, modules per concept, predicate enums (`Arith.Predicate.Eq` instead of raw integers).

3. **Cross-cutting helpers.** `Operation.State.add_operands` takes an OCaml list and allocates a CArray.

**Rule:** Edit these freely. They are the API surface that the frontend uses.

### Layer 3 (future): TableGen-generated bindings

**Location:** `external/omlir/mlir_tablegen/`

The standalone bindings repo also ships a TableGen-based generator. With `-gen-ocaml-bindings` it can read MLIR's `.td` files (e.g., `ArithOps.td`) and produce dialect wrappers automatically. If the dialect wrappers under `mlir/dialects/` start to grow, this layer can replace hand-written files.

**Rule:** Not yet used in Moonshot. Future work.

## Regenerating the auto-generated layer

If you need a C function that does not exist in `mlir_bindings/`:

1. Find which header declares it (`/usr/lib/llvm-22/include/mlir-c/...`).
2. Add a line to the `regenerate` rule in `external/omlir/mlir_bindings/dune`:

```scheme
(rule (alias regenerate)
  (action
    (run %{env:BINDGEN_EXE=}
         %{env:MLIR_ROOT=}/Dialect/Arith.h
         %{env:PROJECT_ROOT=}/mlir_bindings/arith.ml
         --import Support,Ir)))
```

3. Run:

```bash
dune build @regenerate
```

This requires:
- `BINDGEN_EXE` — path to `bindgen.exe` from `pointblank-club/ocaml_bindgen`
- `MLIR_ROOT` — path to MLIR-C headers, typically `/usr/lib/llvm-22/include/mlir-c`
- `PROJECT_ROOT` — the bindings tree, i.e., `external/omlir/`

## Adding a new MLIR op (worked example)

Suppose you want to add `arith.subf` (float subtraction) to the backend.

### Step 1: Check the raw bindings

Does `mlir_bindings/ir.ml` already expose `mlirOperationStateGet` etc.? Yes — the generic op state API works for any op. You do not need to regenerate for `arith.subf` specifically.

### Step 2: Add a wrapper

In `external/omlir/mlir/dialects/arith.ml`, add:

```ocaml
module Subf = struct
  let create ~loc ~lhs ~rhs ~ty =
    binop ~op_name:"arith.subf" ~loc ~lhs ~rhs ~ty
end
```

The `binop` helper at the bottom of `arith.ml` handles two-operand same-type ops.

### Step 3: Wire the frontend

In `backend/mlir/translate.ml`, extend `arith_op_of_prim`:

```ocaml
let arith_op_of_prim = function
  | "%subfloat" -> Some "arith.subf"
  ...
```

The recursive `translate_expr` automatically uses this when it sees a `Texp_apply` whose function is the `%subfloat` primitive.

### Step 4: Test

Add a function to `oxcaml/tests/backend/mlirize/test_arith.ml` using your new primitive. Regenerate the expected output with:

```bash
make -s runtest-mlirize PROMOTE=1
```

## Key wrapper modules

| Module | Purpose | File |
|---|---|---|
| `MlirContext` | MLIR context (owns types, ops) | `mlir/ir/context.ml` |
| `Operation` | MLIR operations | `mlir/ir/operation.ml` |
| `Type` | MLIR types | `mlir/ir/type.ml` |
| `Value` | MLIR values (operands, results) | `mlir/ir/value.ml` |
| `Attribute` | MLIR attributes | `mlir/ir/attribute.ml` |
| `Block` | MLIR blocks | `mlir/ir/block.ml` |
| `Builders.OpBuilder` | Op builder (insertion point) | `mlir/ir/builders.ml` |
| `Func` | `func` dialect wrappers | `mlir/dialects/func.ml` |
| `Arith` | `arith` dialect wrappers | `mlir/dialects/arith.ml` |
| `SCF` | `scf` dialect wrappers | `mlir/dialects/scf.ml` |
| `LLVM` | `llvm` dialect wrappers | `mlir/dialects/llvm.ml` |

## Next steps

- [MLIR backend overview](overview.md) — how the bindings fit into the backend
- [Contributing](../developer/contributing.md) — how to add ops and tests
- [ocaml_bindgen repo](https://github.com/pointblank-club/ocaml_bindgen) — the binding generator tool
