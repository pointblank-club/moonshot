# Installation

This guide covers installing the Moonshot compiler and its dependencies. There are two ways to get a working compiler:

1. **Pre-built switch via OPAM** — fastest, recommended for users who just want to compile OCaml code
2. **Build from source** — required for MLIR backend development

## Prerequisites

### All platforms

- [OPAM](https://opam.ocaml.org/) (2.1 or later)
- `autoconf`, `m4`, `make`
- A C++ toolchain (GCC 7.4+, Clang 5.0+, or MSVC 2019+)
- `rsync` (used by the build system)

### For MLIR backend development (Debian/Ubuntu)

MLIR/LLVM must be version **22**. Paths are hardcoded against `/usr/lib/llvm-22/`.

```bash
sudo apt install \
  libmlir-22-dev llvm-22-dev mlir-22-tools \
  libffi-dev pkg-config cmake ninja-build \
  autoconf m4 build-essential opam rsync
```

### Supported platforms

| Platform | Architecture | Backend support |
|---|---|---|
| Linux | x86-64 | Full (CFG, MLIR experimental) |
| Linux | arm64 | Full (CFG, MLIR experimental) |
| macOS | arm64 | Full (CFG, MLIR experimental) |
| macOS | x86 | Best-effort (CFG) |

Windows is not currently supported for the MLIR backend.

## Option 1: Quick install via OPAM (no MLIR backend)

If you do not need the MLIR backend and just want the OxCaml compiler:

```bash
opam switch create oxcaml-dev --empty
opam pin add -ny git+https://github.com/oxcaml/oxcaml
opam switch set-invariant -y --packages oxcaml-dev
eval $(opam env)
```

You can check that an existing switch is up to date:

```bash
opam upgrade oxcaml-dev
```

## Option 2: Build from source (full MLIR backend)

The MLIR backend has a bootstrap circularity that requires a multi-phase build. The easiest way is to use the provided script:

```bash
git clone https://github.com/pointblank-club/moonshot
cd moonshot
git submodule update --init --recursive
bash scripts/build-mlir-backend.sh
```

This script takes 2–3 hours and needs at least 8 GB of free disk space. It resolves the bootstrap loop automatically.

For a manual step-by-step breakdown (useful when debugging), see [Build from source](build-from-source.md).

## Verify the installation

After either installation path:

```bash
# Check the compiler version
ocamlopt --version
# Expected: 5.2.0+ox

# For MLIR backend, check that mlir-opt is available
/usr/lib/llvm-22/bin/mlir-opt --version
```

## Next steps

- [Quickstart](quickstart.md) — compile your first program
- [Build from source](build-from-source.md) — full manual build for developers
- [Developer guide](../developer/contributing.md) — how to run tests and send patches
