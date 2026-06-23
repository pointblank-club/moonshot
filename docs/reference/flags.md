# Compiler Flags Reference

This page lists the flags and options that are specific to Moonshot and OxCaml. For upstream OCaml flags, see the [OCaml manual](https://ocaml.org/manual/comp.html).

## OxCaml flags

### Backend selection

| Flag | Description | Default |
|---|---|---|
| `-classic-backend` | Use the classic Mach linear backend | off |
| `-mlir-backend` | Use the MLIR backend (experimental) | off |
| `-fllvm` | Use the LLVM backend via CFG (experimental) | off |

### CFG backend options

| Flag | Description | Default |
|---|---|---|
| `-regalloc` | Register allocator: `cfg` or `linear-scan` | `cfg` |
| `-regalloc-linscan-threshold` | Threshold for linear scan | `max_int` |
| `-regalloc-param` | Pass parameters to register allocator | `[]` |
| `-regalloc-validate` | Validate register allocation | on |
| `-vectorize` | Enable vectorization | off |
| `-vectorize-max-block-size` | Max block size for vectorization | 100 |
| `-cfg-peephole-optimize` | Enable CFG peephole optimizer | on |
| `-x86-peephole-optimize` | Enable x86-specific peephole optimizer | off |
| `-cfg-stack-check` | Enable stack checks | on |
| `-cfg-stack-threshold` | Stack check threshold | 16384 |
| `-cfg-eliminate-dead-trap-handlers` | Eliminate dead trap handlers | off |
| `-cfg-prologue-validate` | Validate prologue | on |
| `-cfg-prologue-shrink-wrap` | Enable prologue shrink-wrapping | on |
| `-cfg-prologue-shrink-wrap-threshold` | Threshold for shrink-wrapping | 16384 |
| `-cfg-merge-blocks` | Merge basic blocks | off |
| `-cfg-value-propagation` | Enable value propagation | on |
| `-cfg-value-propagation-float` | Propagate float values | off |
| `-cfg-value-propagation-flow` | Flow-sensitive value propagation | off |
| `-reorder-blocks-random` | Random block reordering seed | none |
| `-basic-block-sections` | Emit basic block sections | off |
| `-module-entry-functions-section` | Separate section for entry functions | off |

### Optimization

| Flag | Description | Default |
|---|---|---|
| `-Oclassic` | Use classic optimization mode | off |
| `-O2` | Enable Flambda 2 optimizations | on (in OxCaml) |
| `-O3` | Enable more aggressive optimizations | off |
| `-heap-reduction-threshold` | Heap reduction threshold | platform-dependent |
| `-dzero-alloc` | Dump zero-alloc checker info | off |
| `-disable-zero-alloc-checker` | Disable zero-alloc checker | off |
| `-disable-precise-zero-alloc-checker` | Disable precise zero-alloc checker | off |
| `-zero-alloc-checker-details-cutoff` | Detail cutoff | `At_most 20` |
| `-zero-alloc-checker-join` | Join strategy | `Keep_all` |

### Debugging

| Flag | Description | Default |
|---|---|---|
| `-dcfg` | Dump CFG | off |
| `-dcfg-invariants` | Dump CFG invariants | off |
| `-dvectorize` | Dump vectorization info | off |
| `-dasm-comments` | Emit assembly comments | off |

## MLIR backend flags

The MLIR backend is enabled with `-mlir-backend`. There are currently no additional flags specific to the MLIR backend, but future versions may add:

- `-mlir-dump-ir` — dump intermediate MLIR at each stage
- `-mlir-opt-level` — optimization level for MLIR passes
- `-mlir-target` — target triple for LLVM IR
- `-mlir-gpu` — enable GPU offloading

## Environment variables

| Variable | Description |
|---|---|
| `BINDGEN_EXE` | Path to `ocaml_bindgen` executable |
| `MLIR_ROOT` | Path to MLIR C headers (`/usr/lib/llvm-22/include/mlir-c`) |
| `PROJECT_ROOT` | Path to the `omlir` bindings tree |
| `PARK` | Name of the opam switch with `dune` and `menhir` for the build script |

## Next steps

- [Glossary](glossary.md) — definitions of terms used in this reference
- [Debugging](../developer/debugging.md) — what to do when flags do not work
- [MLIR backend overview](../mlir-backend/overview.md) — how the MLIR backend is triggered
