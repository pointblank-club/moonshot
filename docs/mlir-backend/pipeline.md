# MLIR Lowering Pipeline

This page describes the exact sequence of transformations that turn a custom `ocaml` dialect module into a native object file. It is the heart of the MLIR backend.

## The pipeline

```
Custom MLIR (ocaml dialect)
   |
   |  --convert-ocaml-to-arith
   v
Standard MLIR (arith, func, scf)
   |
   |  --convert-scf-to-cf
   v
Standard MLIR (arith, func, cf)
   |
   |  --convert-cf-to-llvm
   |  --convert-arith-to-llvm
   |  --convert-func-to-llvm
   v
Standard MLIR (llvm dialect)
   |
   |  --reconcile-unrealized-casts
   v
Clean LLVM dialect
   |
   |  mlir-translate --mlir-to-llvmir
   v
LLVM IR (.ll)
   |
   |  clang -c -x ir
   v
Object file (.o)
```

## Step 1: Custom lowering (`--convert-ocaml-to-arith`)

**File:** `backend/mlir/lowering/lib/OcamlLowering.cpp`

This is the custom pass written for Moonshot. It lowers the `ocaml` dialect to a mix of `arith`, `func`, `scf`, and `llvm` dialect ops.

### Lowering patterns

#### `ocaml.module` → `module`

The module container is stripped. Its symbol name becomes the prefix for entry function and globals.

#### `ocaml.entry` → `llvm.func`

The entry op is lowered to an LLVM function:

```mlir
// Before
ocaml.entry {
  ...
}

// After
llvm.func @caml<ModuleName>__entry() -> i64 {
  ...
  llvm.return %unit : i64
}
```

The function returns `i64` (the OCaml unit value, `1`). This matches the OCaml runtime convention for module entry functions.

#### `ocaml.int` → `arith.constant`

Integer constants are untagged during lowering. OCaml immediate integers are shifted left by 1 and have the low bit set to 1. So `42` becomes `85` in the LLVM IR:

```mlir
// Before
%0 = ocaml.int 42 : !ocaml.int

// After
%0 = arith.constant 85 : i64
```

#### `ocaml.string` → `llvm.mlir.global`

Strings are lowered to global constants with the OCaml string header:

```mlir
// Before
%0 = ocaml.string "hello" : !ocaml.string

// After
llvm.mlir.global external constant @camlModule.1("\FC\07...hello\00...") : !llvm.array<16 x i8>
%ptr = llvm.mlir.addressof @camlModule.1 : !llvm.ptr
%str = llvm.getelementptr %ptr[8] : (!llvm.ptr) -> !llvm.ptr, i8
```

The header contains the string length and color (GC marking) information. The pointer returned skips the 8-byte header.

#### `ocaml.binop` → `arith.*` / `llvm.*`

Binary operations are lowered based on the operator name and operand types:

| OCaml op | MLIR op | Notes |
|---|---|---|
| `"+"` (int) | `arith.addi` | After untagging operands |
| `"*"` (int) | `arith.muli` | After untagging operands |
| `"-"` (int) | `arith.subi` | After untagging operands |
| `"/"` (int) | `arith.divsi` | Signed division |
| `"+"` (float) | `arith.addf` | Float addition |
| `"="` | `arith.cmpi eq` | Integer equality |
| `"<"` | `arith.cmpi slt` | Signed less than |
| ... | ... | ... |

