#ifndef OCAML_OCAMLDIALECT_H
#define OCAML_OCAMLDIALECT_H

#include "mlir/Bytecode/BytecodeOpInterface.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/IR/OpDefinition.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"
#include "mlir/Pass/Pass.h"

#define GEN_PASS_DECL
#include "OCaml/Passes.h.inc"

#include "OCaml/OCamlDialect.h.inc"

#include "OCaml/OCamlTypeInterfaces.h.inc"

#define GET_TYPEDEF_CLASSES
#include "OCaml/OCamlTypes.h.inc"

#define GET_OP_CLASSES
#include "OCaml/OCamlOps.h.inc"

#include "mlir/IR/BuiltinAttributes.h"
#include "llvm/ADT/StringMap.h"

namespace mlir {
class TypeConverter;
class RewritePatternSet;
class MLIRContext;
} // namespace mlir

namespace ocaml {
struct LoweringState {
  unsigned stringIndex = 0;
  bool copyDoubleDeclared = false;
  std::string moduleName;
  llvm::StringMap<std::string> externTargets;
  llvm::StringMap<mlir::TypeAttr> externTypes;
};

void populateOcamlOpsPatterns(::mlir::RewritePatternSet &patterns,
                              const ::mlir::TypeConverter &typeConverter,
                              ::mlir::MLIRContext *context,
                              std::shared_ptr<LoweringState> state);
} // namespace ocaml

#endif // OCAML_OCAMLDIALECT_H
