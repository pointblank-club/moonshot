#include "OCaml/OCamlDialect.h"

#include <cstring>
#include <memory>

#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/Transforms/DialectConversion.h"

using namespace mlir;

namespace ocaml {

/// Lowers a boxed constant to a global LLVM array and returns its GEP.
LogicalResult BoxedTypeInterface::lowerBoxedConstant(
    OpBuilder &builder, Location loc, Value &result, unsigned &stringIndex,
    StringRef symNameVal, StringRef globalValStr) const {
  std::string sym_name_str = symNameVal.str();
  std::string globalName =
      "caml" + sym_name_str + "." + std::to_string(++stringIndex);

  Operation *parentOp = builder.getBlock()->getParentOp();
  Operation *insertParent = nullptr;
  while (parentOp) {
    if (llvm::isa<ocaml::ModuleOp>(parentOp) ||
        llvm::isa<mlir::ModuleOp>(parentOp)) {
      insertParent = parentOp;
      if (llvm::isa<ocaml::ModuleOp>(parentOp))
        break;
    }
    parentOp = parentOp->getParentOp();
  }
  if (!insertParent)
    return failure();

  auto i8Type = builder.getI8Type();
  auto ptrType = LLVM::LLVMPointerType::get(builder.getContext());
  {
    OpBuilder::InsertionGuard guard(builder);
    if (auto ocamlMod = llvm::dyn_cast<ocaml::ModuleOp>(insertParent)) {
      builder.setInsertionPoint(ocamlMod);
    } else if (auto stdMod = llvm::dyn_cast<mlir::ModuleOp>(insertParent)) {
      LLVM::GlobalOp lastConstGlobal = nullptr;
      for (Operation &op : stdMod.getBody()->getOperations()) {
        if (auto global = llvm::dyn_cast<LLVM::GlobalOp>(op)) {
          if (global.getSymName().starts_with("caml" + sym_name_str + ".")) {
            lastConstGlobal = global;
          }
        }
      }
      if (lastConstGlobal) {
        builder.setInsertionPointAfter(lastConstGlobal);
      } else {
        builder.setInsertionPointToStart(stdMod.getBody());
      }
    } else {
      builder.setInsertionPoint(insertParent);
    }
    auto arrayType = LLVM::LLVMArrayType::get(i8Type, globalValStr.size());
    LLVM::GlobalOp::create(builder, loc, arrayType, true,
                           LLVM::Linkage::External, globalName,
                           builder.getStringAttr(StringRef(
                               globalValStr.data(), globalValStr.size())));
  }

  auto address = LLVM::AddressOfOp::create(builder, loc, ptrType, globalName);
  auto dataAddress = LLVM::GEPOp::create(
      builder, loc, ptrType, i8Type, address.getResult(),
      ArrayRef<LLVM::GEPArg>{8}, LLVM::GEPNoWrapFlags::none, {});
  result = dataAddress.getResult();
  return success();
}

/// Lowers a string constant to a global LLVM array and returns its GEP.
LogicalResult StringType::constLowering(OpBuilder &builder, Attribute value,
                                        Location loc, Value &result,
                                        unsigned &stringIndex,
                                        StringRef symNameVal) const {
  auto stringAttr = llvm::dyn_cast<StringAttr>(value);
  if (!stringAttr)
    return failure();

  std::string stringValue = stringAttr.getValue().str();
  size_t dataWords = (stringValue.size() + 1 + 7) / 8;
  uint64_t header = createBoxedHeader(dataWords);
  unsigned padding = (dataWords * 8) - 1 - stringValue.size();
  std::string globalValStr;
  for (unsigned i = 0; i < 8; i++) {
    globalValStr.push_back(static_cast<char>((header >> (i * 8)) & 0xff));
  }
  globalValStr.append(stringValue);
  globalValStr.append(padding, '\0');
  globalValStr.push_back(static_cast<char>(padding));

  return llvm::cast<ocaml::BoxedTypeInterface>(*this).lowerBoxedConstant(
      builder, loc, result, stringIndex, symNameVal, globalValStr);
}

/// Lowers a float constant to a Double_tag boxed block and returns its GEP.
LogicalResult FloatType::constLowering(OpBuilder &builder, Attribute value,
                                       Location loc, Value &result,
                                       unsigned &stringIndex,
                                       StringRef symNameVal) const {
  auto floatAttr = llvm::dyn_cast<FloatAttr>(value);
  if (!floatAttr)
    return failure();

  double doubleValue = floatAttr.getValueAsDouble();
  uint64_t bits;
  std::memcpy(&bits, &doubleValue, sizeof(bits));
  uint64_t header = createBoxedHeader(1);
  std::string globalValStr;
  for (unsigned i = 0; i < 8; i++) {
    globalValStr.push_back(static_cast<char>((header >> (i * 8)) & 0xff));
  }
  for (unsigned i = 0; i < 8; i++) {
    globalValStr.push_back(static_cast<char>((bits >> (i * 8)) & 0xff));
  }

  return llvm::cast<ocaml::BoxedTypeInterface>(*this).lowerBoxedConstant(
      builder, loc, result, stringIndex, symNameVal, globalValStr);
}

} // namespace ocaml
