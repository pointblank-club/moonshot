# Feature Roadmap

This roadmap tracks the planned features for the Moonshot compiler. It is organized by version and covers the language, the MLIR backend, and the supporting tooling.

## Version 0.1 (current)

**Theme:** Proof of concept — compile basic arithmetic to native code.

### Language

- [x] Integer constants
- [x] String constants
- [x] Integer arithmetic (`+`, `-`, `*`, `/`)
- [x] Float arithmetic (`+`, `-`, `*`, `/`)
- [x] Integer comparisons (`=`, `<`, `>`, `<=`, `>=`, `==`, `!=`)
- [x] Float comparisons
- [x] Boolean operations (`not`, `&&`, `||`)
- [x] Let bindings
- [x] If-then-else
- [x] External function calls

### Backend

- [x] Typedtree → custom MLIR dialect
- [x] Custom MLIR → standard MLIR lowering
- [x] Standard MLIR → LLVM IR
- [x] LLVM IR → object file
- [x] In-tree expect tests
- [x] End-to-end external call execution

### Tooling

- [x] Partial MLIR C bindings for OCaml
- [x] Hand-written dialect wrappers (`Func`, `Arith`, `SCF`, `LLVM`)
- [x] Custom `ocaml` dialect in C++
- [x] Custom lowering pass (`--convert-ocaml-to-arith`)

## Version 0.2 (next milestone)

**Theme:** Hello world with GC — compile a program that allocates and prints.

### Language

- [ ] References (`ref`, `!`, `:=`)
- [ ] Tuples (fixed-size, heterogeneous)
- [ ] Records (labeled fields, optional mutable)
- [ ] Basic pattern matching (int, tuple, record)

### Backend

- [ ] GC integration (minimal alloc + collection)
- [ ] `print_endline` works
- [ ] `printf` works
- [ ] String operations (concatenation, length)

### Runtime

- [ ] Link OCaml runtime with MLIR-generated object files
- [ ] Initialize GC roots
- [ ] Frame tables for GC
- [ ] Data segment boundaries

## Version 1.0.0

**Theme:** A usable subset of OCaml for systems programming.

### Core language

- [ ] Arithmetic — `+`, `-`, `*`, `/`
- [ ] Comparison — `=`, `<`, `>`, `==`, `!=`
- [ ] Boolean — `not`, `||`, `&&`
- [ ] References — creating and modifying pointers (`ref`, `!`, `:=`)
- [ ] Lists — singly linked immutable (`[1; 2; 3]`)
- [ ] Arrays — fixed-size mutable (`[| 1; 2; 3 |]`)
- [ ] Records — labeled data fields, with optional mutable annotations
- [ ] Variants — algebraic data types (sum types) with pattern matching
- [ ] Tuples — fixed-size heterogeneous collections (`(1, "a")`)

### Type system

- [ ] Hindley-Milner type inference
- [ ] Parametric polymorphism — one general code that works on all types
- [ ] First-class functions — functions treated as any other variable
- [ ] Pattern matching — control structure to inspect and deconstruct data

### Module system

- [ ] Structures, signatures, and functors (functions at module level)

### Object system

- [ ] Classes and objects
- [ ] Structural subtyping
- [ ] Multiple inheritance
- [ ] Binary methods
- [ ] Self and super keywords

### Standard library

- [ ] Strings module
- [ ] Queue module
- [ ] Stack module
- [ ] Map module
- [ ] Set module
- [ ] Unix module
- [ ] Sys module

### Runtime

- [ ] Garbage collector — full integration
- [ ] Exception handling — `try`, `raise`, `match` with exception patterns

## Version 1.1

**Theme:** Performance and optimization.

### Backend

- [ ] MLIR optimization passes on the custom dialect
- [ ] Inlining
- [ ] Constant folding
- [ ] Dead code elimination
- [ ] Loop unrolling
- [ ] Vectorization via MLIR vector dialect

### Runtime

- [ ] Domain support (OCaml 5 multicore)
- [ ] Effect handlers
- [ ] Custom block allocators

## Version 2.0

**Theme:** Advanced features and ecosystem integration.

### Backend

- [ ] GPU offloading via MLIR GPU dialect
- [ ] JIT compilation via LLVM ORC
- [ ] Cross-compilation support
- [ ] Profile-guided optimization

### Language

- [ ] Full Jane Street extensions (modes, layouts, uniqueness, etc.)
- [ ] Full Flambda 2 integration (run Flambda 2 before MLIR)
- [ ] Full OCaml 5 runtime support

## Tooling roadmap

### `mlir_ocaml_bindings`

- [ ] Complete C bindings for MLIR C API
- [ ] TableGen-generated dialect wrappers
- [ ] Documentation for all wrapper modules

### `ocaml_bindgen`

- [ ] Generate bindings from C headers automatically
- [ ] Support for structs, unions, enums
- [ ] Support for function pointers
- [ ] Support for callbacks

### Moonshot compiler

- [ ] Single-command build (no bootstrap circularity)
- [ ] OPAM package
- [ ] CI on GitHub Actions
- [ ] Benchmark suite
- [ ] Documentation website

## Milestone table

| Milestone | Target | Definition of done |
|---|---|---|
| GC + hello world | Version 0.2 | `print_endline "Hello, World!"` compiles and runs via MLIR backend |
| Usable subset | Version 1.0 | Can write small CLI tools in a subset of OCaml |
| Performance | Version 1.1 | MLIR backend beats CFG backend on some benchmarks |
| Advanced | Version 2.0 | Full OCaml + GPU + JIT |

## How to update this roadmap

This roadmap is a living document. To propose a change:

1. Open an issue on the moonshot repo with the `roadmap` label
2. Describe the feature, why it is needed, and the proposed version
3. If accepted, the maintainers will update this file

When a feature is completed:

1. Mark the checkbox as done in the relevant version
2. Update the [language features](features.md) page with backend support details
3. Add a note to the [changelog](../appendix/changelog.md)

## Next steps

- [Language features](features.md) — what is supported today
- [Contributing](../developer/contributing.md) — how to work on a roadmap item
- [MLIR backend overview](../mlir-backend/overview.md) — current backend status
