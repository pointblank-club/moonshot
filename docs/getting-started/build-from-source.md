# Build from Source

This guide is for developers who want to build the Moonshot compiler with the MLIR backend enabled. The build is more involved than a standard OCaml compiler because the MLIR backend introduces a bootstrap circularity.

> If you just want a quick install, see the [installation guide](installation.md). If you want the one-command build, run `bash scripts/build-mlir-backend.sh` and skip this page.

## What you need to clone

| Repository | When | Notes |
|---|---|---|
| `pointblank-club/moonshot` (this repo) | always | Branch with the MLIR backend |
| `pointblank-club/mlir_ocaml_bindings` | always | Provides `omlir` — the MLIR FFI bindings |
| `devalgupta404/ocaml-ctypes` (branch `oxcaml-0.24.0`) | always | Pulled by `opam pin`, no local clone needed |
| `pointblank-club/ocaml_bindgen` | only to regenerate bindings | See the [bindings guide](../mlir-backend/bindings.md) |

```bash
git clone https://github.com/pointblank-club/moonshot
cd moonshot
git submodule update --init --recursive
```

## System packages

### Debian / Ubuntu

```bash
sudo apt install \
  libmlir-22-dev llvm-22-dev mlir-22-tools \
  libffi-dev pkg-config cmake ninja-build \
  autoconf m4 build-essential opam rsync
```

> MLIR/LLVM must be version **22**. Paths are hardcoded against `/usr/lib/llvm-22/`.

### macOS

You will need LLVM 22 from Homebrew or built from source. The `apt` packages above do not apply; adapt the paths in `backend/mlir/mlirize.ml` if your LLVM install is elsewhere.

## Version pins (must match exactly)

| Component | Version | Why |
|---|---|---|
| OCaml bootstrap switch | `5.4.0` | Bootstrap source uses `Format.utf_8_scalar_width` (5.4-only). The compiler you *produce* reports `5.2.0+ox`. |
| `menhir` | exactly `20231231` | Newer menhir emits `MenhirLib.StaticVersion.require_20260209`, absent from OxCaml's vendored `CamlinternalMenhirLib`. Used only as a binary. |
| `ctypes` / `ctypes-foreign` | `0.24.0` + OxCaml patch | From `devalgupta404/ocaml-ctypes#oxcaml-0.24.0`: eta-expands four `Bigarray.kind` cases for the `@immutable` modality OxCaml's stdlib adds. |
| `omlir` | `~dev` (path pin) | Your local `mlir_ocaml_bindings` clone. |

## The bootstrap circularity

Moonshot's source `otherlibs/unix/dune` and `otherlibs/systhreads/byte/dune` originally defined libraries named `unix` and `threads`. The MLIR backend's `omlir` library depends on `ctypes-foreign`, which declares `requires "ctypes threads"`. The instant `omlir` enters the link closure, dune sees **two** libraries called `threads` (source-side and opam-side) and refuses to pick one.

The fix renames the source libraries to private names (`ocaml_unix_internal`, `ocaml_threads_byte_internal`) so that `(libraries unix)` and `(libraries threads)` in any in-tree consumer cleanly resolve to the opam-side libraries during the main-context build. The install rules still emit `unix/unix.cma` and `threads/threads.cma` under the public names, so externally there is no visible change.

A second consequence: a renamed library's archives embed their stub-archive name, so `unix.cma` references `-locaml_unix_internal_stubs`. The install rules must therefore install the stub `.a`/`.so` under both the internal name and the legacy name (`libunix_stubs.a` / `dllthreads_stubs.so`).

This circularity is why the build is a multi-phase dance.

## Manual build phases

### Phase 1: Pre-fix bootstrap

Create a vanilla `ocaml-base-compiler.5.4.0` switch. Revert the 8 fix-touched files to the pre-fix commit so `unix` resolves from the in-build stdlib. `make -s` completes everything except the expected `omlir` cmi-magic link. Assemble a consistent OxCaml `_install`.

### Phase 2: Target switch + flambda2 repo

Create a separate `--empty` target switch with the flambda2 repo. The `--empty` has no invariant, so `opam custom-install` does not try to recompile `ocaml.5.4.0` against the 5.2.0+ox compiler.

```bash
opam switch create <sw> --empty \
  --repositories=flambda2=git+https://github.com/ocaml-flambda/flambda2-opam.git,default
opam custom-install -n ocaml-variants.5.2.0+oxcaml
opam install ocaml.5.2.0
```

Fake-install + symlink the vanilla `dune`/`menhir` binaries (their sources do not compile against OxCaml). Then pin and install `ctypes`/`ctypes-foreign`/`omlir` at the correct magic.

### Phase 3: Post-fix rebuild

Restore the 8 files to HEAD, regenerate `duneconf/*.ws` (so the `OCAMLPATH`→opam line is emitted), clean `_build`, and run `make -s`. Re-assemble `_install` from the post-fix `_build` and re-`custom-install` so the switch stdlib matches the post-fix `runtime_stdlib`.

### Phase 4: Dialect + smoke test

```bash
make -s _install
make mlir-dialect   # builds ocaml-mlir-opt via cmake/ninja
make runtest-mlirize
```

## Day-to-day build loop

Once the full build is done, incremental work is fast:

```bash
# Quick build check (recommended for development)
make -s boot-compiler

# Full build
make -s

# Install to _install/
make -s install

# Format before committing
make -s fmt

# Run all tests
make -s test

# Run only the MLIR backend tests
make -s runtest-mlirize

# Run a specific MLIR test case using Dune
opam exec -- dune runtest duneconf/boot.ws oxcaml/tests/backend/mlirize --filter test_arith
```

## Common pitfalls

These are the failure modes observed during full clean-from-scratch runs.

### `opam custom-install` aborts with "OCaml version mismatch: 5.2.0, expected 5.4.0"

The target switch was created with a real `ocaml-base-compiler.5.4.0` instead of `--empty`. Recreate it with:

```bash
opam switch create <sw> --empty \
  --repositories=flambda2=git+https://github.com/ocaml-flambda/flambda2-opam.git,default
```

### `opam custom-install` recompiles `dune` and fails on "with constraint ... 'a : any separable"

You omitted `-n` (`--no-recompilations`). Re-custom-install on a populated switch otherwise rebuilds every `[uses ocaml]` package, including `dune 3.22.2`, which does not compile against OxCaml.

### `opam custom-install -n` rolled back and the switch has no stdlib

Expected on the second custom-install. Run it again (the script loops up to 3 times checking `stdlib.cmi` magic).

### `Library "unix" not found` (ocamldoc / ocaml-jit) after restoring post-fix source

`duneconf/main.ws` is stale. `make` won't regenerate an existing `.ws`. Fix:

```bash
rm -f duneconf/*.ws
make -s
```

### `make inconsistent assumptions over interface "CamlinternalFormatBasics"`

Generation skew between opam-`unix` and `runtime_stdlib`. Re-assemble `_install` from the *post-fix* `_build` and re-`custom-install` so they match.

### `cannot find -locaml_unix_internal_stubs`

The stub-name fix is not committed. It must be on HEAD before the clean run.

### `menhir`/`require_20260209` mismatch

Use `menhir.20231231` exactly. Fake-install + symlink the vanilla binary; never recompile it against OxCaml.

## Next steps

- [Contributing](../developer/contributing.md) — how to write code and tests
- [Debugging](../developer/debugging.md) — what to do when things break
- [MLIR backend overview](../mlir-backend/overview.md) — how the backend works
