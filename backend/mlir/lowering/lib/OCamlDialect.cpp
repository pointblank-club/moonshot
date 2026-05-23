#include "OCaml/OCamlDialect.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/OpImplementation.h"
#include "mlir/IR/DialectImplementation.h"

#include "OCaml/OCamlDialect.cpp.inc"

#define GET_OP_CLASSES
#include "OCaml/OCamlOps.cpp.inc"

void ocaml::OCamlDialect::initialize() {
  addOperations<
#define GET_OP_LIST
#include "OCaml/OCamlOps.cpp.inc"
  >();
}
