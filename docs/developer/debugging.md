# Debugging

This guide helps you diagnose and fix problems when building or testing the Moonshot compiler.

## Build failures

### `autoconf` fails

If `autoconf` fails because the version is too old, try `autoconf27` instead.

### `configure` fails

Run `./configure` with verbose output:

```bash
./configure --prefix=/path/to/install 2>&1 | tee configure.log
```

Common causes:

- Missing `libffi-dev` or `pkg-config`
- Wrong LLVM version (must be 22)
- Missing `mlir-22-dev` on Debian/Ubuntu

### `make -s boot-compiler` fails

Look at the error message. If it is a compilation error in OCaml code, the file and line number are usually clear.

If it is a link error:

- Check that `libffi` is installed
- Check that the `omlir` library is in the opam switch
- Check that `unix` and `threads` resolve correctly (see the [build guide](../getting-started/build-from-source.md))

### `make -s test` fails

If the build succeeds but tests fail, the issue is usually:

1. A test expects output that your change modified
2. A runtime mismatch (e.g., the switch stdlib differs from the build stdlib)
3. A missing expected file

### Inconsistent assumptions over interface

```
make inconsistent assumptions over interface CamlinternalFormatBasics
```

This means two parts of the build were compiled against different versions of the stdlib. Fix:

```bash
make -s install
opam custom-install -n ocaml-variants.5.2.0+oxcaml
```

Or do a clean rebuild.

## Test failures

### MLIR backend tests fail

Run the failing tests in isolation:

```bash
# Run all MLIR backend tests
make -s runtest-mlirize

# Or run a specific test case using Dune filter
opam exec -- dune runtest duneconf/boot.ws oxcaml/tests/backend/mlirize --filter <test_name>
```

Look at the diff. There are three stages:

1. **Custom MLIR** — if this changed, your frontend emission is different
2. **Standard MLIR** — if this changed, your lowering pass is different
3. **LLVM IR** — if this changed, the final IR is different

If the change is expected (e.g., you added a new op), promote the expected output:

```bash
make -s runtest-mlirize PROMOTE=1
```

### Segmentation fault in test

If a test segfaults, it usually means:

- The generated LLVM IR is invalid
- A C helper function has the wrong signature
- The runtime is not initialized

Run the test with `lldb` or `gdb`:

```bash
lldb ./_build/default/oxcaml/tests/backend/mlirize/test_arith.exe
run
cont
bt
```

### Wrong output in `verify_stdout`

If the program runs but produces wrong output, check:

- The tagged integer representation (did you forget to untag or retag?)
- The external function signature (did you pass an `i64` where a pointer is expected?)
- The string header (did you skip the correct number of bytes?)

## Inspecting generated code

### View the custom MLIR

```bash
_build/_bootinstall/bin/ocamlopt.opt -nostdlib -nopervasives \
  -mlir-backend -c foo.ml
```

### View the standard MLIR

```bash
ocamlopt -mlir-backend -c foo.ml > custom.mlir
/usr/lib/llvm-22/bin/mlir-opt \
  --convert-scf-to-cf \
  --convert-cf-to-llvm \
  --convert-arith-to-llvm \
  --convert-func-to-llvm \
  --reconcile-unrealized-casts \
  custom.mlir > standard.mlir
cat standard.mlir
```

### View the LLVM IR

```bash
/usr/lib/llvm-22/bin/mlir-translate --mlir-to-llvmir standard.mlir > output.ll
cat output.ll
```

### Verify LLVM IR with `opt`

```bash
/usr/lib/llvm-22/bin/opt -verify output.ll
```

This checks that the LLVM IR is well-formed.

### Disassemble the object file

```bash
objdump -d foo.o
```

## Common error messages

### `unknown option -mlir-backend`

The MLIR backend is not enabled in your build. You need to build from source with the MLIR backend enabled.

### `cannot find -locaml_unix_internal_stubs`

The stub-name fix is not applied. See the [build guide](../getting-started/build-from-source.md) for the background and fix.

### `Library "unix" not found`

`duneconf/main.ws` is stale. Regenerate it:

```bash
rm -f duneconf/*.ws
make -s
```

### `menhir` version mismatch

Use exactly `menhir.20231231`. Newer versions are incompatible with OxCaml's vendored `CamlinternalMenhirLib`.

### `opam custom-install` aborts

See the [build guide](../getting-started/build-from-source.md) for the full list of common pitfalls and fixes.

## Getting more help

If you are stuck:

1. Read the error message carefully. It usually contains the file and line number.
2. Search the codebase for the error string to find where it is raised.
3. Check the [FAQ](../appendix/faq.md) for known issues.
4. Open an issue on GitHub with the full error output and your platform details.

## Next steps

- [Testing](testing.md) — how to run and write tests
- [Contributing](contributing.md) — how to send a patch
- [Build from source](../getting-started/build-from-source.md) — detailed build instructions
