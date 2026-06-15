set(LLVM_TARGET_DEFINITIONS OCamlDialect.td)
mlir_tablegen(OCamlDialect.h.inc -gen-dialect-decls -dialect=ocaml)
mlir_tablegen(OCamlDialect.cpp.inc -gen-dialect-defs -dialect=ocaml)

set(LLVM_TARGET_DEFINITIONS OCamlTypes.td)
mlir_tablegen(OCamlTypes.h.inc -gen-typedef-decls)
mlir_tablegen(OCamlTypes.cpp.inc -gen-typedef-defs)
mlir_tablegen(OCamlTypeInterfaces.h.inc -gen-type-interface-decls)
mlir_tablegen(OCamlTypeInterfaces.cpp.inc -gen-type-interface-defs)

set(LLVM_TARGET_DEFINITIONS OCamlOps.td)
mlir_tablegen(OCamlOps.h.inc -gen-op-decls)
mlir_tablegen(OCamlOps.cpp.inc -gen-op-defs)

add_public_tablegen_target(MLIROCamlIncGen)

set(LLVM_TARGET_DEFINITIONS Passes.td)
mlir_tablegen(Passes.h.inc -gen-pass-decls -name=OCaml)
add_public_tablegen_target(MLIROCamlPassesIncGen)
