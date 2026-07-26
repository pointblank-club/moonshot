#include "OCaml/OCamlDialect.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/DialectImplementation.h"
#include "mlir/IR/OpImplementation.h"
#include "llvm/ADT/TypeSwitch.h"

using namespace mlir;

#include "OCaml/OCamlDialect.cpp.inc"

#include "OCaml/OCamlTypeInterfaces.cpp.inc"

#define GET_TYPEDEF_CLASSES
#include "OCaml/OCamlTypes.cpp.inc"

#define GET_OP_CLASSES
#include "OCaml/OCamlOps.cpp.inc"

void ocaml::OCamlDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "OCaml/OCamlOps.cpp.inc"
      >();
  addTypes<
#define GET_TYPEDEF_LIST
#include "OCaml/OCamlTypes.cpp.inc"
      >();
}

ParseResult ocaml::ConstantOp::parse(OpAsmParser &parser,
                                     OperationState &result) {
  Attribute valueAttr;
  Type type;
  if (parser.parseAttribute(valueAttr, "value", result.attributes) ||
      parser.parseColonType(type) || parser.addTypeToList(type, result.types))
    return failure();
  return success();
}

void ocaml::ConstantOp::print(OpAsmPrinter &p) {
  p << " ";
  if (auto intAttr = llvm::dyn_cast<IntegerAttr>(getValue())) {
    p << intAttr.getValue();
  } else {
    p << getValue();
  }
  p.printOptionalAttrDict((*this)->getAttrs(), {"value"});
  p << " : " << getType();
}

OpFoldResult ocaml::ConstantOp::fold(FoldAdaptor adaptor) {
  return getValue();
}
