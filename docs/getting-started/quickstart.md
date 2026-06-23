# Quickstart

This guide walks you through compiling your first OCaml program with Moonshot, first with the standard CFG backend and then with the experimental MLIR backend.

## Hello world with the CFG backend

The CFG backend is the default and most stable path.

```bash
# Create a file
cat > hello.ml << 'EOF'
let () = print_endline "Hello, World!"
EOF

# Compile and run
ocamlopt hello.ml -o hello
./hello
```

You should see:

```
Hello, World!
```

## Hello world with the MLIR backend

The MLIR backend is triggered with `-mlir-backend`. It currently supports a subset of OCaml (arithmetic, comparisons, constants, and external calls). It compiles through Typedtree → MLIR → LLVM IR → object file.

```bash
# Create a file that the MLIR backend can compile
cat > mlir_demo.ml << 'EOF'
external ( + ) : int -> int -> int = "%addint"
external print_int : int -> unit = "print_int"
let () = print_int (41 + 1)
EOF

# Compile with the MLIR backend
ocamlopt -mlir-backend mlir_demo.ml -o mlir_demo
./mlir_demo
```

If the MLIR backend is not enabled in your build, you will get an error like `unknown option -mlir-backend`. In that case, follow the [build from source](build-from-source.md) instructions.

## Inspecting the intermediate output

One of the main reasons to use the MLIR backend is to inspect the intermediate representations.

### View the custom MLIR dialect

```bash
_build/_bootinstall/bin/ocamlopt.opt -nostdlib -nopervasives \
  -mlir-backend -c mlir_demo.ml
```

This prints the `ocaml.*` dialect, e.g.:

```mlir
ocaml.module @Mlir_demo {
  ocaml.entry {
    %0 = ocaml.int 41 : !ocaml.int
    %1 = ocaml.int 1 : !ocaml.int
    %2 = ocaml.binop "+" %0, %1 : !ocaml.int, !ocaml.int -> !ocaml.int
    %3 = ocaml.extern_call @print_int(%2 : !ocaml.int) : (!ocaml.int) -> !ocaml.value
  }
  ocaml.extern @print_int {target = "print_int"} : (!ocaml.int) -> !ocaml.value
}
```

### View the standard MLIR after lowering

The compiler internally runs `mlir-opt` to lower the custom dialect to standard MLIR (`llvm` dialect). You can see this by running the lowering pipeline manually:

```bash
# First emit the custom MLIR
ocamlopt -mlir-backend -c mlir_demo.ml > custom.mlir

# Then lower it
/usr/lib/llvm-22/bin/mlir-opt \
  --convert-scf-to-cf \
  --convert-cf-to-llvm \
  --convert-arith-to-llvm \
  --convert-func-to-llvm \
  --reconcile-unrealized-casts \
  custom.mlir > standard.mlir
```

### View the LLVM IR

```bash
/usr/lib/llvm-22/bin/mlir-translate --mlir-to-llvmir standard.mlir > output.ll
cat output.ll
```

## Running the in-tree tests

The fastest way to see what the MLIR backend can do today is to run the in-tree tests.

```bash
# Run all MLIR backend tests
make runtest-mlirize

# Promote expected outputs after a change
make runtest-mlirize PROMOTE=1
```

These tests live in `oxcaml/tests/backend/mlirize/` and cover:

- `test_empty.ml` — empty module
- `test_constants.ml` — integer and string constants
- `test_arith.ml` — arithmetic operations
- `test_extern_call.ml` — external C function calls

## Next steps

- [Architecture overview](../architecture/overview.md) — understand how the compiler is organized
- [MLIR backend pipeline](../mlir-backend/pipeline.md) — deep dive into Typedtree → LLVM IR
- [Feature roadmap](../language/roadmap.md) — see what language features are supported
