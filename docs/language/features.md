# Language Features

This page documents the OCaml language features supported by Moonshot, with notes on which backend supports each feature and what the status is in the MLIR backend.

## Core language features

### Arithmetic

| Feature | CFG | MLIR | Notes |
|---|---|---|---|
| Integer `+`, `-`, `*`, `/` | Yes | Yes | `int`, `int32`, `int64`, `nativeint` |
| Float `+.`, `-.`, `*.`, `/.` | Yes | Yes | Via `arith.addf` etc. |
| Integer modulus | Yes | No | Not yet in MLIR backend |
| Float modulus | Yes | No | Not yet in MLIR backend |
| Bitwise ops | Yes | No | Not yet in MLIR backend |
| Integer negation | Yes | Yes | Via `arith.subi` with 0 |
| Float negation | Yes | Yes | Via `arith.subf` with 0.0 |

### Comparisons

| Feature | CFG | MLIR | Notes |
|---|---|---|---|
| `=` (structural) | Yes | No | Needs `caml_equal` runtime call |
| `==` (physical) | Yes | No | Needs pointer comparison |
| `<`, `>`, `<=`, `>=` | Yes | Yes | Int, float, char, bool |
| `!=` | Yes | No | Not yet in MLIR backend |

The MLIR backend currently supports comparison primitives (`%equal`, `%notequal`, `%lessthan`, `%lessequal`, `%greaterthan`, `%greaterequal`, `%eq`, `%noteq`) on scalar types. It explicitly rejects structural comparison on aggregates because that requires a runtime call to `caml_equal`.

### Boolean logic

| Feature | CFG | MLIR | Notes |
|---|---|---|---|
| `not` | Yes | Yes | Via `arith.xori` with 1 |
| `&&` | Yes | Yes | Via `scf.if` |
| `\|\|` | Yes | Yes | Via `scf.if` |

### Let bindings

| Feature | CFG | MLIR | Notes |
|---|---|---|---|
| `let x = e` | Yes | Yes | SSA values in MLIR |
| `let rec` | Yes | No | Needs fixpoint handling in MLIR |
| Pattern bindings | Yes | No | Needs pattern compilation |

### Control flow

| Feature | CFG | MLIR | Notes |
|---|---|---|---|
| `if-then-else` | Yes | Yes | `scf.if` in MLIR |
| `match` | Yes | No | Needs match compilation + pattern matching |
| `while` | Yes | No | Needs `scf.while` lowering |
| `for` | Yes | No | Needs `scf.for` lowering |
| `try-with` | Yes | No | Needs exception handling |
| `raise` | Yes | No | Needs exception handling |

### Functions

| Feature | CFG | MLIR | Notes |
|---|---|---|---|
| Top-level functions | Yes | Partial | External calls only |
| Local functions | Yes | No | Needs closure conversion |
| Currying | Yes | No | Needs closure representation |
| First-class functions | Yes | No | Needs closure representation |
| Recursive functions | Yes | No | Needs fixpoint handling |
| Tail call optimization | Yes | No | Future work |

### Data types

| Feature | CFG | MLIR | Notes |
|---|---|---|---|
| Integers (`int`, `int32`, `int64`, `nativeint`) | Yes | Yes | Tagged representation in MLIR |
| Floats | Yes | Yes | Untagged in MLIR |
| Characters | Yes | Yes | Tagged integer in MLIR |
| Booleans | Yes | Yes | Tagged integer in MLIR |
| Strings | Yes | Partial | Constants work, operations need runtime |
| Tuples | Yes | No | Needs struct allocation |
| Lists | Yes | No | Needs GC + allocation |
| Arrays | Yes | No | Needs GC + allocation |
| Records | Yes | No | Needs struct allocation |
| Variants | Yes | No | Needs tag + allocation |
| Options | Yes | No | Needs variant support |
| References | Yes | No | Needs mutable memory model |
| Unit | Yes | Yes | Tagged integer `1` |

### Type system

| Feature | CFG | MLIR | Notes |
|---|---|---|---|
| Hindley-Milner inference | Yes | Yes | Shared frontend |
| Parametric polymorphism | Yes | N/A | Runtime representation is uniform |
| Structural subtyping | Yes | N/A | Objects only |
| Row polymorphism | Yes | N/A | Objects only |
| GADTs | Yes | N/A | Type system feature |
| Extensible variants | Yes | N/A | Type system feature |
| First-class modules | Yes | N/A | Type system feature |
| Functors | Yes | N/A | Module system feature |

### Object system

| Feature | CFG | MLIR | Notes |
|---|---|---|---|
| Classes | Yes | No | Not yet in MLIR backend |
| Objects | Yes | No | Not yet in MLIR backend |
| Inheritance | Yes | No | Not yet in MLIR backend |
| Multiple inheritance | Yes | No | Not yet in MLIR backend |
| Binary methods | Yes | No | Not yet in MLIR backend |
| `self` and `super` | Yes | No | Not yet in MLIR backend |

### Module system

| Feature | CFG | MLIR | Notes |
|---|---|---|---|
| Structures | Yes | N/A | Compile-time only |
| Signatures | Yes | N/A | Compile-time only |
| Functors | Yes | N/A | Compile-time only |
| Include | Yes | N/A | Compile-time only |

### Standard library

| Feature | CFG | MLIR | Notes |
|---|---|---|---|
| `Stdlib` | Yes | No | No runtime linking yet |
| `Unix` | Yes | No | No runtime linking yet |
| `Sys` | Yes | No | No runtime linking yet |
| `Str` | Yes | No | No runtime linking yet |
| `Threads` | Yes | No | No runtime linking yet |
| `Bigarray` | Yes | No | No runtime linking yet |
| `Runtime_events` | Yes | No | No runtime linking yet |

### Runtime features

| Feature | CFG | MLIR | Notes |
|---|---|---|---|
| Garbage collector | Yes | No | Major milestone on roadmap |
| Exception handling | Yes | No | Needs unwind tables |
| Signal handling | Yes | No | Needs runtime |
| Finalizers | Yes | No | Needs GC |
| Weak pointers | Yes | No | Needs GC |
| Ephemerons | Yes | No | Needs GC |
| Custom blocks | Yes | No | Needs GC |
| Marshal | Yes | No | Needs runtime |
| Callbacks from C | Yes | Partial | External calls work |

## OCaml version compatibility

Moonshot is based on OxCaml 5.2.0+, which includes:

- OCaml 5 runtime (multicore, effect handlers, domains)
- OCaml 4 runtime (backward compatibility, being removed)
- Flambda 2 optimizer
- CFG backend
- Jane Street extensions (modes, layouts, uniqueness, etc.)

The MLIR backend currently does not depend on either runtime. It generates standalone object files with no runtime linkage.

## Next steps

- [Feature roadmap](roadmap.md) — what is planned for each version
- [MLIR backend overview](../mlir-backend/overview.md) — what the MLIR backend supports today
- [Backends](../architecture/backends.md) — comparing backend capabilities
