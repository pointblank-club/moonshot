# Backends

Moonshot has three backends that can turn OCaml source into machine code. This page compares them so you can choose the right one for your use case and understand where the MLIR backend fits.

## The three backends

| Backend | Flag | Status | Use case |
|---|---|---|---|
| **Classic** (Mach linear) | `-classic-backend` | Stable, legacy | Compatibility with older OCaml versions |
| **CFG** | default | Production | General OCaml development |
| **MLIR** | `-mlir-backend` | Experimental | Research, LLVM ecosystem integration, future optimization |
| **LLVM** | `-fllvm` | Experimental | CFG-based LLVM emission |

## Classic backend

The original OCaml native backend. It has been around since the early days of OCaml and is well-tested.

### Pipeline

```
Typedtree → Lambda → Clambda → Cmm → Mach (linear) → Assembly → Object
```

### Characteristics

- Linear instruction sequence (not a graph)
- Register allocation via graph coloring
- Assembly emission is target-specific
- Supports all OCaml features
- Slower compile times than CFG for some workloads

### When to use

You generally do not need to use the classic backend. It exists mainly for regression testing and comparison with the CFG backend.

## CFG backend

The default backend in OxCaml. It replaces the linear `Mach` IR with a control-flow graph representation.

### Pipeline

```
Typedtree → Lambda → Clambda → Cmm → Cfg_with_layout → Assembly → Object
```

### Characteristics

- Control-flow graph representation enables more aggressive optimizations
- Register allocation via graph coloring or linear scan
- Peephole optimization on CFG
- Stack check elimination
- Prologue shrink-wrapping
- Value propagation
- Supports vectorization (experimental)

### Key flags

| Flag | Default | Description |
|---|---|---|
| `-regalloc` | `cfg` | Register allocator: `cfg` (graph coloring) or `linear-scan` |
| `-cfg-peephole-optimize` | on | Enable CFG peephole optimizer |
| `-vectorize` | off | Enable vectorization |
| `-cfg-stack-check` | on | Enable stack checks |
| `-cfg-eliminate-dead-trap-handlers` | off | Eliminate dead trap handlers |

### When to use

This is the default. Use it for all production OCaml code unless you are experimenting with the MLIR backend.

## LLVM backend (via CFG)

An experimental backend that converts the CFG IR to LLVM IR instead of emitting assembly.

### Pipeline

```
Typedtree → Lambda → Clambda → Cmm → Cfg_with_layout → LLVM IR → Object
```

### Files

- `backend/llvm/llvmize.ml` — main translation logic
- `backend/llvm/llvm_ir.ml` — LLVM IR data types and emission

### Characteristics

- Emits LLVM IR text from the CFG representation
- Uses the same optimization pipeline as the CFG backend up to the CFG stage
- Can leverage LLVM's optimizer (`opt`) and code generator (`llc`)
- Currently experimental, not all features are supported

### When to use

This is a separate experiment from the MLIR backend. It is useful if you want to use LLVM's ecosystem from the existing CFG pipeline.

## MLIR backend (Moonshot)

The newest backend. It bypasses Lambda, Clambda, Cmm, and CFG entirely, going directly from Typedtree to MLIR.

### Pipeline

```
Typedtree → Custom MLIR (ocaml dialect) → Standard MLIR (llvm dialect) → LLVM IR → Object
```

### Files

- `backend/mlir/mlirize.ml` — compiler hook registration
- `backend/mlir/translate.ml` — Typedtree to custom MLIR
- `backend/mlir/mlir.ml` — helper functions for MLIR emission
- `backend/mlir/lowering/lib/OcamlLowering.cpp` — custom dialect lowering
- `backend/mlir/lowering/lib/OcamlInit.cpp` — dialect initialization
- `backend/mlir/lowering/lib/OcamlTypes.cpp` — type conversion
- `external/omlir/` — MLIR OCaml bindings

### Characteristics

- Direct translation from Typedtree preserves high-level type information
- Custom MLIR dialect captures OCaml-specific concepts (tagged integers, strings, externals)
- Uses MLIR's standard lowering infrastructure (`mlir-opt`)
- Can leverage MLIR's optimization passes (future work)
- LLVM ecosystem integration (can use `mlir-translate`, `clang`, `llc`)
- Currently limited to a subset of OCaml (no GC, no exceptions, no stdlib)

### Key flags

| Flag | Description |
|---|---|
| `-mlir-backend` | Enable the MLIR backend |

### When to use

Use the MLIR backend if you are:

- Contributing to the Moonshot project
- Researching retargetable backends for functional languages
- Interested in MLIR/LLVM ecosystem integration
- Building custom optimization passes on MLIR

Do not use it for production code yet.

## Feature comparison

| Feature | Classic | CFG | LLVM (via CFG) | MLIR |
|---|---|---|---|---|
| Full OCaml language | Yes | Yes | Partial | Partial |
| GC | Yes | Yes | Yes | No |
| Exceptions | Yes | Yes | Yes | No |
| Stdlib | Yes | Yes | Yes | No |
| Flambda 2 | Yes | Yes | Yes | No |
| Cross-compilation | No | No | No | Future |
| Custom optimizations | Limited | Good | Good (via LLVM) | Future (via MLIR) |
| JIT compilation | No | No | Future | Future |
| GPU offloading | No | No | No | Future |

## Performance notes

The MLIR backend is currently not optimized for performance. The focus is on correctness and infrastructure. As the backend matures, we expect to:

1. Run MLIR optimization passes (CSE, inlining, loop optimization)
2. Use LLVM's optimizer (`opt -O3`)
3. Leverage MLIR's GPU dialects for offloading

The CFG backend remains the performance baseline for now.

## Next steps

- [MLIR backend overview](../mlir-backend/overview.md) — deep dive into the new backend
- [Compiler pipeline](compiler-pipeline.md) — step-by-step flow for each backend
- [Feature roadmap](../language/roadmap.md) — what works in each backend
