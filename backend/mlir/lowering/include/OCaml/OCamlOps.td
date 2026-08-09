#ifndef OCAML_OPS
#define OCAML_OPS

include "mlir/IR/OpBase.td"
include "mlir/IR/SymbolInterfaces.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

include "OCamlTypes.td"

class OCaml_Op<string mnemonic, list<Trait> traits = []>
    : Op<OCaml_Dialect, mnemonic, traits>;

def ModuleOp : OCaml_Op<"module", [
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

def FunctionOp : OCaml_Op<"function", [
    Symbol,
    NoTerminator
]> {
  let summary = "An OCaml function definition";
  let arguments = (ins SymbolNameAttr:$sym_name,
                       StrAttr:$mangled_name,
                       TypeAttrOf<FunctionType>:$function_type);
  let regions = (region SizedRegion<1>:$body);
  let assemblyFormat =
      "$sym_name `(` $mangled_name `)` `:` $function_type "
      "attr-dict-with-keyword $body";
}

def ReturnOp : OCaml_Op<"return"> {
  let summary = "Returns a value from an OCaml function";
  let arguments = (ins Ocaml_Type:$value);
  let assemblyFormat = "$value attr-dict `:` type($value)";
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
  let arguments = (ins StrAttr:$predicate, Ocaml_Type:$lhs, Ocaml_Type:$rhs);
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
                       Variadic<Ocaml_Type>:$args);
  let results = (outs Ocaml_Type:$result);
  let assemblyFormat =
      "$callee `(` $args `)` attr-dict `:` functional-type($args, results)";
}

def CallOp : OCaml_Op<"call"> {
  let summary = "A call to an OCaml function";
  let arguments = (ins OptionalAttr<StrAttr>:$module_name,
                       StrAttr:$function_name,
                       StrAttr:$mangled_name,
                       Variadic<AnyType>:$args);
  let results = (outs AnyType:$result);
  let assemblyFormat =
      "(`[` $module_name^ `]`)? $function_name `(` $mangled_name `)` `(` $args `)` attr-dict `:` functional-type($args, results)";
}

def BinOp : OCaml_Op<"binop"> {
  let summary = "An OCaml binary operation";
  let arguments = (ins StrAttr:$op_name, Ocaml_Type:$lhs, Ocaml_Type:$rhs);
  let results = (outs Ocaml_Type:$result);
  let assemblyFormat =
      "$op_name $lhs `,` $rhs attr-dict `:` "
      "type($lhs) `,` type($rhs) `->` type($result)";
}

def ConstantOp : OCaml_Op<"constant", [ConstantLike, Pure]> {
  let summary = "An OCaml constant definition";
  let arguments = (ins AnyAttr:$value);
  let results = (outs Ocaml_Type:$result);
  let hasCustomAssemblyFormat = 1;
  let hasFolder = 1;
}

def AllocArrayOp : OCaml_Op<"alloc_array"> {
  let summary = "Allocates an OCaml array block on the heap with initial values";
  let arguments = (ins Variadic<Ocaml_Type>:$elements);
  let results = (outs ArrayType:$result);
  let assemblyFormat =
      "`(` $elements `)` attr-dict `:` functional-type($elements, results)";
}

def ArrayGetOp : OCaml_Op<"array_get"> {
  let summary = "Gets an element from an OCaml array";
  let arguments = (ins ArrayType:$array, IntType:$index);
  let results = (outs Ocaml_Type:$result);
  let assemblyFormat =
      "$array `[` $index `]` attr-dict `:` type($array) `,` type($index) `->` type($result)";
}

def ArraySetOp : OCaml_Op<"array_set"> {
  let summary = "Sets an element in an OCaml array";
  let arguments = (ins ArrayType:$array, IntType:$index, Ocaml_Type:$value);
  let results = (outs UnitType:$result);
  let assemblyFormat =
      "$array `[` $index `]` `=` $value attr-dict `:` type($array) `,` type($index) `,` type($value) `->` type($result)";
}

def ArrayLenOp : OCaml_Op<"array_length"> {
  let summary = "Gets the length of an OCaml array as a tagged int";
  let arguments = (ins ArrayType:$array);
  let results = (outs IntType:$result);
  let assemblyFormat =
      "$array attr-dict `:` type($array) `->` type($result)";
}

#endif // OCAML_OPS
