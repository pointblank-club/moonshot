#ifndef OCAML_DIALECT_TD
#define OCAML_DIALECT_TD

include "mlir/IR/OpBase.td"
include "mlir/IR/AttrTypeBase.td"
include "mlir/IR/EnumAttr.td"
include "mlir/Interfaces/InferTypeOpInterface.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def OCaml_Dialect : Dialect {
  let name = "ocaml";
  let cppNamespace = "::ocaml";
  let summary = "OCaml semantic dialect";
  let description = [{
    Operations representing OCaml-specific arithmetic semantics over
    runtime-tagged integers (tagged repr `T(n) = 2n + 1`). Distinct
    from `arith` so the lowering pass can apply tag-aware rewrites
    (e.g. `addi a, b -> (a + b) - 1`).

    Operands and results use `i64` rather than a custom `!ocaml.int`
    type so the dialect can be consumed by frontends that build IR
    via the MLIR C API without registering a custom dialect handle.
  }];
}

class OCaml_Op<string mnemonic_, list<Trait> traits = []>
    : Op<OCaml_Dialect, mnemonic_, traits>;

def OCaml_CmpIPredicateAttr : I64EnumAttr<
    "CmpIPredicate", "OCaml integer comparison predicate", [
      I64EnumAttrCase<"eq",  0, "eq">,
      I64EnumAttrCase<"ne",  1, "ne">,
      I64EnumAttrCase<"slt", 2, "slt">,
      I64EnumAttrCase<"sle", 3, "sle">,
      I64EnumAttrCase<"sgt", 4, "sgt">,
      I64EnumAttrCase<"sge", 5, "sge">,
    ]> {
  let cppNamespace = "::ocaml";
}

def OCaml_ConstantOp : OCaml_Op<"constant",
    [Pure, ConstantLike]> {
  let summary = "OCaml integer constant (untagged)";
  let description = [{
    The attribute holds the untagged signed value. Lowers to
    `arith.constant ((value << 1) | 1) : i64`.
  }];
  let arguments = (ins I64Attr:$value);
  let results = (outs I64:$result);
  let assemblyFormat = "$value attr-dict";
}

class OCaml_BinIntOp<string mnemonic_>
    : OCaml_Op<mnemonic_, [Pure, SameOperandsAndResultType]> {
  let arguments = (ins I64:$lhs, I64:$rhs);
  let results = (outs I64:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}

def OCaml_AddIOp : OCaml_BinIntOp<"addi"> {
  let summary = "OCaml tagged integer addition";
}

def OCaml_SubIOp : OCaml_BinIntOp<"subi"> {
  let summary = "OCaml tagged integer subtraction";
}

def OCaml_MulIOp : OCaml_BinIntOp<"muli"> {
  let summary = "OCaml tagged integer multiplication";
}

def OCaml_DivIOp : OCaml_BinIntOp<"divi"> {
  let summary = "OCaml tagged integer division (truncating)";
}

def OCaml_ModIOp : OCaml_BinIntOp<"modi"> {
  let summary = "OCaml tagged integer remainder";
}

def OCaml_CmpIOp : OCaml_Op<"cmpi", [Pure]> {
  let summary = "OCaml tagged integer comparison";
  let description = [{
    Lowers to `arith.cmpi` on the underlying i64 — tagging is
    monotonic, so equality and signed ordering predicates are
    preserved.
  }];
  let arguments = (ins OCaml_CmpIPredicateAttr:$predicate,
                       I64:$lhs,
                       I64:$rhs);
  let results = (outs I1:$result);
  let assemblyFormat = "$predicate `,` $lhs `,` $rhs attr-dict `:` type($lhs)";
}

def OCaml_CmpFPredicateAttr : I64EnumAttr<
    "CmpFPredicate", "OCaml ordered float comparison predicate", [
      I64EnumAttrCase<"oeq", 0, "oeq">,
      I64EnumAttrCase<"ogt", 1, "ogt">,
      I64EnumAttrCase<"oge", 2, "oge">,
      I64EnumAttrCase<"olt", 3, "olt">,
      I64EnumAttrCase<"ole", 4, "ole">,
      I64EnumAttrCase<"one", 5, "one">,
    ]> {
  let cppNamespace = "::ocaml";
}

class OCaml_BinFloatOp<string mnemonic_>
    : OCaml_Op<mnemonic_, [Pure, SameOperandsAndResultType]> {
  let arguments = (ins F64:$lhs, F64:$rhs);
  let results = (outs F64:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}

def OCaml_AddFOp : OCaml_BinFloatOp<"addf"> {
  let summary = "OCaml unboxed float addition";
}

def OCaml_SubFOp : OCaml_BinFloatOp<"subf"> {
  let summary = "OCaml unboxed float subtraction";
}

def OCaml_MulFOp : OCaml_BinFloatOp<"mulf"> {
  let summary = "OCaml unboxed float multiplication";
}

def OCaml_DivFOp : OCaml_BinFloatOp<"divf"> {
  let summary = "OCaml unboxed float division";
}

def OCaml_CmpFOp : OCaml_Op<"cmpf", [Pure]> {
  let summary = "OCaml ordered float comparison";
  let description = [{
    OCaml's `=`/`<>`/`<`/`<=`/`>`/`>=` on `float` follow IEEE *ordered*
    semantics (NaN compares unequal to anything). Lowers directly to
    `arith.cmpf` with the corresponding `O*` predicate.
  }];
  let arguments = (ins OCaml_CmpFPredicateAttr:$predicate,
                       F64:$lhs,
                       F64:$rhs);
  let results = (outs I1:$result);
  let assemblyFormat = "$predicate `,` $lhs `,` $rhs attr-dict `:` type($lhs)";
}

#endif
