# Moonshot Documentation

Welcome to the Moonshot compiler documentation. This is the central source of truth for understanding, building, and extending the Moonshot compiler project.

## What is Moonshot?

Moonshot is an experimental compiler backend for OCaml that leverages [MLIR](https://mlir.llvm.org/) (Multi-Level Intermediate Representation) and [LLVM](https://llvm.org/) to compile OCaml source code through a modern, retargetable pipeline. It sits on top of [OxCaml](https://github.com/oxcaml/oxcaml), a performance-focused fork of OCaml maintained by Jane Street, which includes the Flambda 2 optimizer and the CFG backend.

The project focuses on building a production-quality path from OCaml's typed AST all the way to native object files via MLIR.

## Who should read this?

- **Compiler engineers** who want to understand or extend the backend
- **OCaml programmers** curious about the compilation pipeline
- **Researchers** interested in retargetable compiler backends for functional languages

## How to read this documentation

The docs are organized into four sections, following the [Divio documentation framework](https://documentation.divio.com/):

| Section | Purpose | Start here if you... |
|---|---|---|
| [Getting Started](getting-started/) | Task-oriented, step-by-step guides | ...want to install and run the compiler |
| [Architecture](architecture/) | Understanding-oriented, design context | ...want to understand how the pieces fit together |
| [MLIR Backend](mlir-backend/) | Reference and deep dives | ...are working on the MLIR or LLVM backend |
| [Language & Roadmap](language/) | What is supported and what is coming | ...want to know feature status |
| [Developer Guide](developer/) | How-to for contributors | ...want to build, test, or debug |
| [Reference](reference/) | Lookup tables, flags, glossary | ...need a quick fact check |

## Quick links

- [Build from source](getting-started/build-from-source.md) — Full build instructions
- [Compiler pipeline](architecture/compiler-pipeline.md) — How your code flows through the compiler
- [MLIR lowering pipeline](mlir-backend/pipeline.md) — Typedtree to LLVM IR in detail
- [Feature roadmap](language/roadmap.md) — What works today and what is planned
- [Contributing](developer/contributing.md) — How to send patches and run tests

## Status at a glance

| Component | Status | Notes |
|---|---|---|
| OxCaml base compiler | Stable | Based on OCaml 5.2.0, builds in ~10 min |
| Flambda 2 optimizer | Production | Enabled by default in `-O2` |
| CFG backend | Production | Default native backend |
| MLIR backend | Experimental | `-mlir-backend` flag, arithmetic + comparisons + extern calls working |
| LLVM backend | Experimental | Via CFG-to-LLVM path, `-fllvm` |
| `mlir_ocaml_bindings` | WIP | Partial C bindings, remaining work tracked |
| `ocaml_bindgen` | WIP | Binding generator not yet functional |

## Project repositories

| Repo | Role |
|---|---|
| `pointblank-club/moonshot` | This repo — the compiler |
| `pointblank-club/mlir_ocaml_bindings` | MLIR C API bindings for OCaml |
| `pointblank-club/ocaml_bindgen` | Auto-generates OCaml/ctypes bindings from C headers |

## Getting help

- Open an issue on the [moonshot GitHub repo](https://github.com/pointblank-club/moonshot)
- Check the [FAQ](appendix/faq.md) for common build and test problems
- Read the [debugging guide](developer/debugging.md) if tests fail

## License

The compiler is distributed under the same license as upstream OCaml (LGPL 2.1 with linking exception). The MLIR backend and related C++ lowering code are under the MIT license. See individual files for details.
