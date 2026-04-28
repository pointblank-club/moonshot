#include "OCaml/OCamlDialect.h"

#include "mlir/IR/Builders.h"
#include "mlir/IR/DialectImplementation.h"
#include "mlir/IR/OpImplementation.h"
#include "llvm/ADT/TypeSwitch.h"

using namespace mlir;
using namespace ocaml;

#include "OCaml/OCamlDialect.cpp.inc"
#include "OCaml/OCamlEnums.cpp.inc"

#define GET_OP_CLASSES
#include "OCaml/OCamlOps.cpp.inc"

void OCamlDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "OCaml/OCamlOps.cpp.inc"
      >();
}
