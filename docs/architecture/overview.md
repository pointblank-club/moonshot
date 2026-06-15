# Architecture Overview

Moonshot is a fork of the OxCaml compiler with an experimental MLIR backend. To understand the architecture, it helps to know the upstream compiler first, then see where the new pieces fit.

## Upstream OxCaml at a glance

OxCaml is a performance-focused fork of OCaml maintained by Jane Street. It is based on OCaml 5.2.0 and contains two major additions over upstream:

1. **Flambda 2** — a whole-program optimizer that works in CPS (continuation-passing style)
2. **CFG backend** — a native code backend that uses control-flow graphs instead of the older linear IR

OxCaml supports both the OCaml 4 and OCaml 5 runtime systems, though OCaml 4 runtime support is expected to be removed in autumn 2025.

## Where Moonshot fits in

Moonshot adds a **third backend** that sits alongside the CFG backend: the MLIR backend. Instead of the traditional path through `Lambda` → `Clambda` → `Cmm` → `Cfg`, the MLIR backend goes directly from `Typedtree` to MLIR, then through standard MLIR lowering passes to LLVM IR, and finally to object files.

## High-level directory layout

The source tree is organized like upstream OCaml, with extra directories for the new backends.

| Directory | Purpose | Upstream or Moonshot? |
|---|---|---|
| `parsing/` | Lexer, parser, AST | Upstream |
| `typing/` | Type inference, Typedtree | Upstream |
| `lambda/` | Lambda IR (simplified AST) | Upstream |
| `middle_end/flambda2/` | Flambda 2 optimizer | OxCaml |
| `backend/cfg/` | CFG backend (machine code) | OxCaml |
| `backend/llvm/` | LLVM IR emission from CFG | OxCaml (experimental) |
| `backend/mlir/` | **MLIR backend** — Typedtree to MLIR | **Moonshot** |
| `backend/mlir/lowering/` | C++ MLIR dialect + lowering passes | **Moonshot** |
| `driver/` | Compiler driver, command-line parsing | Upstream + OxCaml flags |
| `runtime/` | OCaml 5 runtime (GC, systhreads, etc.) | Upstream |
| `runtime4/` | OCaml 4 runtime | OxCaml (legacy) |
| `external/omlir/` | Vendored MLIR OCaml bindings | **Moonshot** |
| `jane/` | Jane Street extensions (modes, layouts, etc.) | OxCaml |
| `oxcaml/tests/` | OxCaml-specific tests | OxCaml + Moonshot |

## The three backends

Moonshot currently has three ways to turn OCaml source into machine code:

### 1. The classic backend (upstream)

```
Source (.ml)
   |
   v
Typedtree
   |
   v
Lambda
   |
   v
Clambda
   |
   v
Cmm
   |
   v
Mach (linear)
   |
   v
Assembly (.s)
   |
   v
Object file (.o)
```

This is the original OCaml native backend. It is stable but not the default in OxCaml.

### 2. The CFG backend (OxCaml default)

```
Source (.ml)
   |
   v
Typedtree
   |
   v
Lambda
   |
   v
Clambda
   |
   v
Cmm
   |
   v
Cfg_with_layout
   |
   v
Assembly (.s)
   |
   v
Object file (.o)
```

The CFG backend replaces the linear `Mach` IR with a control-flow graph. It is the default when you run `ocamlopt` without special flags.

### 3. The MLIR backend (Moonshot, experimental)

```
Source (.ml)
   |
   v
Typedtree
   |
   v
Custom MLIR dialect (ocaml.*)
   |
   v
Standard MLIR dialects (func, arith, scf, cf, llvm)
   |
   v
LLVM dialect
   |
   v
LLVM IR (.ll)
   |
   v
Object file (.o)
```

The MLIR backend skips Lambda, Clambda, Cmm, and CFG entirely. It translates the typed AST directly into a custom `ocaml` MLIR dialect, then runs standard MLIR lowering passes to reach the LLVM dialect, and finally emits LLVM IR that `clang` compiles to an object file.

