get_property(dialect_libs GLOBAL PROPERTY MLIR_DIALECT_LIBS)
get_property(conversion_libs GLOBAL PROPERTY MLIR_CONVERSION_LIBS)
get_property(extension_libs GLOBAL PROPERTY MLIR_EXTENSION_LIBS)

add_llvm_executable(ocaml-mlir-opt ocaml-mlir-opt.cpp)
llvm_update_compile_flags(ocaml-mlir-opt)
target_link_libraries(ocaml-mlir-opt PRIVATE
  ${dialect_libs}
  ${conversion_libs}
  ${extension_libs}
  MLIROCaml
  MLIROptLib
)
mlir_check_all_link_libraries(ocaml-mlir-opt)