For integer ops, the operands are first untagged (shifted right by 1), the operation is performed, and the result is retagged (shifted left by 1 and OR'd with 1).

#### `ocaml.extern` → `llvm.func` declaration

External functions are declared with the LLVM function type derived from the OCaml external declaration:

```mlir
// Before
ocaml.extern @puts {target = "caml_puts"} : (!ocaml.string) -> !ocaml.int

// After
llvm.func @caml_puts(!llvm.ptr) -> i64
```

#### `ocaml.extern_call` → `llvm.call`

External calls are lowered to direct LLVM calls:

```mlir
// Before
%1 = ocaml.extern_call @puts(%0 : !ocaml.string) : (!ocaml.string) -> !ocaml.int

// After
%1 = llvm.call @caml_puts(%0) : (!llvm.ptr) -> i64
```

### Runtime globals

The lowering pass also inserts the runtime globals that the OCaml linker expects:

```mlir
llvm.mlir.global external @camlModule__gc_roots(0 : i64) : i64
llvm.mlir.global external @camlModule__data_begin(0 : i64) : i64
llvm.mlir.global external @camlModule__data_end(0 : i64) : i64
llvm.mlir.global external @camlModule__code_begin(0 : i64) : i64
llvm.mlir.global external @camlModule__code_end(0 : i64) : i64
llvm.mlir.global external @camlModule__frametable(0 : i64) : i64
```

These are currently zero-initialized stubs. In the future, they will contain real GC roots, frame tables, and data segment boundaries.

## Step 2: SCF to CF (`--convert-scf-to-cf`)

MLIR's `scf` (structured control flow) dialect contains high-level control flow like `scf.if` and `scf.for`. This pass lowers them to the `cf` (control flow) dialect, which uses basic blocks and branches:

```mlir
// Before (scf)
scf.if %cond {
  ...
} else {
  ...
}

// After (cf)
cf.cond_br %cond, ^then, ^else
^then:
  ...
  cf.br ^merge
^else:
  ...
  cf.br ^merge
^merge:
```

## Step 3: CF to LLVM (`--convert-cf-to-llvm`)

The `cf` dialect is lowered to LLVM dialect branch instructions:

```mlir
// Before (cf)
cf.cond_br %cond, ^then, ^else

// After (llvm)
llvm.cond_br %cond, ^then, ^else
```

## Step 4: Arith to LLVM (`--convert-arith-to-llvm`)

Arithmetic operations in the `arith` dialect are lowered to LLVM dialect instructions:

```mlir
// Before (arith)
%0 = arith.addi %a, %b : i64

// After (llvm)
%0 = llvm.add %a, %b : i64
```

## Step 5: Func to LLVM (`--convert-func-to-llvm`)

Function definitions and declarations are converted to LLVM dialect:

```mlir
// Before (func)
func.func @foo(%arg0: i64) -> i64 {
  return %arg0 : i64
}

// After (llvm)
llvm.func @foo(i64) -> i64 {
  llvm.return %arg0 : i64
}
```

## Step 6: Reconcile casts (`--reconcile-unrealized-casts`)

During lowering, some operations may produce `unrealized_conversion_cast` ops where types change between dialects. This pass removes them when they are no longer needed.

## Step 7: Translate to LLVM IR

**Tool:** `mlir-translate --mlir-to-llvmir`

This is a standard LLVM tool that converts the LLVM dialect to LLVM IR text. The output is a `.ll` file that can be consumed by `opt`, `llc`, or `clang`.

## Step 8: Compile to object file

**Tool:** `clang -c -x ir`

Clang compiles the LLVM IR to a native object file. This is the final output of the MLIR backend.

## Example: full pipeline for `let x = 4 + 3`

### OCaml source

```ocaml
let x = 4 + 3
```

### Custom MLIR (after frontend)

```mlir
ocaml.module @Foo {
  ocaml.entry {
    %0 = ocaml.int 4 : !ocaml.int
    %1 = ocaml.int 3 : !ocaml.int
    %2 = ocaml.binop "+" %0, %1 : !ocaml.int, !ocaml.int -> !ocaml.int
  }
}
```

### After `--convert-ocaml-to-arith`

```mlir
module {
  func.func @camlFoo__entry() -> i64 {
    %0 = arith.constant 4 : i64
    %1 = arith.constant 3 : i64
    %2 = arith.addi %0, %1 : i64
    %unit = arith.constant 1 : i64
    return %unit : i64
  }
}
```

Note: in this case, the constant folding happens in the custom lowering (the untagging/retagging is optimized away because both operands are constants). In the actual implementation, the arithmetic is done on untagged values and the result is retagged.

### After `--convert-arith-to-llvm` and `--convert-func-to-llvm`

```mlir
module {
  llvm.func @camlFoo__entry() -> i64 {
    %0 = llvm.mlir.constant(7 : i64) : i64
    llvm.return %0 : i64
  }
}
```

### LLVM IR

```llvm
; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"

define i64 @camlFoo__entry() {
  ret i64 7
}
```

## Custom `mlir-opt` plugin

The lowering pass is packaged as a standalone `mlir-opt` plugin called `ocaml-mlir-opt`. It is built by CMake in `backend/mlir/lowering/` and linked against the installed MLIR libraries.

To build it:

```bash
make mlir-dialect
```

This runs CMake + Ninja in the lowering directory and produces the plugin shared library.

To use it manually:

```bash
/usr/lib/llvm-22/bin/mlir-opt \
  --load-dialect-plugin=path/to/ocaml-mlir-opt.so \
  --convert-ocaml-to-arith \
  input.mlir
```

The compiler driver (`mlirize.ml`) handles this automatically when `-mlir-backend` is set.

## Next steps

- [Dialects](dialects.md) — reference for the custom OCaml dialect
- [Lowering](lowering.md) — C++ implementation details
- [Bindings](bindings.md) — the OCaml-to-MLIR C API bindings
- [Adding a new operation](../developer/contributing.md#adding-a-new-mlir-op) — contributor guide
