#ifndef OCAML_OCAMLDIALECT_H
#define OCAML_OCAMLDIALECT_H

#include "mlir/Bytecode/BytecodeOpInterface.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/Pass/Pass.h"

#define GEN_PASS_DECL
#include "OCaml/Passes.h.inc"

#include "OCaml/OCamlDialect.h.inc"

#define GET_OP_CLASSES
#include "OCaml/OCamlOps.h.inc"

#endif // OCAML_OCAMLDIALECT_H
