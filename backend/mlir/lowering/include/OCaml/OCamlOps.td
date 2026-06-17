#ifndef OCAML_OPS
#define OCAML_OPS

include "mlir/IR/OpBase.td"
include "mlir/IR/SymbolInterfaces.td"
include "mlir/Interfaces/SideEffectInterfaces.td"
include "mlir/Interfaces/ControlFlowInterfaces.td"

include "OCamlTypes.td"

class OCaml_Op<string mnemonic, list<Trait> traits = []>
    : Op<OCaml_Dialect, mnemonic, traits>;

def ModuleOp : OCaml_Op<"module", [
    IsolatedFromAbove,
    NoRegionArguments,
    Symbol,
    SymbolTable,
    NoTerminator
]> {
  let summary = "The top-level OCaml module operation";
  let arguments = (ins OptionalAttr<SymbolNameAttr>:$sym_name);
  let regions = (region AnyRegion:$body);
  let assemblyFormat = "($sym_name^)? attr-dict-with-keyword $body";
}

def EntryOp : OCaml_Op<"entry", [
    NoRegionArguments,
    NoTerminator
]> {
  let summary = "The OCaml entry point operation";
  let regions = (region AnyRegion:$body);
  let assemblyFormat = "attr-dict-with-keyword $body";
}

def ExternOp : OCaml_Op<"extern", [
    Symbol
]> {
  let summary = "An OCaml external declaration";
  let arguments = (ins SymbolNameAttr:$sym_name,
                       TypeAttrOf<FunctionType>:$function_type,
                       StrAttr:$target);
  let assemblyFormat = "$sym_name attr-dict `:` $function_type";
}

def CmpOp : OCaml_Op<"cmp", [AllTypesMatch<["lhs", "rhs"]>]> {
  // predicate is "lt", "gt", "eq" or "ne"
  let summary = "Compare two tagged OCaml ints, yielding an OCaml bool";
  let arguments = (ins StrAttr:$predicate, AnyType:$lhs, AnyType:$rhs);
  let results = (outs BoolType:$result);
  let assemblyFormat =
      "$predicate $lhs `,` $rhs attr-dict `:` "
      "type($lhs) `->` type($result)";
}

def AndOp : OCaml_Op<"and", [AllTypesMatch<["lhs", "rhs", "result"]>]> {
  let summary = "Logical AND of two OCaml bools";
  let arguments = (ins BoolType:$lhs, BoolType:$rhs);
  let results = (outs BoolType:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}

def OrOp : OCaml_Op<"or", [AllTypesMatch<["lhs", "rhs", "result"]>]> {
  let summary = "Logical OR of two OCaml bools";
  let arguments = (ins BoolType:$lhs, BoolType:$rhs);
  let results = (outs BoolType:$result);
  let assemblyFormat = "$lhs `,` $rhs attr-dict `:` type($result)";
}

def NotOp : OCaml_Op<"not", [AllTypesMatch<["value", "result"]>]> {
  let summary = "Logical NOT of an OCaml bool";
  let arguments = (ins BoolType:$value);
  let results = (outs BoolType:$result);
  let assemblyFormat = "$value attr-dict `:` type($result)";
}

def ExternCallOp : OCaml_Op<"extern_call"> {
  let summary = "A call to an OCaml external";
  let arguments = (ins SymbolRefAttr:$callee,
                       Variadic<AnyType>:$args);
  let results = (outs AnyType:$result);
  let assemblyFormat =
      "$callee `(` $args `)` attr-dict `:` functional-type($args, results)";
}

def BinOp : OCaml_Op<"binop"> {
  let summary = "An OCaml binary operation";
  let arguments = (ins StrAttr:$op_name, AnyType:$lhs, AnyType:$rhs);
  let results = (outs AnyType:$result);
  let assemblyFormat =
      "$op_name $lhs `,` $rhs attr-dict `:` "
      "type($lhs) `,` type($rhs) `->` type($result)";
}

def ConstantOp : OCaml_Op<"constant", [ConstantLike, Pure]> {
  let summary = "An OCaml constant definition";
  let arguments = (ins AnyAttr:$value);
  let results = (outs AnyType:$result);
  let hasCustomAssemblyFormat = 1;
}

def YieldOp : OCaml_Op<"yield", [Terminator, ReturnLike]> {
  let summary = "Yield a value from an if-then-else branch region";
  let arguments = (ins AnyType:$value);
  let assemblyFormat = "$value attr-dict `:` type($value)";
}

def IfThenElseOp : OCaml_Op<"if_then_else"> {
  let summary = "An OCaml if-then-else expression";
  let description = [{
    Evaluates `cond` (a tagged OCaml bool: false=1, true=3).
    Executes the then-region if true, else-region otherwise.
    Both regions must be single-block and end with ocaml.yield.
    Yields the result of whichever region ran.
  }];
  let arguments = (ins BoolType:$cond);
  let results = (outs AnyType:$result);
  let regions = (region AnyRegion:$then_region,
                        AnyRegion:$else_region);
  let assemblyFormat =
      "$cond attr-dict `:` type($cond) `->` type($result) `then` $then_region `else` $else_region";
  let hasVerifier = 1;
}

#endif // OCAML_OPS
