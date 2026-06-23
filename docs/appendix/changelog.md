# Changelog

This file tracks notable changes to the Moonshot compiler and documentation.

## Format

Each entry has a date, a category, and a description. Categories are:

- **Language** — new OCaml language features supported
- **Backend** — changes to the MLIR, LLVM, or CFG backends
- **Tooling** — build system, bindings, tests, etc.
- **Docs** — documentation changes

## Unreleased

### Backend

- Added MLIR backend with custom `ocaml` dialect
- Added lowering passes: `ocaml` → `arith` → `llvm`
- Added support for integer and string constants
- Added support for integer and float arithmetic
- Added support for comparisons (int, float, char, bool)
- Added support for boolean operations (`not`, `&&`, `||`)
- Added support for external function calls
- Added C++ custom dialect implementation (`backend/mlir/lowering/`)

### Tooling

- Added `make runtest-mlirize` test alias
- Added `ppx_expect` tests for MLIR backend
- Added `test_empty.ml`, `test_constants.ml`, `test_arith.ml`, `test_extern_call.ml`
- Added `scripts/build-mlir-backend.sh` for full bootstrap build

### Docs

- Created `docs/` directory with comprehensive documentation
- Added getting started guides (installation, quickstart, build from source)
- Added architecture documentation (overview, compiler pipeline, IRs, backends)
- Added MLIR backend documentation (overview, pipeline, dialects, lowering, bindings)
- Added language documentation (features, roadmap)
- Added developer documentation (contributing, testing, debugging)
- Added reference documentation (flags, glossary)
- Added appendix (FAQ, Flambda 2 encyclopedia)

## Next release (planned)

### Language

- References (`ref`, `!`, `:=`)
- Tuples
- Records
- Basic pattern matching

### Backend

- GC integration (minimal allocation)
- `print_endline` support
- String operations

### Tooling

- Single-command build (no bootstrap circularity)
- CI on GitHub Actions

## How to update this changelog

When you make a change that should be noted:

1. Add an entry to the **Unreleased** section under the appropriate category
2. Write a concise description of what changed and why
3. If the change is a fix, reference the issue number if applicable

When a release is cut:

1. Rename the **Unreleased** section to the version number and date
2. Create a new empty **Unreleased** section at the top
3. Tag the release in git

## Next steps

- [Feature roadmap](../language/roadmap.md) — what is coming next
- [Contributing](../developer/contributing.md) — how to send a patch
