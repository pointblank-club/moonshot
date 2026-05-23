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

## Building locally — full setup for new contributors

> The MLIR-enabled compiler does **not** build with a plain
> `opam switch ... ; ./configure ; make -s`. It has an inherent bootstrap
> circularity (explained at the end of this section). The build is a
> multi-phase dance; it is scripted at **`scripts/build-mlir-backend.sh`**.
> Run that one command and skip to *Build & test*. The manual breakdown
> below documents what the script does and why, for when something needs
> debugging.

### What you need to clone

| Repo | When | Notes |
|---|---|---|
| `pointblank-club/moonshot` (this repo) | always | branch with the MLIR backend (`fix/mlir-full-build`, or `comparison` once merged) |
| `pointblank-club/mlir_ocaml_bindings` | always | provides `omlir` — the MLIR FFI bindings |
| `devalgupta404/ocaml-ctypes` (branch `oxcaml-0.24.0`) | always | pulled by `opam pin`, no local clone needed |
| `pointblank-club/ocaml_bindgen` | only to regenerate bindings | see "Working with the bindings" above |

### System packages (Debian/Ubuntu)

LLVM/MLIR **must be 22** — paths are hardcoded against `/usr/lib/llvm-22/`.

```bash
sudo apt install \
  libmlir-22-dev llvm-22-dev mlir-22-tools \
  libffi-dev pkg-config cmake ninja-build \
  autoconf m4 build-essential opam rsync
```

### Version pins (must match exactly)

| Component | Version | Why |
|---|---|---|
| OCaml base (bootstrap switch) | `5.4.0` | bootstrap source uses `Format.utf_8_scalar_width` (5.4-only). The compiler you *produce* reports `5.2.0+ox`. |
| `menhir` | exactly `20231231` | newer menhir emits `MenhirLib.StaticVersion.require_20260209`, absent from OxCaml's vendored `CamlinternalMenhirLib`. Used only as a *binary*. |
| `ctypes` / `ctypes-foreign` | `0.24.0` + OxCaml patch | from `devalgupta404/ocaml-ctypes#oxcaml-0.24.0`: eta-expands four `Bigarray.kind` cases for the `@ immutable` modality OxCaml's stdlib adds. |
| `omlir` | `~dev` (path pin) | your local `mlir_ocaml_bindings` clone. |

### Prerequisite

The `otherlibs/{unix,systhreads}` library-rename **and** stub-name fixes
must be committed on the branch (they are, on `fix/mlir-full-build`). A
clean build reverts to committed source, so uncommitted local fixes are
lost. The script guards on this.

### One command

```bash
bash scripts/build-mlir-backend.sh
```

≈2–3 h, several `make -s` cycles, needs ≥8 GB free disk after a clean.
On success it prints `exit code = 42` from a smoke test.

### Why it's a dance, not a recipe

The committed fix (renamed `unix`/`threads` + `OCAMLPATH`→opam) makes the
main dune context resolve `unix`/`threads`/`ctypes`/`omlir` from the opam
switch — so the switch must already host an OxCaml-magic (`Caml1999I577`)
compiler **before** `make -s` can link. But producing that compiler needs
a build. The script breaks the circle in phases:

1. **Pre-fix bootstrap.** A *vanilla* `ocaml-base-compiler.5.4.0` switch;
   revert the 8 fix-touched files to the pre-fix commit (conventional
   `unix`/`threads`, no `OCAMLPATH`→opam) so `unix` resolves from the
   in-build stdlib. `make -s` completes everything except the expected
   `omlir` cmi-magic link. Assemble a consistent OxCaml `_install`.
