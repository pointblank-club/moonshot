#include "OCaml/OCamlDialect.h"

#include <cstring>
#include <memory>

#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/Transforms/DialectConversion.h"

using namespace mlir;

namespace ocaml {

/// Lowers a string constant to a global LLVM array and returns its GEP.
LogicalResult StringType::constLowering(OpBuilder &builder, Attribute value,
                                        Location loc, Value &result,
                                        unsigned &stringIndex,
                                        StringRef symNameVal) const {
  auto stringAttr = llvm::dyn_cast<StringAttr>(value);
  if (!stringAttr)
    return failure();

  std::string sym_name_str = symNameVal.str();
  std::string globalName =
      "caml" + sym_name_str + "." + std::to_string(++stringIndex);
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

  Operation *parentOp = builder.getBlock()->getParentOp();
  ocaml::ModuleOp parent_module = nullptr;
  while (parentOp) {
    if (auto mod = llvm::dyn_cast<ocaml::ModuleOp>(parentOp)) {
      parent_module = mod;
      break;
    }
    parentOp = parentOp->getParentOp();
  }
  if (!parent_module)
    return failure();

  auto i8Type = builder.getI8Type();
  auto ptrType = LLVM::LLVMPointerType::get(builder.getContext());
  {
    OpBuilder::InsertionGuard guard(builder);
    builder.setInsertionPoint(parent_module);
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

/// Lowers a float constant to a Double_tag boxed block and returns its GEP.
LogicalResult FloatType::constLowering(OpBuilder &builder, Attribute value,
                                       Location loc, Value &result,
                                       unsigned &stringIndex,
                                       StringRef symNameVal) const {
  auto floatAttr = llvm::dyn_cast<FloatAttr>(value);
  if (!floatAttr)
    return failure();

  std::string sym_name_str = symNameVal.str();
  std::string globalName =
      "caml" + sym_name_str + "." + std::to_string(++stringIndex);
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

  Operation *parentOp = builder.getBlock()->getParentOp();
  ocaml::ModuleOp parent_module = nullptr;
  while (parentOp) {
    if (auto mod = llvm::dyn_cast<ocaml::ModuleOp>(parentOp)) {
      parent_module = mod;
      break;
    }
    parentOp = parentOp->getParentOp();
  }
  if (!parent_module)
    return failure();

  auto i8Type = builder.getI8Type();
  auto ptrType = LLVM::LLVMPointerType::get(builder.getContext());
  {
    OpBuilder::InsertionGuard guard(builder);
    builder.setInsertionPoint(parent_module);
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

/// Lowers an integer constant to a tagged 63-bit LLVM constant.
LogicalResult IntType::constLowering(OpBuilder &builder, Attribute value,
                                     Location loc, Value &result) const {
  auto intAttr = llvm::dyn_cast<IntegerAttr>(value);
  if (!intAttr)
    return failure();
  auto raw = intAttr.getValue().getSExtValue();
  auto tagged = tagUnboxedValue(raw);
  auto constant =
      LLVM::ConstantOp::create(builder, loc, builder.getI64Type(), tagged);
  result = constant.getResult();
  return success();
}

namespace {

struct LoweringState {
  unsigned stringIndex = 0;
  bool copyDoubleDeclared = false;
};

/// Lowers a constant operation using the type's constLowering interface.
struct ConstantOpLowering : public OpConversionPattern<ocaml::ConstantOp> {
  using OpConversionPattern<ocaml::ConstantOp>::OpConversionPattern;

  ConstantOpLowering(const TypeConverter &typeConverter, MLIRContext *context,
                     std::shared_ptr<LoweringState> state)
      : OpConversionPattern<ocaml::ConstantOp>(typeConverter, context),
        state(std::move(state)) {}

  LogicalResult
  matchAndRewrite(ocaml::ConstantOp op, OpAdaptor,
                  ConversionPatternRewriter &rewriter) const override {
    Type resultType = op.getType();
    if (auto unboxedType =
            llvm::dyn_cast<ocaml::UnboxedTypeInterface>(resultType)) {
      Value resultVal;
      if (failed(unboxedType.constLowering(rewriter, op.getValue(), op.getLoc(),
                                           resultVal)))
        return failure();
      rewriter.replaceOp(op, resultVal);
      return success();
    }
    if (auto boxedType =
            llvm::dyn_cast<ocaml::BoxedTypeInterface>(resultType)) {
      auto parent_module = op->getParentOfType<ocaml::ModuleOp>();
      if (!parent_module) {
        return rewriter.notifyMatchFailure(
            op, "boxed type has no ocaml.module parent");
      }
      StringRef symNameVal = "";
      if (auto symName = parent_module.getSymName()) {
        symNameVal = *symName;
      }
      Value resultVal;
      if (failed(boxedType.constLowering(rewriter, op.getValue(), op.getLoc(),
                                         resultVal, state->stringIndex,
                                         symNameVal)))
        return failure();
      rewriter.replaceOp(op, resultVal);
      return success();
    }
    return failure();
  }

private:
  std::shared_ptr<LoweringState> state;
};

struct BinOpLowering : public OpConversionPattern<ocaml::BinOp> {
  using OpConversionPattern<ocaml::BinOp>::OpConversionPattern;

  /// Lowers a binary operation to tagged arithmetic in LLVM.
  LogicalResult
  matchAndRewrite(ocaml::BinOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    Location loc = op.getLoc();
    Value lhs = adaptor.getLhs();
    Value rhs = adaptor.getRhs();
    StringRef opName = op.getOpName();
    Type i64Type = rewriter.getI64Type();

    if (opName == "+") {
      auto sum = LLVM::AddOp::create(rewriter, loc, i64Type, lhs, rhs);
      auto one = LLVM::ConstantOp::create(rewriter, loc, i64Type, 1ULL);
      auto res = LLVM::SubOp::create(rewriter, loc, i64Type, sum.getResult(),
                                     one.getResult());
      rewriter.replaceOp(op, res.getResult());
      return success();
    } else if (opName == "-") {
      auto diff = LLVM::SubOp::create(rewriter, loc, i64Type, lhs, rhs);
      auto one = LLVM::ConstantOp::create(rewriter, loc, i64Type, 1ULL);
      auto res = LLVM::AddOp::create(rewriter, loc, i64Type, diff.getResult(),
                                     one.getResult());
      rewriter.replaceOp(op, res.getResult());
      return success();
    } else if (opName == "*") {
      auto one = LLVM::ConstantOp::create(rewriter, loc, i64Type, 1ULL);
      auto lhsMinusOne =
          LLVM::SubOp::create(rewriter, loc, i64Type, lhs, one.getResult());
      auto rhsUntagged =
          LLVM::AShrOp::create(rewriter, loc, i64Type, rhs, one.getResult());
      auto mul =
          LLVM::MulOp::create(rewriter, loc, i64Type, lhsMinusOne.getResult(),
                              rhsUntagged.getResult());
      auto res = LLVM::AddOp::create(rewriter, loc, i64Type, mul.getResult(),
                                     one.getResult());
      rewriter.replaceOp(op, res.getResult());
      return success();
    } else if (opName == "/") {
      auto one = LLVM::ConstantOp::create(rewriter, loc, i64Type, 1ULL);
      auto lhsUntagged =
          LLVM::AShrOp::create(rewriter, loc, i64Type, lhs, one.getResult());
      auto rhsUntagged =
          LLVM::AShrOp::create(rewriter, loc, i64Type, rhs, one.getResult());
      auto div =
          LLVM::SDivOp::create(rewriter, loc, i64Type, lhsUntagged.getResult(),
                               rhsUntagged.getResult());
      auto divShifted = LLVM::ShlOp::create(rewriter, loc, i64Type,
                                            div.getResult(), one.getResult());
      auto res = LLVM::AddOp::create(rewriter, loc, i64Type,
                                     divShifted.getResult(), one.getResult());
      rewriter.replaceOp(op, res.getResult());
      return success();
    }

    return failure();
  }
};

struct FloatBinOpLowering : public OpConversionPattern<ocaml::FloatBinOp> {
  using OpConversionPattern<ocaml::FloatBinOp>::OpConversionPattern;

  FloatBinOpLowering(const TypeConverter &typeConverter, MLIRContext *context,
                     std::shared_ptr<LoweringState> state)
      : OpConversionPattern<ocaml::FloatBinOp>(typeConverter, context),
        state(std::move(state)) {}

  /// Unbox both operands, perform the float op, rebox via caml_copy_double.
  LogicalResult
  matchAndRewrite(ocaml::FloatBinOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    Location loc = op.getLoc();
    StringRef opName = op.getOpName();
    auto f64Type = rewriter.getF64Type();
    auto i64Type = rewriter.getI64Type();
    auto ptrType = LLVM::LLVMPointerType::get(op.getContext());

    auto lhs = LLVM::LoadOp::create(rewriter, loc, f64Type, adaptor.getLhs());
    auto rhs = LLVM::LoadOp::create(rewriter, loc, f64Type, adaptor.getRhs());

    Value computed;
    if (opName == "+") {
      computed = LLVM::FAddOp::create(rewriter, loc, f64Type, lhs, rhs);
    } else if (opName == "-") {
      computed = LLVM::FSubOp::create(rewriter, loc, f64Type, lhs, rhs);
    } else if (opName == "*") {
      computed = LLVM::FMulOp::create(rewriter, loc, f64Type, lhs, rhs);
    } else if (opName == "/") {
      computed = LLVM::FDivOp::create(rewriter, loc, f64Type, lhs, rhs);
    } else {
      return failure();
    }

    auto parent_module = op->getParentOfType<ocaml::ModuleOp>();
    if (!parent_module)
      return failure();
    auto copyType = LLVM::LLVMFunctionType::get(i64Type, {f64Type}, false);
    if (!state->copyDoubleDeclared) {
      OpBuilder::InsertionGuard guard(rewriter);
      rewriter.setInsertionPoint(parent_module);
      LLVM::LLVMFuncOp::create(rewriter, loc, "caml_copy_double", copyType,
                               LLVM::Linkage::External);
      state->copyDoubleDeclared = true;
    }
    auto boxed = LLVM::CallOp::create(rewriter, loc, copyType,
                                      "caml_copy_double", ValueRange{computed});
    auto asPtr =
        LLVM::IntToPtrOp::create(rewriter, loc, ptrType, boxed.getResult());
    rewriter.replaceOp(op, asPtr.getResult());
    return success();
  }

private:
  std::shared_ptr<LoweringState> state;
};

// i1 -> OCaml bool (false=1, true=3): (zext(b) << 1) | 1
static Value tagBool(ConversionPatternRewriter &rewriter, Location loc,
                     Value boolI1) {
  auto i64Type = rewriter.getI64Type();
  auto wide = LLVM::ZExtOp::create(rewriter, loc, i64Type, boolI1);
  auto one = LLVM::ConstantOp::create(rewriter, loc, i64Type, 1ULL);
  auto shifted =
      LLVM::ShlOp::create(rewriter, loc, i64Type, wide.getResult(), one);
  auto tagged =
      LLVM::OrOp::create(rewriter, loc, i64Type, shifted.getResult(), one);
  return tagged.getResult();
}

// signed icmp on the tagged words (tag-invariant), then tag the result
struct CmpOpLowering : public OpConversionPattern<ocaml::CmpOp> {
  using OpConversionPattern<ocaml::CmpOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(ocaml::CmpOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    LLVM::ICmpPredicate pred;
    StringRef p = op.getPredicate();
    if (p == "lt") {
      pred = LLVM::ICmpPredicate::slt;
    } else if (p == "gt") {
      pred = LLVM::ICmpPredicate::sgt;
    } else if (p == "eq") {
      pred = LLVM::ICmpPredicate::eq;
    } else if (p == "ne") {
      pred = LLVM::ICmpPredicate::ne;
    } else {
      return rewriter.notifyMatchFailure(op, "unknown cmp predicate");
    }

    auto cmp = LLVM::ICmpOp::create(rewriter, op.getLoc(), pred,
                                    adaptor.getLhs(), adaptor.getRhs());
    rewriter.replaceOp(op, tagBool(rewriter, op.getLoc(), cmp.getResult()));
    return success();
  }
};

// bitwise AND works directly on tagged bools (tag bit is always 1)
struct AndOpLowering : public OpConversionPattern<ocaml::AndOp> {
  using OpConversionPattern<ocaml::AndOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(ocaml::AndOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto result =
        LLVM::AndOp::create(rewriter, op.getLoc(), rewriter.getI64Type(),
                            adaptor.getLhs(), adaptor.getRhs());
    rewriter.replaceOp(op, result.getResult());
    return success();
  }
};

// bitwise OR on tagged bools
struct OrOpLowering : public OpConversionPattern<ocaml::OrOp> {
  using OpConversionPattern<ocaml::OrOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(ocaml::OrOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto result =
        LLVM::OrOp::create(rewriter, op.getLoc(), rewriter.getI64Type(),
                           adaptor.getLhs(), adaptor.getRhs());
    rewriter.replaceOp(op, result.getResult());
    return success();
  }
};

// xor x, 2 flips false (1) and true (3), tag bit preserved
struct NotOpLowering : public OpConversionPattern<ocaml::NotOp> {
  using OpConversionPattern<ocaml::NotOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(ocaml::NotOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto i64Type = rewriter.getI64Type();
    auto two = LLVM::ConstantOp::create(rewriter, op.getLoc(), i64Type, 2ULL);
    auto result = LLVM::XOrOp::create(rewriter, op.getLoc(), i64Type,
                                      adaptor.getValue(), two.getResult());
    rewriter.replaceOp(op, result.getResult());
    return success();
  }
};

} // namespace

/// Populates rewrite patterns for OCaml types and constants.
void populateOcamlLoweringTypesPatterns(RewritePatternSet &patterns,
                                        const TypeConverter &typeConverter,
                                        MLIRContext *context) {
  auto state = std::make_shared<LoweringState>();
  patterns.add<ConstantOpLowering>(typeConverter, context, state);
  patterns.add<FloatBinOpLowering>(typeConverter, context, state);
  patterns.add<BinOpLowering>(typeConverter, context);
  patterns.add<CmpOpLowering, AndOpLowering, OrOpLowering, NotOpLowering>(
      typeConverter, context);
}

} // namespace ocaml
