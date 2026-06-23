# Testing

This page explains how the Moonshot test suite works and how to run it.

## Test suite structure

The tests are split into two directories:

| Directory | Purpose | Backend |
|---|---|---|
| `testsuite/tests/` | Upstream OCaml tests | All backends |
| `oxcaml/tests/` | OxCaml-specific tests | CFG, LLVM, MLIR |
| `oxcaml/testsuite/` | OxCaml test suite infrastructure | All |

### MLIR backend tests

Located in `oxcaml/tests/backend/mlirize/`.

| Test | What it covers |
|---|---|
| `test_empty.ml` | Empty module compilation |
| `test_constants.ml` | Integer and string constants |
| `test_arith.ml` | Integer and float arithmetic |
| `test_extern_call.ml` | External C function calls |

These tests use the `ppx_expect` framework. Each test compiles OCaml code through the MLIR backend and checks the output at four stages:

1. `verify_mlir` — the custom `ocaml` dialect
2. `verify_std_mlir` — the standard MLIR after lowering
3. `verify_llvm` — the LLVM IR text
4. `verify_stdout` — the program output (for tests that run)

## Running tests

### Full test suite

```bash
make -s test
```

This runs all upstream and OxCaml tests. It takes several minutes.

### Running MLIR Backend Tests

To run all MLIR backend tests:

```bash
make -s runtest-mlirize
```

To run a specific MLIR backend test case using Dune filter:

```bash
opam exec -- dune runtest duneconf/boot.ws oxcaml/tests/backend/mlirize --filter <test_name>
```

To promote/update the expected output for MLIR backend tests:

```bash
make -s runtest-mlirize PROMOTE=1
```

### Running Upstream Compiler Tests

To run a single upstream compiler test (relative to the `testsuite/tests/` directory):

```bash
make -s test-one TEST=typing-gadts/test.ml
```

To run all tests in an upstream test directory:

```bash
make -s test-one DIR=typing-gadts
```

To promote/update the expected output for a single upstream test:

```bash
make -s promote-one TEST=typing-gadts/test.ml
```

## Test formats

### `ppx_expect` tests

The MLIR backend tests use `ppx_expect`. The test file contains OCaml code with `[%expect ...]` blocks. The compiler output is captured and compared against the expected string.

Example from `test_arith.ml`:

```ocaml
verify_mlir t;
[%expect
  {|
  ocaml.module @Arith {
    ocaml.entry {
      %0 = ocaml.int 1 : !ocaml.int
      %1 = ocaml.int 2 : !ocaml.int
      %2 = ocaml.int 3 : !ocaml.int
      %3 = ocaml.binop "*" %1, %2 : !ocaml.int, !ocaml.int -> !ocaml.int
      %4 = ocaml.binop "+" %0, %3 : !ocaml.int, !ocaml.int -> !ocaml.int
    }
  }
  |}];
```

### Inline tests

Some tests are inline in the source code using `let%test_unit` or `let%expect_test`. These are collected by dune and run with `dune runtest`.

### Regression tests

The upstream `testsuite/tests/` directory contains thousands of regression tests organized by topic:

- `testsuite/tests/typing-*` — type checker tests
- `testsuite/tests/basic-*` — basic language tests
- `testsuite/tests/lib-*` — standard library tests
- `testsuite/tests/backend-*` — backend tests

## Writing a new test

### For the MLIR backend

1. Create a new file in `oxcaml/tests/backend/mlirize/` named `test_<feature>.ml`
2. Use the `Helpers` module:

```ocaml
open Helpers

let%expect_test "my feature" =
  let t =
    test_compile ~name:"my_feature"
      ~code:
        "\n\
        \    let x = 42\n\
        \  "
  in
  verify_mlir t;
  [%expect {| ... |}];
  verify_std_mlir t;
  [%expect {| ... |}];
  verify_llvm t;
  [%expect {| ... |}]
```

3. Run the test:

```bash
make -s runtest-mlirize
```

4. If the output is correct, promote it:

```bash
make -s runtest-mlirize PROMOTE=1
```

### For the compiler frontend

If you are adding a language feature or modifying the type checker, add a test in `testsuite/tests/`:

```bash
# Create test directory
mkdir testsuite/tests/my-feature

# Create test file
cat > testsuite/tests/my-feature/test.ml << 'EOF'
(* TEST
   * expect
*)

let x = 42
[%%expect{|
val x : int = 42
|}]
EOF
```

Run it:

```bash
make -s test-one TEST=my-feature/test.ml
```

## Continuous integration

The project does not currently have a public CI setup. The plan is to add GitHub Actions that run:

```bash
make -s boot-compiler
make -s test
make -s runtest-mlirize
```

on Ubuntu with LLVM 22.

## Debugging test failures

See the [debugging guide](debugging.md).

## Next steps

- [Debugging](debugging.md) — what to do when a test fails
- [Contributing](contributing.md) — how to send a patch
- [MLIR backend overview](../mlir-backend/overview.md) — how the backend tests work
