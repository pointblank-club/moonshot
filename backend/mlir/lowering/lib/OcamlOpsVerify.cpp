#include "OCaml/OCamlDialect.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/OpImplementation.h"

using namespace mlir;

LogicalResult ocaml::IfThenElseOp::verify() {
  auto check_region = [&](Region &region, const char *name) -> LogicalResult {
    if (region.empty())
      return emitOpError(std::string(name) + " region cannot be empty");
    Block &block = region.front();
    if (block.empty())
      return emitOpError(std::string(name) +
                         " region entry block cannot be empty");
    auto yieldOp = dyn_cast<ocaml::YieldOp>(block.getTerminator());
    if (!yieldOp)
      return emitOpError(std::string(name) +
                         " region terminator must be ocaml.yield");
    if (yieldOp.getValue().getType() != getResult().getType())
      return emitOpError(std::string(name) +
                         " region yield type must match the op result type");
    return success();
  };

  if (failed(check_region(getThenRegion(), "then")))
    return failure();
  if (failed(check_region(getElseRegion(), "else")))
    return failure();

  return success();
}
