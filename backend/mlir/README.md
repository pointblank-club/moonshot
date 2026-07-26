# MLIR Backend

## Building

This project requires MLIR and LLVM built from https://github.com/pointblank-club/llvm-project/tree/ocaml-cc.

Build llvm-project as per the llvm [Getting Started](https://llvm.org/docs/GettingStarted.html#getting-the-source-code-and-building-llvm) guide.

Building the moonshot compiler requires the following steps:

```bash
git clone https://github.com/pointblank-club/moonshot
git submodule update --init --recursive

# opam switch
opam switch create . 5.4.1

autoconf

# If using a custom LLVM/MLIR build:
# ./configure --prefix=/path/to/install/dir --with-llvm-prefix=/path/to/llvm/build

make install
```

For building just the compiler,
```bash
make boot-compiler
```

## Testing

To run mlir specific tests, run
```bash
make runtest-mlirize
```

To promote tests, run
```bash
make runtest-mlirize PROMOTE=1
```

Use bear for clangd support in `backend/mlir/lowering`.
