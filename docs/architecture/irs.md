# Intermediate Representations

Moonshot (and upstream OxCaml) uses several intermediate representations (IRs) between source code and machine code. This page describes each one, what it looks like, and where it lives in the pipeline.

## Overview of all IRs

| IR | Format | Pipeline position | Files |
|---|---|---|---|
| **Parsetree** | OCaml AST | After parsing | `parsing/parsetree.mli` |
| **Typedtree** | OCaml AST + types | After type inference | `typing/typedtree.mli` |
| **Lambda** | Simplified lambda calculus | After Typedtree | `lambda/lambda.mli` |
| **Slambda** | Lambda with layouts | After Lambda | `lambda/slambda.mli` |
| **Flambda** | CPS-based IR | After Slambda (optional) | `middle_end/flambda2/` |
| **Cmm** | C-like memory model | After Flambda or Lambda | `backend/cmm.mli` |
| **Cfg** | Control-flow graph | After Cmm | `backend/cfg/` |
| **MLIR (custom)** | `ocaml` dialect | MLIR backend entry | `backend/mlir/translate.ml` |
| **MLIR (standard)** | `llvm` dialect | After lowering | `backend/mlir/lowering/` |
| **LLVM IR** | SSA LLVM assembly | After MLIR translation | Emitted by `mlir-translate` |

## Parsetree

The untyped AST. Produced by the Menhir parser. Every node carries source locations but no type information.

```ocaml
(* Example: let x = 42 *)
Pstr_value (Nonrecursive,
  [{ pvb_pat = { ppat_desc = Ppat_var { txt = "x" } };
     pvb_expr = { pexp_desc = Pexp_constant (Pconst_integer ("42", None)) } }])
```

## Typedtree

The fully typed AST. Every expression has an `exp_type` field. This is the **entry point for the MLIR backend**.

```ocaml
(* Example: let x = 42 *)
Tstr_value (Nonrecursive,
  [{ vb_pat = { pat_desc = Tpat_var (x_id, ...); pat_type = int_type };
     vb_expr = { exp_desc = Texp_constant (Const_int 42);
                 exp_type = int_type } }])
```

Key nodes for the MLIR backend:

- `Texp_constant` — integer, string, float, char, boolean
- `Texp_let` — local bindings
- `Texp_apply` — function application (including primitives and externals)
- `Texp_ifthenelse` — conditional
- `Texp_function` — anonymous functions
- `Texp_match` — pattern matching

The MLIR backend currently handles `Texp_constant`, `Texp_let`, `Texp_apply` (primitives and externals only), and `Texp_ifthenelse`.

## Lambda

A simplified, untyped lambda calculus. The traditional backend converts Typedtree to Lambda, then optimizes Lambda.

```ocaml
(* Example: let x = 42 *)
Llet (Strict, Pintval, x_id, Lconst (Const_base (Const_int 42)), ...)
```

The MLIR backend **does not use Lambda**. It goes directly from Typedtree to MLIR to avoid duplicating the simplification logic and to experiment with a higher-level IR.

## Slambda

Lambda with layout information (value representation). Used by the Flambda 2 optimizer.

```ocaml
(* Example: let x = 42 *)
Slambda { slv_comptime = ...; slv_runtime = Lconst (Const_base (Const_int 42)) }
```

## Flambda 2

The whole-program optimizer. Operates in CPS (continuation-passing style). For details, see the [Flambda 2 encyclopedia](../appendix/flambda2-encyclopedia.md) or the upstream docs in `middle_end/flambda2/docs/encyclopaedia.md`.

The MLIR backend does not use Flambda 2. Future work may explore running MLIR optimization passes after the custom dialect lowering.

## Cmm

A low-level C-like IR with explicit memory operations. The traditional backend uses Cmm as the last high-level IR before machine code generation.

```ocaml
(* Example: let x = 42 *)
Clet (x_id, Cconst_int (42, ...), ...)
```

## Cfg

The control-flow graph backend's IR. Blocks of instructions with explicit successors. Used by the CFG backend and the LLVM backend (which converts CFG to LLVM IR).

