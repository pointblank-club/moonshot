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

# Generate OCamlLowering.inc directly from OCamlOps.td
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/OCamlOps.td")
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/OCamlOps.td" OCAML_OPS_TD_CONTENTS)
string(REGEX MATCHALL "def ([A-Za-z0-9_]+Op) *:" OCAML_OPS_MATCHES "${OCAML_OPS_TD_CONTENTS}")

set(OCAML_LOWERING_PATTERN_LIST "")
foreach(MATCH ${OCAML_OPS_MATCHES})
  string(REGEX REPLACE "def ([A-Za-z0-9_]+Op) *:" "\\1" OP_NAME "${MATCH}")
  if(OCAML_LOWERING_PATTERN_LIST STREQUAL "")
    set(OCAML_LOWERING_PATTERN_LIST "${OP_NAME}Lowering")
  else()
    set(OCAML_LOWERING_PATTERN_LIST "${OCAML_LOWERING_PATTERN_LIST},\n${OP_NAME}Lowering")
  endif()
endforeach()

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/OCamlLowering.inc"
  "#ifdef GET_OCAML_LOWERING_PATTERNS_LIST\n${OCAML_LOWERING_PATTERN_LIST}\n#endif\n"
)

add_public_tablegen_target(MLIROCamlIncGen)

set(LLVM_TARGET_DEFINITIONS Passes.td)
mlir_tablegen(Passes.h.inc -gen-pass-decls -name=OCaml)
add_public_tablegen_target(MLIROCamlPassesIncGen)
