# MLIR Backend

## Building

This project is tested with llvm 22 only. Mlir has to be built with the same version of llvm.

```bash
git clone https://github.com/pointblank-club/moonshot
git submodule update --init --recursive

# opam switch
opam switch create . 5.4.1

autoconf
./configure --prefix=/path/to/install/dir

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
