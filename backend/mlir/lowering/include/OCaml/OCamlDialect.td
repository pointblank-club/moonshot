include "mlir/IR/OpBase.td"
include "mlir/IR/SymbolInterfaces.td"

def OCaml_Dialect : Dialect {
  let name = "ocaml";
  let summary = "The OCaml Dialect";
  let description = [{
    The OCaml dialect represents OCaml-specific constructs during compilation.
  }];
  let cppNamespace = "::ocaml";
}

class OCaml_Op<string mnemonic, list<Trait> traits = []> :
    Op<OCaml_Dialect, mnemonic, traits>;

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

def StringOp : OCaml_Op<"string"> {
  let summary = "An OCaml string literal";
  let arguments = (ins StrAttr:$value);
  let results = (outs AnyType:$result);
  let assemblyFormat = "$value attr-dict `:` type($result)";
}

def IntOp : OCaml_Op<"int"> {
  let summary = "An OCaml int literal";
  let arguments = (ins I64Attr:$value);
  let results = (outs AnyType:$result);
  let assemblyFormat = "$value attr-dict `:` type($result)";
}

def ExternCallOp : OCaml_Op<"extern_call"> {
  let summary = "A call to an OCaml external";
  let arguments = (ins SymbolRefAttr:$callee,
                       Variadic<AnyType>:$args,
                       TypeAttrOf<FunctionType>:$callee_type);
  let assemblyFormat =
      "$callee `(` $args `:` type($args) `)` attr-dict `:` $callee_type";
}

def BinOp : OCaml_Op<"binop"> {
  let summary = "An OCaml binary operation";
  let arguments = (ins StrAttr:$op_name, AnyType:$lhs, AnyType:$rhs);
  let results = (outs AnyType:$result);
  let assemblyFormat =
      "$op_name $lhs `,` $rhs attr-dict `:` type($lhs) `,` type($rhs) `->` type($result)";
}
