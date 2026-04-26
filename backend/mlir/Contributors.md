# OxCaml MLIR Backend

Experimental `-mlir-backend` pipeline. Compiles OCaml source → MLIR
(via the `arith` / `func` / `scf` dialects) → LLVM IR → object file.

## Pipeline at a glance

```
OCaml source
   |
   |  optcomp/optcompile.ml fires Compiler_hooks.Mlirize when -mlir-backend is set
   v
Typedtree.implementation
   |
   |  backend/mlir/translate.ml: walks structure_items, recognises
   |    comparison / arithmetic primitives, let-bindings, if-then-else
   v
OxCaml-built MLIR module (arith.cmpi / arith.cmpf / arith.add* / scf.if / func.func)
   |
   |  shell out: mlir-opt --convert-scf-to-cf --convert-cf-to-llvm
   |             --convert-arith-to-llvm --convert-func-to-llvm
   |             --reconcile-unrealized-casts
   v
LLVM dialect
   |
   |  shell out: mlir-translate --mlir-to-llvmir
   v
LLVM IR (.ll)
   |
   |  shell out: clang -c -x ir -
   v
Object file (.o)
```

`mlirize.ml` orchestrates the shell-outs in-process; the only thing
hard-coded is `/usr/lib/llvm-22/bin` (matching the `apt install
llvm-22-dev` layout).

## Layout

```
backend/mlir/
  mlirize.{ml,mli}              entry point, hook registration, lowering shell-outs
  translate.{ml,mli}            Typedtree -> MLIR module
  Contributors.md               this file

external/omlir/   vendored MLIR OCaml bindings (was a submodule, now tracked)
  mlir_bindings/*.ml            AUTO-GENERATED ctypes stubs.  Never edit by hand.
  mlir/ir/*.ml                  HAND-WRITTEN low-level wrappers (Type, Value, Operation, ...)
  mlir/dialects/*.ml            HAND-WRITTEN dialect wrappers (Func, Arith)
  mlir/omlir.ml   library main module (re-exports Mlir_ir + dialects)

oxcaml/tests/backend/mlirize/   dune alias `runtest-mlirize`
  empty.{ml,expected}           empty-module sanity test
  comparisons.{ml,expected}     all 35 comparison patterns end-to-end
```

## Working with the bindings (the part most contributors will touch)

The bindings tree has **two layers**, each with a different rule:

### Layer 1: `mlir_bindings/*.ml` — auto-generated, do not edit

These are direct ctypes stubs of MLIR's C API
(`mlirOperationStateGet`, `mlirIntegerTypeGet`, etc.). They're produced
by the `bindgen` tool (`pointblank-club/ocaml_bindgen`) reading
the MLIR-C headers at `/usr/lib/llvm-22/include/mlir-c/*.h`. **Any edits here will be lost
on the next regen.**

To add a new C function from a header that isn't yet covered, edit the
`(rule (alias regenerate) ...)` block in
`external/omlir/mlir_bindings/dune` to point at the
relevant header, then run:

```bash
dune build @regenerate
```

This is for **functions** that don't exist in the `mlir_bindings/`
namespace yet. If they're already there, skip directly to layer 2.

### Layer 2: `mlir/ir/*.ml` and `mlir/dialects/*.ml` — hand-written wrappers

These layers exist on top of the auto-generated stubs because there
are three things bindgen cannot do:

1. **Lifetime / GC fixes.**  e.g. `mlir/ir/stringRef.ml` keeps a `_buf`
   field alive so OCaml's GC doesn't free the C buffer while MLIR is
   still pointing into it.  `Operation.State` retains the
   `StringRef.t` for the same reason: MLIR keeps the op-name pointer
   between `State.get` and `Operation.create`. These constraints
   aren't in the C headers; they're documented in MLIR's docs and
   verified by getting it wrong once (we did — symptom is corrupt op
   names like `"3\BA\9C}]d\00\00nstant"`).

2. **Ergonomic OCaml shape.** Records with named fields, optional
   args, modules per concept, predicate enums (`Arith.Predicate.Eq`
   instead of raw integers).

3. **Cross-cutting helpers** like `Operation.State.add_operands`
   (taking an OCaml list, allocating a CArray) — these patterns
   could in principle be auto-generated from a heuristic but aren't
   today.

#### How to add a new MLIR op (worked example)

Suppose you want to add `arith.subf` (float subtraction) to the
backend.  Steps:

1. **Check the raw bindings.** Does `mlir_bindings/ir.ml` already
   expose `mlirOperationStateGet` etc.? Yes — the generic op state
   API works for any op. You don't need to regen for `arith.subf`
   specifically because it's a generic op built by name.

2. **Add a wrapper.** In
   `external/omlir/mlir/dialects/arith.ml`, add:

   ```ocaml
   module Subf = struct
     let create ~loc ~lhs ~rhs ~ty =
       binop ~op_name:"arith.subf" ~loc ~lhs ~rhs ~ty
   end
   ```

   The `binop` helper at the bottom of `arith.ml` handles
   two-operand same-type ops in 5 lines. For ops with different
   shape (unary, type-changing, with attributes), look at how
   `Constant.create` or `CmpI.create` is built.

3. **Wire the frontend.** In `backend/mlir/translate.ml`, extend
   `arith_op_of_prim` to recognise the OCaml primitive name, e.g.:

   ```ocaml
   let arith_op_of_prim = function
     | "%subfloat" -> Some "arith.subf"
     ...
   ```

   The recursive `translate_expr` automatically uses this when it
   sees a `Texp_apply` whose function is the `%subfloat` primitive.

