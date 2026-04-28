#ifndef OCAML_DIALECT_H
#define OCAML_DIALECT_H

#include "mlir/Bytecode/BytecodeOpInterface.h"
#include "mlir/IR/Dialect.h"
#include "mlir/IR/OpDefinition.h"
#include "mlir/IR/Types.h"
#include "mlir/Interfaces/InferTypeOpInterface.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"

#include "OCaml/OCamlDialect.h.inc"
#include "OCaml/OCamlEnums.h.inc"

#define GET_OP_CLASSES
#include "OCaml/OCamlOps.h.inc"

#endif // OCAML_DIALECT_H
