include "mlir/IR/OpBase.td"
include "mlir/IR/SymbolInterfaces.td"
include "mlir/Interfaces/SideEffectInterfaces.td"

def OCaml_Dialect : Dialect {
  let name = "ocaml";
  let summary = "The OCaml Dialect";
  let description = [{
    The OCaml dialect represents OCaml-specific constructs during compilation.
  }];
  let cppNamespace = "::ocaml";
  let useDefaultTypePrinterParser = 1;
}

class OCaml_Op<string mnemonic, list<Trait> traits = []> :
    Op<OCaml_Dialect, mnemonic, traits>;

include "mlir/IR/AttrTypeBase.td"

def BoxedTypeInterface : TypeInterface<"BoxedTypeInterface"> {
  let cppNamespace = "::ocaml";
  let methods = [
    InterfaceMethod<
      /*description=*/"Get the tag of the boxed type",
      /*retTy=*/"unsigned",
      /*methodName=*/"getTag",
      /*args=*/(ins),
      /*methodBody=*/"",
      /*defaultImplementation=*/"return 0;"
    >,
    InterfaceMethod<
      /*description=*/"Lower a constant of this boxed type to LLVM",
      /*retTy=*/"::mlir::LogicalResult",
      /*methodName=*/"constLowering",
      /*args=*/(ins "::mlir::OpBuilder &":$builder, "::mlir::Attribute":$value, "::mlir::Location":$loc, "::mlir::Value &":$result, "unsigned &":$stringIndex, "::llvm::StringRef":$symNameVal)
    >
  ];
}

def UnboxedTypeInterface : TypeInterface<"UnboxedTypeInterface"> {
  let cppNamespace = "::ocaml";
  let methods = [
    InterfaceMethod<
      /*description=*/"Lower a constant of this unboxed type to LLVM",
      /*retTy=*/"::mlir::LogicalResult",
      /*methodName=*/"constLowering",
      /*args=*/(ins "::mlir::OpBuilder &":$builder, "::mlir::Attribute":$value, "::mlir::Location":$loc, "::mlir::Value &":$result)
    >
  ];
}

include "OCamlTypes.td"

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
      "$predicate $lhs `,` $rhs attr-dict `:` type($lhs) `->` type($result)";
}

def FloatCmpOp : OCaml_Op<"float_cmp", [AllTypesMatch<["lhs", "rhs"]>]> {
  // predicate is "lt", "gt", "eq" or "ne"
  let summary = "Compare two OCaml floats, yielding an OCaml bool";
  let arguments = (ins StrAttr:$predicate, AnyType:$lhs, AnyType:$rhs);
  let results = (outs BoolType:$result);
  let assemblyFormat =
      "$predicate $lhs `,` $rhs attr-dict `:` type($lhs) `->` type($result)";
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
                       Variadic<AnyType>:$args,
                       TypeAttrOf<FunctionType>:$callee_type);
  let results = (outs AnyType:$result);
  let assemblyFormat =
      "$callee `(` $args `:` type($args) `)` attr-dict `:` "
      # "$callee_type `->` type($result)";
}

def BinOp : OCaml_Op<"binop"> {
  let summary = "An OCaml binary operation";
  let arguments = (ins StrAttr:$op_name, AnyType:$lhs, AnyType:$rhs);
  let results = (outs AnyType:$result);
  let assemblyFormat =
      "$op_name $lhs `,` $rhs attr-dict `:` type($lhs) `,` type($rhs) `->` type($result)";
}

def FloatBinOp : OCaml_Op<"float_binop"> {
  let summary = "An OCaml floating-point binary operation";
  let arguments = (ins StrAttr:$op_name, AnyType:$lhs, AnyType:$rhs);
  let results = (outs AnyType:$result);
  let assemblyFormat =
      "$op_name $lhs `,` $rhs attr-dict `:` type($lhs) `,` type($rhs) `->` type($result)";
}
