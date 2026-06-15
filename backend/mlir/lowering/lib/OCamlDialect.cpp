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

LogicalResult ocaml::IfThenElseOp::verify() {
  auto check_region = [&](Region &region, const char *name) -> LogicalResult {
    if (region.empty())
      return emitOpError(std::string(name) + " region cannot be empty");
    Block &block = region.front();
    if (block.empty())
      return emitOpError(std::string(name) + " region entry block cannot be empty");
    auto yieldOp = dyn_cast<ocaml::YieldOp>(block.getTerminator());
    if (!yieldOp)
      return emitOpError(std::string(name) + " region terminator must be ocaml.yield");
    if (yieldOp.getValue().getType() != getResult().getType())
      return emitOpError(std::string(name) + " region yield type must match the op result type");
    return success();
  };

  if (failed(check_region(getThenRegion(), "then")))
    return failure();
  if (failed(check_region(getElseRegion(), "else")))
    return failure();

  return success();
}