## Key design decisions

### Why skip Lambda and Cmm?

The MLIR backend is intentionally a **frontend-focused** experiment. By going directly from Typedtree to MLIR, we can:

- Avoid re-implementing the entire OCaml runtime ABI in LLVM IR
- Use MLIR's existing infrastructure for arithmetic, control flow, and function calls
- Incrementally add support for new OCaml features without touching the older IRs

The trade-off is that we must handle the OCaml runtime (GC, exceptions, tagged values) explicitly in the custom dialect and lowering passes.

### Why a custom dialect?

OCaml has language-specific concepts that do not map cleanly to standard MLIR dialects:

- Tagged integer representation (low bit is 1 for immediates)
- Immutable strings with custom headers
- Curried functions and closures
- Algebraic data types (variants, records)

The `ocaml` dialect captures these concepts at a high level, then lowers them to `arith`, `func`, `scf`, and eventually `llvm` as the implementation matures.

### Relationship to the LLVM backend

OxCaml already has an experimental LLVM backend in `backend/llvm/` that works by translating the CFG IR to LLVM IR. The MLIR backend is a separate, more ambitious path that uses MLIR as the primary IR and does not depend on the CFG backend at all.

## Component map

| Component | Source files | Description |
|---|---|---|
| Typedtree | `typing/*.ml`, `parsing/*.ml` | The fully typed AST |
| MLIR translation | `backend/mlir/translate.ml` | Typedtree → custom MLIR dialect |
| MLIR orchestration | `backend/mlir/mlirize.ml` | Compiler hook, shell-outs to mlir-opt / mlir-translate |
| MLIR dialect C++ | `backend/mlir/lowering/lib/*.cpp` | Custom `ocaml` dialect ops and lowering passes |
| MLIR bindings | `external/omlir/mlir/*.ml` | Hand-written OCaml wrappers around MLIR C API |
| Auto-generated bindings | `external/omlir/mlir_bindings/*.ml` | ctypes stubs generated by `ocaml_bindgen` |
| LLVM IR emission | `backend/llvm/llvmize.ml` | CFG → LLVM IR (separate from MLIR path) |
| Compiler driver | `driver/optcompile.ml`, `driver/oxcaml_flags.ml` | Entry points, flag handling |
| Flambda 2 | `middle_end/flambda2/` | Whole-program optimizer |
| CFG backend | `backend/cfg/` | Native code backend |

## Data flow through the compiler

For a single `.ml` file, the compiler performs these steps:

1. **Parse** — `parsing/` produces a `Parsetree`
2. **Type** — `typing/` produces a `Typedtree.implementation`
3. **Hook** — `Compiler_hooks.Mlirize` is fired when `-mlir-backend` is set
4. **Translate** — `backend/mlir/translate.ml` walks `structure_items` and emits MLIR
5. **Lower** — `mlir-opt` runs the custom-to-standard lowering pipeline
6. **Translate** — `mlir-translate` converts standard MLIR to LLVM IR
7. **Compile** — `clang -c` turns LLVM IR into an object file

For the default CFG backend, steps 3–7 are replaced by the standard OxCaml pipeline through Lambda, Flambda 2 (optional), Clambda, Cmm, and CFG.

## Runtime considerations

The MLIR backend currently does not link the OCaml runtime. This means:

- The GC is not invoked (acceptable for small tests without allocations)
- Exception handling is not implemented
- The standard library (`Stdlib`, `Unix`, etc.) is not available
- Only operations that compile to pure arithmetic or direct C calls work

Getting the GC + hello world to compile is an explicit milestone on the roadmap.

## Next steps

- [Compiler pipeline](compiler-pipeline.md) — detailed step-by-step flow
- [IRs](irs.md) — what each intermediate representation looks like
- [Backends](backends.md) — comparing the three backends in detail
- [MLIR backend overview](../mlir-backend/overview.md) — the new backend in depth
