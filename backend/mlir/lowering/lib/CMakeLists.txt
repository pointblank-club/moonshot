add_mlir_dialect_library(MLIROCaml
  OCamlDialect.cpp
  OcamlLowering.cpp
  OcamlOps.cpp
  OcamlTypes.cpp
  OcamlInit.cpp
  OcamlOpsVerify.cpp

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

add_library(dllMLIROCaml SHARED
  OCamlDialect.cpp
  OcamlLowering.cpp
  OcamlOps.cpp
  OcamlTypes.cpp
  OcamlInit.cpp
  OcamlOpsVerify.cpp
)

set_target_properties(dllMLIROCaml PROPERTIES PREFIX "")

add_dependencies(dllMLIROCaml MLIROCamlIncGen MLIROCamlPassesIncGen)

target_link_libraries(dllMLIROCaml PUBLIC
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