2. **A SEPARATE `--empty` target switch + flambda2 repo.** Creating it
   with a real 5.4.0 compiler leaves a `5.4.0` invariant; `opam
   custom-install` then tries to recompile `ocaml.5.4.0` against the
   5.2.0+ox compiler → "OCaml version mismatch" → aborts. `--empty` has
   no invariant; the flambda2 repo defines `ocaml-variants.5.2.0+oxcaml`.
   `opam custom-install -n` (the `-n`/`--no-recompilations` is
   essential — see pitfalls), then `opam install ocaml.5.2.0`,
   fake-install + symlink the *vanilla* `dune`/`menhir` binaries (their
   sources don't compile against OxCaml), then pin+install
   `ctypes`/`ctypes-foreign`/`omlir` at I577.
3. **Post-fix rebuild.** Restore the 8 files to HEAD, regenerate
   `duneconf/*.ws` (so the `OCAMLPATH`→opam line is emitted — `make`
   won't regenerate an existing `.ws`), clean `_build`, `make -s`. It
   builds a fresh `runtime_stdlib` whose `CamlinternalFormatBasics`
   interface differs from the v1 `_install` opam-`unix` was built
   against, so it fails. Re-assemble `_install` from this post-fix
   `_build` and re-`custom-install` so the switch stdlib == the post-fix
   `runtime_stdlib`. `make -s` → EXIT 0.
4. `make -s _install` ; `make mlir-dialect` (builds `ocaml-mlir-opt`,
   the `--convert-ocaml-to-arith` tool, via cmake/ninja — separate from
   `make -s`) ; smoke test.

A fresh machine has no switch carrying the `opam-custom-install` plugin
or the vanilla `dune`/`menhir` binaries the script symlinks. The script
expects a "park" switch (default `moonshot-mlir`) providing those; on a
brand-new box, create any vanilla `ocaml-base-compiler.5.4.0` switch and
`opam install opam-custom-install dune menhir.20231231` there first, and
point the script's `PARK=` at it.

## Build & test

Day-to-day loop once the full build has been done:

```bash
# Single-file compile through the pipeline (no link)
_build/_bootinstall/bin/ocamlopt.opt -nostdlib -nopervasives \
  -mlir-backend -c <file>.ml

# Full binary
_install/bin/ocamlopt -mlir-backend mlir_demo.ml -o mlir_demo
./mlir_demo

# In-tree dialect + lowering tests
make -s runtest-mlirize
```

`runtest-mlirize` invokes the boot compiler directly; it exercises MLIR
text emission and `--convert-ocaml-to-arith` lowering on the cases in
`oxcaml/tests/backend/mlirize/`.

## Common pitfalls

These are the failure modes observed while validating the script with a
full clean-from-scratch run:

- **`opam custom-install` aborts with `OCaml version mismatch: 5.2.0,
  expected 5.4.0`.** The target switch was created with a real
  `ocaml-base-compiler.5.4.0` (leaving a `5.4.0` invariant) instead of
  `--empty`. Create it `opam switch create <sw> --empty
  --repositories=flambda2=git+https://github.com/ocaml-flambda/flambda2-opam.git,default`.
- **`opam custom-install` recompiles `dune` and fails on `"with"
  constraint … 'a : any separable`.** You omitted `-n`
  (`--no-recompilations`). Re-custom-install on a populated switch
  otherwise rebuilds every `[uses ocaml]` package incl. `dune 3.22.2`,
  which doesn't compile against OxCaml. The explicit
  `opam install ctypes ctypes-foreign omlir` afterwards still rebuilds
  those against the new stdlib.
- **`opam custom-install -n` rolled back ("former state can be
  restored") and the switch has no stdlib.** Expected on the *second*
  custom-install (populated switch); just run it again — it lands on the
  retry. The script loops up to 3× checking
  `$switch/lib/ocaml/stdlib.cmi == Caml1999I577`.
- **`Library "unix" not found` (ocamldoc / ocaml-jit) after restoring
  post-fix source.** `duneconf/main.ws` is stale — `make` won't
  regenerate an existing `.ws`, so the `OCAMLPATH`→opam line never got
  emitted. `rm -f duneconf/*.ws` then `make -s`.
- **`make inconsistent assumptions over interface
  "CamlinternalFormatBasics"`** between opam-`unix` and
  `runtime_stdlib`. Generation skew: the opam compiler's stdlib differs
  from the post-fix `_build`'s `runtime_stdlib`. Re-assemble `_install`
  from the *post-fix* `_build` and re-`custom-install` so they match.
- **`cannot find -locaml_unix_internal_stubs` /
  `dllocaml_threads_byte_internal_stubs.so: No such file or directory`.**
  The stub-name fix isn't committed (see *Background*). It must be on
  HEAD before the clean run.
- **`menhir`/`require_20260209` mismatch** — `menhir.20231231` exactly.
  It is consumed only as a binary, so fake-install + symlink the vanilla
  one; never recompile it against OxCaml.

## Background — why the build-fix patch exists

moonshot's source `otherlibs/unix/dune` and
`otherlibs/systhreads/byte/dune` defined libraries with the bare names
`unix` and `threads`. That matches the names of the corresponding
opam-side libraries that the system ocamlfind discovers. As long as
nothing in the link closure transitively requires the opam-side `threads`
or `unix`, there's no conflict — moonshot's source libraries are the
only ones in scope and become the installed stdlib.

The MLIR backend's `omlir` library depends on `ctypes-foreign`, which
declares `requires "ctypes threads"`. The instant `omlir` enters the
executable's library closure, dune sees TWO libraries called `threads`
(source-side and opam-side) and refuses to pick one.

The fix renames the source libraries to private names
(`ocaml_unix_internal`, `ocaml_threads_byte_internal`) so that
`(libraries unix)` and `(libraries threads)` in any in-tree consumer
cleanly resolve to the opam-side libraries during the main-context
build. The install rules still emit `unix/unix.cma` and
`threads/threads.cma` under the public names, so externally there's no
visible change in what gets installed.

A second, easily-missed consequence: a renamed library's archives embed
its stub-archive name, so `unix.cm{a,xa}` reference
`-locaml_unix_internal_stubs` and `dllocaml_unix_internal_stubs.so`
(likewise `threads.cma` →
`-locaml_threads_byte_internal_stubs` / `.so`). The install rules must
therefore install the stub `.a`/`.so` under **both** the embedded
internal name and the legacy `libunix_stubs.a` / `dllthreads_stubs.so`
name, or every consumer linking `unix`/`threads` fails at link time.
This is the stub-name fix in `otherlibs/{unix,systhreads}/dune`; it is
required and validated (the dune rules alone are sufficient — no manual
copying of stub archives is needed).
