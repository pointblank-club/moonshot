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

make install
```

For building just the compiler,
```bash
make boot-compiler
```

Use bear for clangd support in `backend/mlir/lowering`.
