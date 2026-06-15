#ifndef OCAML_TYPES
#define OCAML_TYPES

include "mlir/IR/AttrTypeBase.td"
include "mlir/IR/OpBase.td"

def OCaml_Dialect : Dialect {
  let name = "ocaml";
  let summary = "The OCaml Dialect";
  let description = [{
    The OCaml dialect represents OCaml-specific constructs during compilation.
  }];
  let cppNamespace = "::ocaml";
  let useDefaultTypePrinterParser = 1;
}

class OCaml_Op<string mnemonic, list<Trait> traits = []>
    : Op<OCaml_Dialect, mnemonic, traits>;

def BoxedTypeInterface : TypeInterface<"BoxedTypeInterface"> {
  let cppNamespace = "::ocaml";
  let methods =
      [InterfaceMethod<
           /*description=*/"Get the tag of the boxed type",
           /*retTy=*/"unsigned",
           /*methodName=*/"getTag",
           /*args=*/(ins),
           /*methodBody=*/"",
           /*defaultImplementation=*/"return 0;">,
       InterfaceMethod<
           /*description=*/"Lower a constant of this boxed type to LLVM",
           /*retTy=*/"::mlir::LogicalResult",
           /*methodName=*/"constLowering",
           /*args=*/
           (ins "::mlir::OpBuilder &":$builder, "::mlir::Attribute":$value,
               "::mlir::Location":$loc, "::mlir::Value &":$result,
               "unsigned &":$stringIndex, "::llvm::StringRef":$symNameVal)>];
  let extraClassDeclaration = [{
    ::mlir::LogicalResult lowerBoxedConstant(
        ::mlir::OpBuilder &builder, ::mlir::Location loc, ::mlir::Value &result,
        unsigned &stringIndex, ::llvm::StringRef symNameVal,
        ::llvm::StringRef globalValStr) const;
  }];
}

def UnboxedTypeInterface : TypeInterface<"UnboxedTypeInterface"> {
  let cppNamespace = "::ocaml";
  let methods = [InterfaceMethod<
      /*description=*/"Lower a constant of this unboxed type to LLVM",
      /*retTy=*/"::mlir::LogicalResult",
      /*methodName=*/"constLowering",
      /*args=*/
      (ins "::mlir::OpBuilder &":$builder, "::mlir::Attribute":$value,
          "::mlir::Location":$loc, "::mlir::Value &":$result),
      /*methodBody=*/"",
      /*defaultImplementation=*/[{
        int64_t raw = 0;
        if (::llvm::isa<::mlir::UnitAttr>(value)) {
          raw = 0;
        } else {
          auto intAttr = ::llvm::dyn_cast<::mlir::IntegerAttr>(value);
          if (!intAttr)
            return ::mlir::failure();
          raw = intAttr.getValue().getSExtValue();
        }
        auto tagged = $_type.tagUnboxedValue(raw);
        auto constant =
            ::mlir::LLVM::ConstantOp::create(
                builder, loc, builder.getI64Type(), tagged);
        result = constant.getResult();
        return ::mlir::success();
      }]>];
}

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

def BoolType : UnboxedType<"Bool", "bool"> {
  let summary = "OCaml bool type";
}

def UnitType : UnboxedType<"Unit", "unit"> {
  let summary = "OCaml unit type";
}

#endif // OCAML_TYPES
