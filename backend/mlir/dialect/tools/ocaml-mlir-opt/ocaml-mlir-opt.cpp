#include "mlir/IR/DialectRegistry.h"
#include "mlir/InitAllDialects.h"
#include "mlir/InitAllExtensions.h"
#include "mlir/InitAllPasses.h"
#include "mlir/Tools/mlir-opt/MlirOptMain.h"

#include "OCaml/OCamlDialect.h"
#include "OCaml/Passes.h"

int main(int argc, char **argv) {
  mlir::DialectRegistry registry;
  mlir::registerAllDialects(registry);
  mlir::registerAllExtensions(registry);
  mlir::registerAllPasses();
  ocaml::registerOCamlPasses();
  registry.insert<ocaml::OCamlDialect>();
  return mlir::asMainReturnCode(mlir::MlirOptMain(
      argc, argv, "OxCaml MLIR optimizer driver\n", registry));
}
