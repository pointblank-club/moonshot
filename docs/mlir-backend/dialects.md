# OCaml MLIR Dialect Reference

The `ocaml` dialect is a custom MLIR dialect defined for the Moonshot compiler. It captures OCaml-specific language constructs at a high level before they are lowered to standard MLIR dialects.

## Dialect definition

**Files:** `backend/mlir/lowering/include/OCaml/OCamlDialect.h`, `backend/mlir/lowering/lib/OCamlDialect.cpp`

The dialect is registered with MLIR under the name `ocaml` and the namespace `ocaml::`.

## Operations

### `ocaml.module`

A module container, similar to `builtin.module` but with an optional symbol name.

**Syntax:**

```mlir
ocaml.module @ModuleName {
  ...
}
```

**Attributes:**

| Name | Type | Description |
|---|---|---|
| `sym_name` | `StringAttr` | Optional module name |

**Lowered to:** `module` (builtin module op)

### `ocaml.entry`

The entry point for a module's top-level expressions. Corresponds to the module initialization code in OCaml.

**Syntax:**

```mlir
ocaml.entry {
  ...
}
```

**Lowered to:** `llvm.func @caml<ModuleName>__entry() -> i64`

The entry function returns the OCaml unit value (`1` as a tagged integer).

### `ocaml.int`

A tagged integer constant.

**Syntax:**

```mlir
%0 = ocaml.int 42 : !ocaml.int
```

**Attributes:**

| Name | Type | Description |
|---|---|---|
| `value` | `IntegerAttr` | The untagged integer value |

**Result type:** `!ocaml.int`

**Lowered to:** `arith.constant` (after tagging: `value * 2 + 1`)

### `ocaml.string`

An immutable string constant.

**Syntax:**

```mlir
%0 = ocaml.string "hello" : !ocaml.string
```

**Attributes:**

| Name | Type | Description |
|---|---|---|
| `value` | `StringAttr` | The string contents |

**Result type:** `!ocaml.string`

**Lowered to:** `llvm.mlir.global` constant with OCaml string header

The global is an array of bytes containing the header (8 bytes) followed by the string data and padding. A `getelementptr` skips the header.

### `ocaml.binop`

A binary operation on two values.

**Syntax:**

```mlir
%2 = ocaml.binop "+" %0, %1 : !ocaml.int, !ocaml.int -> !ocaml.int
```

**Attributes:**

| Name | Type | Description |
|---|---|---|
| `op_name` | `StringAttr` | Operator name: `"+"`, `"-"`, `"*"`, `"/"`, `"="`, `"<"`, `">"`, `"=="`, `"!="`, etc. |

**Operands:**

| # | Type | Description |
|---|---|---|
| 0 | `!ocaml.int` or `!ocaml.value` | Left operand |
| 1 | `!ocaml.int` or `!ocaml.value` | Right operand |

**Result type:** `!ocaml.int` or `!ocaml.value`

**Lowered to:** `arith.addi`, `arith.muli`, `arith.subi`, `arith.divsi`, `arith.cmpi`, `arith.cmpf`, etc.

For integer operations, the lowering untags both operands, performs the operation, and retags the result. For float operations, the operands are untagged and interpreted as floats.

### `ocaml.extern`

Declares an external function available at link time.

**Syntax:**

```mlir
ocaml.extern @puts {target = "caml_puts"} : (!ocaml.string) -> !ocaml.int
```

**Attributes:**

| Name | Type | Description |
|---|---|---|
| `sym_name` | `StringAttr` | The symbol name used in the module |
| `target` | `StringAttr` | The actual C function name |

**Function type:** Any function type

**Lowered to:** `llvm.func` declaration with the target name

### `ocaml.extern_call`

Calls an external function.

**Syntax:**

```mlir
%1 = ocaml.extern_call @puts(%0 : !ocaml.string) : (!ocaml.string) -> !ocaml.int
```

**Operands:**

| # | Type | Description |
|---|---|---|
| 0..N | `!ocaml.*` | Arguments |

**Result type:** `!ocaml.int` or `!ocaml.value`

**Lowered to:** `llvm.call` with the target function name

## Types

### `!ocaml.int`

OCaml's tagged integer type. At the runtime level, this is an `i64` where the low bit is 1 and the upper 63 bits hold the signed integer value.

**Lowered to:** `i64`

### `!ocaml.string`

OCaml's immutable string type. At the runtime level, this is a pointer to a heap block with a header and byte data.

**Lowered to:** `!llvm.ptr` (pointer to the string data, skipping the header)

### `!ocaml.value`

A generic OCaml value. This is the catch-all type for values that the frontend does not know how to represent more precisely.

**Lowered to:** `!llvm.ptr` (opaque pointer to a heap value)

## Type conversion rules

The `map_ocaml_type_to_mlir` function in `backend/mlir/mlir.ml` converts OCaml `Types.type_expr` to MLIR types:

| OCaml type | MLIR type |
|---|---|
| `int` | `!ocaml.int` |
| `string` | `!ocaml.string` |
| `float` | `!ocaml.value` (currently) |
| `bool` | `!ocaml.int` (tagged) |
| `char` | `!ocaml.int` (tagged) |
| `unit` | `!ocaml.int` (tagged, value 1) |
| Any other type | `!ocaml.value` |

## Assembly format

The dialect uses MLIR's standard assembly format. Ops are prefixed with `ocaml.` and types with `!ocaml.`.

```mlir
ocaml.module @Example {
  ocaml.entry {
    %0 = ocaml.int 1 : !ocaml.int
    %1 = ocaml.int 2 : !ocaml.int
    %2 = ocaml.binop "+" %0, %1 : !ocaml.int, !ocaml.int -> !ocaml.int
    %3 = ocaml.string "hello" : !ocaml.string
    %4 = ocaml.extern_call @puts(%3 : !ocaml.string) : (!ocaml.string) -> !ocaml.value
  }
  ocaml.extern @puts {target = "caml_puts"} : (!ocaml.string) -> !ocaml.value
}
```

## Adding a new operation

To add a new operation to the dialect:

1. Define the op in the C++ dialect files (`backend/mlir/lowering/include/OCaml/`)
2. Add a lowering pattern in `OcamlLowering.cpp`
3. Add the OCaml frontend emission in `backend/mlir/translate.ml`
4. Add tests in `oxcaml/tests/backend/mlirize/`

See the [contributing guide](../developer/contributing.md#adding-a-new-mlir-op) for a worked example.

## Next steps

- [Lowering pipeline](pipeline.md) — how the dialect is lowered
- [Lowering implementation](lowering.md) — C++ details
- [Contributing](../developer/contributing.md) — how to extend the dialect
