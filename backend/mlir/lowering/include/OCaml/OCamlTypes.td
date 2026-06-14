#ifndef OCAML_TYPES
#define OCAML_TYPES

include "mlir/IR/AttrTypeBase.td"
include "mlir/IR/OpBase.td"



class OCaml_Type<string name, string typeMnemonic, list<Trait> traits = []>
    : TypeDef<OCaml_Dialect, name, traits> {
  let mnemonic = typeMnemonic;
}

class BoxedType<string name, string typeMnemonic, int typeTag, list<Trait> traits = []>
    : TypeDef<OCaml_Dialect, name, !listconcat(traits, [
        DeclareTypeInterfaceMethods<BoxedTypeInterface, ["constLowering"]>
      ])> {
  let mnemonic = typeMnemonic;
  let extraClassDeclaration = [{
    unsigned getTag() const { return }] # typeTag # [{; }
    static uint64_t createBoxedHeader(size_t dataWords) {
      return (static_cast<uint64_t>(dataWords) << 10) | 0x300ULL | }] # typeTag # [{;
    }
  }];
}

class UnboxedType<string name, string typeMnemonic, list<Trait> traits = []>
    : TypeDef<OCaml_Dialect, name, !listconcat(traits, [DeclareTypeInterfaceMethods<UnboxedTypeInterface>])> {
  let mnemonic = typeMnemonic;
  let extraClassDeclaration = [{
    static int64_t tagUnboxedValue(int64_t raw) {
      return (raw << 1) | 1;
    }
  }];
}

def StringType : BoxedType<"String", "string", 252> {
  let summary = "OCaml string type";
}

def FloatType : BoxedType<"Float", "float", 253> {
  let summary = "OCaml float type";
}

def IntType : UnboxedType<"Int", "int"> {
  let summary = "OCaml int type";
}

def BoolType : OCaml_Type<"Bool", "bool"> {
  let summary = "OCaml bool type";
}

def ConstantOp : OCaml_Op<"constant", [ConstantLike, Pure]> {
  let summary = "An OCaml constant definition";
  let arguments = (ins AnyAttr:$value);
  let results = (outs AnyType:$result);
  let hasCustomAssemblyFormat = 1;
}

#endif // OCAML_TYPES
