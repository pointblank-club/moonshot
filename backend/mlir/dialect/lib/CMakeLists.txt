add_mlir_dialect_library(MLIROCaml
  OCamlDialect.cpp
  OCamlToArith.cpp

  ADDITIONAL_HEADER_DIRS
  ${PROJECT_SOURCE_DIR}/include/OCaml

  DEPENDS
  MLIROCamlIncGen

  LINK_LIBS PUBLIC
  MLIRIR
  MLIRArithDialect
  MLIRPass
  MLIRTransformUtils
)
