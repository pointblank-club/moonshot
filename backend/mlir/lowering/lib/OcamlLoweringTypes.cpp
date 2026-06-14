#include "OCaml/OCamlDialect.h"

#include <memory>

#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/Transforms/DialectConversion.h"

using namespace mlir;

namespace ocaml {

namespace {

struct LoweringState {
  unsigned stringIndex = 0;
};

struct StringOpLowering : public OpConversionPattern<ocaml::StringOp> {
  using OpConversionPattern<ocaml::StringOp>::OpConversionPattern;

  StringOpLowering(const TypeConverter &typeConverter, MLIRContext *context,
                   std::shared_ptr<LoweringState> state)
      : OpConversionPattern<ocaml::StringOp>(typeConverter, context),
        state(std::move(state)) {}

  LogicalResult
  matchAndRewrite(ocaml::StringOp op, OpAdaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto parent_module = op->getParentOfType<ocaml::ModuleOp>();
    if (!parent_module) {
      return rewriter.notifyMatchFailure(op,
                                         "string has no ocaml.module parent");
    }

    std::string sym_name_str = "";
    if (auto symName = parent_module.getSymName()) {
      sym_name_str = symName->str();
    }
    std::string globalName =
        "caml" + sym_name_str + "." + std::to_string(++state->stringIndex);
    std::string stringValue = op.getValue().str();
    size_t dataWords = (stringValue.size() + 1 + 7) / 8;
    uint64_t header = (dataWords << 10) | 0x3fc;
    unsigned padding = (dataWords * 8) - 1 - stringValue.size();
    std::string value;
    for (unsigned i = 0; i < 8; i++) {
      value.push_back(static_cast<char>((header >> (i * 8)) & 0xff));
    }
    value.append(stringValue);
    value.append(padding, '\0');
    value.push_back(static_cast<char>(padding));

    auto i8Type = rewriter.getI8Type();
    auto ptrType = LLVM::LLVMPointerType::get(op.getContext());
    OpBuilder::InsertionGuard guard(rewriter);
    rewriter.setInsertionPoint(parent_module);
    auto arrayType = LLVM::LLVMArrayType::get(i8Type, value.size());
    LLVM::GlobalOp::create(
        rewriter, op.getLoc(), arrayType, true, LLVM::Linkage::External,
        globalName,
        rewriter.getStringAttr(StringRef(value.data(), value.size())));

    rewriter.setInsertionPoint(op);
    auto address =
        LLVM::AddressOfOp::create(rewriter, op.getLoc(), ptrType, globalName);
    auto dataAddress = LLVM::GEPOp::create(
        rewriter, op.getLoc(), ptrType, i8Type, address.getResult(),
        ArrayRef<LLVM::GEPArg>{8}, LLVM::GEPNoWrapFlags::none, {});
    rewriter.replaceOp(op, dataAddress.getResult());
    return success();
  }

private:
  std::shared_ptr<LoweringState> state;
};

struct IntOpLowering : public OpConversionPattern<ocaml::IntOp> {
  using OpConversionPattern<ocaml::IntOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(ocaml::IntOp op, OpAdaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto raw = static_cast<uint64_t>(op.getValue());
    auto tagged = static_cast<int64_t>((raw << 1) | 1ULL);
    auto value = LLVM::ConstantOp::create(rewriter, op.getLoc(),
                                          rewriter.getI64Type(), tagged);
    rewriter.replaceOp(op, value.getResult());
    return success();
  }
};

// arith on tagged ints: + and - fix up the tag; * and / untag then retag
struct BinOpLowering : public OpConversionPattern<ocaml::BinOp> {
  using OpConversionPattern<ocaml::BinOp>::OpConversionPattern;

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

void populateOcamlLoweringTypesPatterns(RewritePatternSet &patterns,
                                        const TypeConverter &typeConverter,
                                        MLIRContext *context) {
  auto state = std::make_shared<LoweringState>();
  patterns.add<StringOpLowering>(typeConverter, context, state);
  patterns.add<IntOpLowering>(context);
  patterns.add<BinOpLowering>(typeConverter, context);
  patterns.add<CmpOpLowering, AndOpLowering, OrOpLowering, NotOpLowering>(
      typeConverter, context);
}

} // namespace ocaml