4. **Test.** Add a function to
   `oxcaml/tests/backend/mlirize/comparisons.ml` (or a new test
   file) using your new primitive. Regenerate the expected with:

   ```bash
   _build/_bootinstall/bin/ocamlopt.opt -nostdlib -nopervasives \
     -mlir-backend -c oxcaml/tests/backend/mlirize/<name>.ml \
     > oxcaml/tests/backend/mlirize/<name>.expected 2>&1
   ```

#### How to add a wrapper that needs a C function not in `mlir_bindings/`

If you hit a name like `mlirArithCreateFooOp` that doesn't exist in
`mlir_bindings/ir.ml` or `mlir_bindings/builtinTypes.ml`, you need
the auto-generated layer to grow first:

1. Find which header declares it
   (`/usr/lib/llvm-22/include/mlir-c/...`).
2. Add a line to the `regenerate` rule in
   `external/omlir/mlir_bindings/dune`:

   ```scheme
   (run %{env:BINDGEN_EXE=} %{env:MLIR_ROOT=}/Dialect/Arith.h
        %{env:PROJECT_ROOT=}/mlir_bindings/arith.ml
        --import Support,Ir)
   ```

3. `dune build @regenerate` produces the new
   `mlir_bindings/arith.ml`. Now you can wrap its functions in
   layer 2 (`mlir/dialects/arith.ml`).

The bindgen tool lives in a separate repo (`pointblank-club/ocaml_bindgen`).
Clone it somewhere convenient, build it (`dune build`), and point
`BINDGEN_EXE` at the resulting `bindgen.exe`.  The regen rule also
needs `MLIR_ROOT` (path to MLIR-C headers, typically
`/usr/lib/llvm-22/include/mlir-c`) and `PROJECT_ROOT` (the bindings
tree, i.e. `external/omlir/`).

### Layer 3 (optional, future): `mlir-ocaml-tblgen`

The bindings repo also ships a TableGen-based generator at
`mlir_tablegen/`. With `-gen-ocaml-bindings` it can read MLIR's `.td`
files (e.g. `ArithOps.td`) and produce dialect wrappers automatically.
If the dialect wrappers under `mlir/dialects/` start to grow, look at
how `external/omlir/test/dune` (in the standalone
bindings repo) wires the tablegen rule, then add an analogous rule
under `mlir/dialects/dune` here. A correctly wired `arith.ml` would
become regenerated output instead of a hand-written file.

## Frontend (`backend/mlir/translate.ml`)

Walks `Typedtree.implementation` and emits MLIR ops. Recognises:

- 8 comparison primitives (`%equal`, `%notequal`, `%lessthan`,
  `%lessequal`, `%greaterthan`, `%greaterequal`, `%eq`, `%noteq`)
  on int/int32/int64/nativeint/bool/char/float.
- 9 arithmetic primitives (`%addint` etc., `%addfloat` etc.).
- `Texp_let` for local bindings.
- `Texp_ifthenelse` (lowers to `scf.if`).
- Qualified compare names like `Stdlib__Int.equal` via path matching.

What it explicitly rejects (with clear error messages):

- Polymorphic / structural compare on tuples, records, strings.
  Needs runtime call to `caml_equal` and OCaml-tagged value ABI;
  out of scope until we sort out runtime linking.
- Arbitrary `match`, `let rec`, function literals as values, etc.
  These are general expression-compilation features beyond the
  comparison/arithmetic slice.

## Required system tools

- `/usr/lib/llvm-22/bin/{mlir-opt,mlir-translate,clang}` — install
  via `apt install llvm-22-dev mlir-22-dev` on Debian/Ubuntu.

## Build & test

```bash
# Activate an opam switch with OCaml 5.4 + ctypes + ctypes-foreign +
# integers + menhir.20231231 installed (matching the OxCaml
# bootstrap requirements).

# Build the boot compiler (this is the one that supports -mlir-backend)
make -s boot-compiler

# Run a single .ml through the pipeline
_build/_bootinstall/bin/ocamlopt.opt -nostdlib -nopervasives \
  -mlir-backend -c <file>.ml

# Run the in-tree tests
make -s runtest-mlirize
```

The `runtest-mlirize` target invokes the boot compiler directly (not
the dune `@runtest-mlirize` alias) because the production `ocamlopt`
currently no-ops on `-mlir-backend` — see *Known limitations* below.
The dune alias rules in `oxcaml/tests/backend/mlirize/dune` remain in
place for the day production gets the bindings; until then they're
inert.

## Known limitations

- **`-mlir-backend` only works in `boot_ocamlopt`**, not in the
  installed `ocamlopt.opt`. Reason: opam's `ctypes.cmi` has the
  system OCaml's magic (`Caml1999I036`) while moonshot's stdlib
  uses `Caml1999I577`, so the bindings can't be linked into the
  main-context compiler. Fix path: build ctypes against moonshot's
  stdlib (vendor ctypes source or pin its opam build to moonshot's
  compiler).
- Therefore the `runtest-mlirize` Makefile target invokes the boot
  compiler directly (the production compiler would silently no-op
  on `-mlir-backend`).  The dune alias `@runtest-mlirize` exists
  but is inert until production gets the bindings.