```ocaml
(* Simplified: a block with an integer move *)
{ start = label_1;
  body = [Instr (Op (Const_int 42))];
  terminator = Return }
```

## MLIR (custom dialect)

The MLIR backend's first IR. Uses a custom `ocaml` dialect with these ops:

| Op | Description | Example |
|---|---|---|
| `ocaml.module` | Module container | `ocaml.module @Foo { ... }` |
| `ocaml.entry` | Entry point (top-level expressions) | `ocaml.entry { ... }` |
| `ocaml.int` | Tagged integer constant | `%0 = ocaml.int 42 : !ocaml.int` |
| `ocaml.string` | Immutable string constant | `%0 = ocaml.string "hello" : !ocaml.string` |
| `ocaml.binop` | Binary operation (arithmetic or comparison) | `%2 = ocaml.binop "+" %0, %1 : !ocaml.int, !ocaml.int -> !ocaml.int` |
| `ocaml.extern` | External function declaration | `ocaml.extern @puts {target = "caml_puts"} : (!ocaml.string) -> !ocaml.int` |
| `ocaml.extern_call` | Call to external function | `%1 = ocaml.extern_call @puts(%0 : !ocaml.string) : (!ocaml.string) -> !ocaml.int` |

Types in the custom dialect:

| Type | Description |
|---|---|
| `!ocaml.int` | OCaml tagged integer (63-bit value with low bit 1) |
| `!ocaml.string` | OCaml immutable string (header + bytes) |
| `!ocaml.value` | Generic OCaml value (opaque pointer) |

## MLIR (standard dialects)

After lowering, the module uses standard MLIR dialects:

- `func.func` — function definitions
- `arith.addi`, `arith.muli`, `arith.cmpi` — integer arithmetic
- `scf.if` — structured control flow (lowered to `cf` before LLVM)
- `llvm.func`, `llvm.call`, `llvm.return` — LLVM dialect functions
- `llvm.mlir.global` — global constants
- `llvm.getelementptr` — pointer arithmetic

## LLVM IR

The final IR before object file generation. Standard LLVM SSA assembly.

```llvm
; Example: let x = 42
@camlFoo__gc_roots = global i64 0
...

define i64 @camlFoo__entry() {
  ret i64 85   ; 42 << 1 + 1 = 85 (tagged representation)
}
```

Note the tagged integer representation: OCaml immediate integers are shifted left by 1 and have the low bit set to 1. So `42` becomes `85` in the LLVM IR.

## IR comparison for `let x = 4 + 3`

### Typedtree

```ocaml
Tstr_value (Nonrecursive,
  [{ vb_pat = ...;
     vb_expr = { exp_desc = Texp_apply
       ({ exp_desc = Texp_ident (Path.Pident ( + )) },
        [Nolabel, { exp_desc = Texp_constant (Const_int 4) };
         Nolabel, { exp_desc = Texp_constant (Const_int 3) }]) } }])
```

### Lambda (for reference)

```ocaml
Llet (Strict, Pintval, x,
  Lprim (Pintadd, [Lconst (Const_base (Const_int 4));
                    Lconst (Const_base (Const_int 3))]),
  ...)
```

### Custom MLIR

```mlir
ocaml.module @Foo {
  ocaml.entry {
    %0 = ocaml.int 4 : !ocaml.int
    %1 = ocaml.int 3 : !ocaml.int
    %2 = ocaml.binop "+" %0, %1 : !ocaml.int, !ocaml.int -> !ocaml.int
  }
}
```

### Standard MLIR (after lowering)

```mlir
module {
  llvm.func @camlFoo__entry() -> i64 {
    %0 = llvm.mlir.constant(7 : i64) : i64
    llvm.return %0 : i64
  }
  ...
}
```

### LLVM IR

```llvm
define i64 @camlFoo__entry() {
  ret i64 7
}
```

## Next steps

- [Compiler pipeline](compiler-pipeline.md) — how these IRs connect
- [MLIR dialects](../mlir-backend/dialects.md) — the custom dialect in depth
- [MLIR lowering](../mlir-backend/lowering.md) — how custom MLIR becomes standard MLIR
