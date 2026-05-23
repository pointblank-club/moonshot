add_mlir_dialect_library(MLIROCaml
  OCamlDialect.cpp
  OcamlLowering.cpp
  OcamlInit.cpp

  DEPENDS
  MLIROCamlIncGen
  MLIROCamlPassesIncGen

  LINK_LIBS PUBLIC
  MLIRIR
  MLIRPass
  MLIRTransformUtils
  MLIRLLVMDialect
  MLIRFuncDialect
  MLIRParser
  MLIRRegisterAllDialects
  MLIRRegisterAllExtensions
  MLIRRegisterAllPasses
  MLIRToLLVMIRTranslationRegistration
  MLIRArithToLLVM
  MLIRFuncToLLVM
  MLIRReconcileUnrealizedCasts
)
