# Contributing

This guide is for people who want to modify the Moonshot compiler. It covers the workflow from making a change to getting it merged.

## Prerequisites

Before contributing, you should:

1. Build the compiler from source (see [build from source](../getting-started/build-from-source.md))
2. Run the tests to verify your build works
3. Read the [architecture overview](../architecture/overview.md) to understand the codebase

## Development workflow

### 1. Make a branch

```bash
git checkout -b myfeature origin/main
```

### 2. Configure and build

```bash
autoconf
./configure --prefix=/path/to/install/dir
make -s boot-compiler
```

Always run `make -s boot-compiler` before testing. It is the fastest way to check that your change compiles.

### 3. Make your change

Follow the existing code style:

- Keep lines under 80 characters
- Use pattern matching and functional programming idioms
- Do not add `assert false` or other unreachable code
- Do not add excessive comments unless the logic is genuinely complex
- Match the indentation style already used in the file

### 4. Format

```bash
make -s fmt
```

Always run this before committing. It ensures consistent formatting across the codebase.

### 5. Build again

```bash
make -s boot-compiler
```

### 6. Run tests

```bash
# Full test suite
make -s test

# Run a specific MLIR test case using Dune
opam exec -- dune runtest duneconf/boot.ws oxcaml/tests/backend/mlirize --filter test_arith

# Run only the MLIR backend tests
make -s runtest-mlirize

# Promote MLIR backend tests
make -s runtest-mlirize PROMOTE=1
```

### 7. Commit

```bash
git add -p
git commit -s -m "description of change"
```

Commit messages should be clear and direct. Do not use fluff like "Great feature!" or "This is important because...". State what changed and why.

Example:

```
Add float subtraction to the MLIR backend

The arith dialect already supports arith.subf. This wires it through
the OCaml frontend so that ( -. ) on floats compiles via the MLIR
backend.
```

### 8. Push and open a PR

```bash
git push origin myfeature
```

Then open a pull request on GitHub. Include:

- What the change does
- Why it is needed
- How you tested it
- Any known limitations or follow-up work

## Adding a new MLIR operation

This is the most common contribution for the MLIR backend. Here is the full workflow.

### Example: add `arith.subf` (float subtraction)

#### Step 1: Check the raw bindings

Look in `external/omlir/mlir_bindings/ir.ml`. Does it already expose `mlirOperationStateGet`? Yes — the generic op state API works for any op. You do not need to regenerate bindings.

#### Step 2: Add a wrapper

In `external/omlir/mlir/dialects/arith.ml`, add:

```ocaml
module Subf = struct
  let create ~loc ~lhs ~rhs ~ty =
    binop ~op_name:"arith.subf" ~loc ~lhs ~rhs ~ty
end
```

#### Step 3: Wire the frontend

In `backend/mlir/translate.ml`, extend `arith_op_of_prim`:

```ocaml
let arith_op_of_prim = function
  | "%addfloat" -> Some "arith.addf"
  | "%subfloat" -> Some "arith.subf"
  | "%mulfloat" -> Some "arith.mulf"
  | "%divfloat" -> Some "arith.divf"
  | _ -> None
```

The recursive `translate_expr` automatically uses this when it sees a `Texp_apply` whose function is the primitive.

#### Step 4: Add a C++ lowering pattern (if needed)

If the op maps to an existing `arith` dialect op, the generic lowering in `OcamlLowering.cpp` may already handle it. Check the `BinopOpLowering` pattern. If it does not, add a case:

```cpp
} else if (opName == "arith.subf") {
  result = rewriter.create<arith::SubFOp>(loc, lhs_val, rhs_val);
```

#### Step 5: Test

Add a test in `oxcaml/tests/backend/mlirize/test_arith.ml`:

```ocaml
let%expect_test "float subtraction" =
  let t =
    test_compile ~name:"float_sub"
      ~code:
        "\n\
        \    external ( -. ) : float -> float -> float = \"%subfloat\"\n\
        \    let res = 5.0 -. 3.0\n\
        \  "
  in
  verify_mlir t;
  [%expect {|
    ocaml.module @Float_sub {
      ocaml.entry {
        %0 = ocaml.float 5.0 : !ocaml.float
        %1 = ocaml.float 3.0 : !ocaml.float
        %2 = ocaml.binop "-." %0, %1 : !ocaml.float, !ocaml.float -> !ocaml.float
      }
    }
    |}];
  verify_stdout t;
  [%expect {| 2.0 |}]
```

Run the test:

```bash
make -s runtest-mlirize
```

If it fails because the expected output changed, promote it:

```bash
make -s runtest-mlirize PROMOTE=1
```

#### Step 6: Build and test everything

```bash
make -s boot-compiler
make -s test
make -s fmt
```

## Working with the MLIR bindings

### Regenerating auto-generated stubs

If you need a C function that is not in `mlir_bindings/`:

1. Find the header: `/usr/lib/llvm-22/include/mlir-c/Dialect/Arith.h`
2. Add a line to the `regenerate` rule in `external/omlir/mlir_bindings/dune`:

```scheme
(run %{env:BINDGEN_EXE=}
     %{env:MLIR_ROOT=}/Dialect/Arith.h
     %{env:PROJECT_ROOT=}/mlir_bindings/arith.ml
     --import Support,Ir)
```

3. Run:

```bash
dune build @regenerate
```

### Adding a new wrapper module

If you need to wrap a C function that is already in `mlir_bindings/ir.ml`:

1. Create a new file in `external/omlir/mlir/ir/` or `external/omlir/mlir/dialects/`
2. Write the wrapper using the existing patterns (see `stringRef.ml`, `operation.ml`)
3. Export it from `external/omlir/mlir/omlir.ml`
4. Use it in the frontend

## Debugging a failing test

If a test fails, the first thing to do is run it in isolation:

```bash
opam exec -- dune runtest duneconf/boot.ws oxcaml/tests/backend/mlirize --filter test_arith
```

This prints the full output including diffs. For MLIR backend tests, the output includes:

1. The custom MLIR dialect
2. The standard MLIR after lowering
3. The LLVM IR
4. The stdout (if running)

If the output is unexpected, compare it against the expect blocks in the test file.

## Common mistakes

- **Forgetting to run `make -s fmt`** — CI will reject unformatted code
- **Editing `mlir_bindings/*.ml` by hand** — These are auto-generated; your changes will be lost
- **Not running `make -s test`** — Even small changes can break tests in unexpected ways
- **Adding `assert false`** — Use `Misc.fatal_error` for impossible cases, not `assert false`
- **Not updating expected outputs** — If a test legitimately changes output, promote it with `PROMOTE=1`

## Next steps

- [Debugging](debugging.md) — what to do when things break
- [Testing](testing.md) — how the test suite works
- [MLIR backend overview](../mlir-backend/overview.md) — how the backend is organized
