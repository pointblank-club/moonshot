# MLIR Backend Overview

The MLIR backend is Moonshot's experimental compiler path that translates OCaml's typed AST directly into MLIR, then uses standard MLIR infrastructure to reach LLVM IR and native object files.

## Why MLIR?

MLIR (Multi-Level Intermediate Representation) was designed to solve a specific problem: different parts of a compiler stack need different levels of abstraction, and translating between them is expensive and error-prone. MLIR provides:

- **Dialects** — domain-specific IRs that can coexist in the same module
- **Progressive lowering** — high-level ops become lower-level ops through rewrite patterns
- **Shared infrastructure** — parsing, printing, validation, and optimization passes work across dialects
- **LLVM integration** — a well-defined path from MLIR to LLVM IR

For Moonshot, this means we can define an `ocaml` dialect that captures OCaml-specific concepts (tagged integers, immutable strings, curried functions) and lower it to standard MLIR dialects as the implementation matures.

## Architecture

The MLIR backend has three layers:

### Layer 1: Frontend (OCaml)

**Files:** `backend/mlir/translate.ml`, `backend/mlir/mlir.ml`

The frontend walks the `Typedtree.implementation` and emits a custom MLIR module using the `ocaml` dialect. It is written in OCaml and uses the `omlir` library to construct MLIR operations.

### Layer 2: Custom dialect + lowering (C++)

**Files:** `backend/mlir/lowering/lib/*.cpp`

The custom dialect is defined in C++ using MLIR's TableGen and C++ APIs. It includes:

- Operation definitions (`ocaml.module`, `ocaml.entry`, `ocaml.int`, `ocaml.binop`, `ocaml.extern`, `ocaml.extern_call`)
- Type definitions (`!ocaml.int`, `!ocaml.string`, `!ocaml.value`)
- Lowering patterns that convert custom ops to `arith`, `func`, `scf`, `llvm` dialect ops

The lowering pass is registered as an `mlir-opt` plugin called `ocaml-mlir-opt`.

### Layer 3: Standard MLIR + LLVM (external tools)

**Tools:** `mlir-opt`, `mlir-translate`, `clang`

After the custom dialect is lowered, the module uses standard MLIR dialects. We run MLIR's built-in passes to reach the `llvm` dialect, then translate to LLVM IR, and finally compile to an object file with `clang`.

## Pipeline at a glance

```
OCaml source (.ml)
   |
   |  optcomp/optcompile.ml fires Compiler_hooks.Mlirize
   v
Typedtree.implementation
   |
   |  backend/mlir/translate.ml: walks structure_items
   v
OxCaml-built MLIR module (ocaml dialect)
   |
   |  shell out: mlir-opt --convert-ocaml-to-arith
   |             --convert-scf-to-cf --convert-cf-to-llvm
   |             --convert-arith-to-llvm --convert-func-to-llvm
   |             --reconcile-unrealized-casts
   v
LLVM dialect
   |
   |  shell out: mlir-translate --mlir-to-llvmir
   v
LLVM IR (.ll)
   |
   |  shell out: clang -c -x ir -
   v
Object file (.o)
```

The shell-outs are orchestrated by `backend/mlir/mlirize.ml` in-process. The only hard-coded path is `/usr/lib/llvm-22/bin` (matching the Debian/Ubuntu `llvm-22-dev` package layout).

## What is supported today

The MLIR backend currently handles these OCaml constructs:

| Construct | Status | MLIR representation |
|---|---|---|
| Integer constants | Working | `ocaml.int` |
| String constants | Working | `ocaml.string` |
| Integer arithmetic (+, -, *, /) | Working | `ocaml.binop` → `arith.addi` etc. |
| Float arithmetic (+, -, *, /) | Working | `ocaml.binop` → `arith.addf` etc. |
| Integer comparisons | Working | `ocaml.binop` → `arith.cmpi` |
| Float comparisons | Working | `ocaml.binop` → `arith.cmpf` |
| Boolean operations (not, &&, \|\|) | Working | `ocaml.binop` + `scf.if` |
| Let bindings | Working | SSA values |
| If-then-else | Working | `scf.if` |
| External function calls | Working | `ocaml.extern_call` + `ocaml.extern` |
| References (ref, !, :=) | Not yet | Needs memory model |
| Lists | Not yet | Needs allocation + GC |
| Arrays | Not yet | Needs allocation + GC |
| Records | Not yet | Needs struct types |
| Variants | Not yet | Needs tag handling |
| Tuples | Not yet | Needs struct types |
| Pattern matching | Not yet | Needs match compilation |
| Closures | Not yet | Needs heap allocation |
| GC | Not yet | Needs runtime integration |
| Exceptions | Not yet | Needs unwind tables |

## What it explicitly rejects

The frontend emits clear error messages for unsupported constructs rather than crashing silently:

- Polymorphic / structural comparison on tuples, records, strings (needs `caml_equal` runtime call)
- Arbitrary `match` expressions (needs pattern compilation)
- `let rec` (needs fixpoint handling)
- Function literals as values (needs closure conversion)
- Non-external function calls (needs calling convention)

## Directory layout

```
backend/mlir/
  mlirize.{ml,mli}              entry point, hook registration, lowering shell-outs
  translate.{ml,mli}            Typedtree → MLIR module
  mlir.{ml,mli}                 helper functions for MLIR emission
  caml_bindings.{ml,mli}        C stubs for runtime helpers
  caml_bindings_stubs.c         C implementation
  lowering/
    CMakeLists.txt              CMake build for the C++ dialect
    include/OCaml/              C++ headers (dialect, passes)
    lib/                        C++ implementation (dialect, lowering, types)
      OCamlDialect.cpp
      OcamlInit.cpp
      OcamlLowering.cpp
      OcamlLoweringTypes.cpp

external/omlir/                 vendored MLIR OCaml bindings
  mlir_bindings/*.ml            AUTO-GENERATED ctypes stubs
  mlir/ir/*.ml                  HAND-WRITTEN low-level wrappers
  mlir/dialects/*.ml            HAND-WRITTEN dialect wrappers
  mlir/omlir.ml                 library main module

oxcaml/tests/backend/mlirize/   dune alias runtest-mlirize
  test_empty.ml                 empty-module sanity test
  test_constants.ml             integer and string constants
  test_arith.ml                 arithmetic operations
  test_extern_call.ml            external C function calls
  helpers.ml                     test utilities
  helpers.c                      C helper functions for tests
```

## Comparison with the CFG-to-LLVM backend

OxCaml already has an experimental LLVM backend (`backend/llvm/`) that translates CFG IR to LLVM IR. The MLIR backend is different:

| Aspect | CFG-to-LLVM | MLIR backend |
|---|---|---|
| Entry IR | Cfg_with_layout | Typedtree |
| Intermediate IR | None (direct) | Custom MLIR → Standard MLIR |
| Optimization | LLVM `opt` | MLIR passes + LLVM `opt` |
| Dialect support | None | Can define OCaml-specific ops |
| GPU / accelerator | Hard | Possible via MLIR GPU dialects |
| Implementation | OCaml | OCaml frontend + C++ dialect |

## Next steps

- [Pipeline](pipeline.md) — the lowering pipeline in detail
- [Dialects](dialects.md) — the custom OCaml dialect reference
- [Lowering](lowering.md) — how custom ops become standard ops
- [Bindings](bindings.md) — how the OCaml code talks to MLIR's C API
- [Contributing](../developer/contributing.md) — how to add a new operation
