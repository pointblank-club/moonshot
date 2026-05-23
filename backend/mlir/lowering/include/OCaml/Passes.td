#ifndef OCAML_PASSES
#define OCAML_PASSES

include "mlir/Pass/PassBase.td"

def ConvertOCamlToBuiltin : Pass<"convert-ocaml-to-builtin", "mlir::ModuleOp"> {
  let summary = "Lower OCaml module to standard builtin module";
  let description = [{
    Lowers the custom ocaml.module operation to standard MLIR builtin.module and LLVM globals.
  }];
  let dependentDialects = [
    "mlir::LLVM::LLVMDialect",
    "mlir::func::FuncDialect"
  ];
}

#endif // OCAML_PASSES
