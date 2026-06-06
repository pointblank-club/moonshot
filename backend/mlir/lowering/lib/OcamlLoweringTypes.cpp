#include "OCaml/OCamlDialect.h"

#include <memory>

#include "mlir/IR/BuiltinTypes.h"
#include "mlir/Transforms/DialectConversion.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"

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
      auto res = LLVM::SubOp::create(rewriter, loc, i64Type, sum.getResult(), one.getResult());
      rewriter.replaceOp(op, res.getResult());
      return success();
    } else if (opName == "-") {
      auto diff = LLVM::SubOp::create(rewriter, loc, i64Type, lhs, rhs);
      auto one = LLVM::ConstantOp::create(rewriter, loc, i64Type, 1ULL);
      auto res = LLVM::AddOp::create(rewriter, loc, i64Type, diff.getResult(), one.getResult());
      rewriter.replaceOp(op, res.getResult());
      return success();
    } else if (opName == "*") {
      auto one = LLVM::ConstantOp::create(rewriter, loc, i64Type, 1ULL);
      auto lhsMinusOne = LLVM::SubOp::create(rewriter, loc, i64Type, lhs, one.getResult());
      auto rhsUntagged = LLVM::AShrOp::create(rewriter, loc, i64Type, rhs, one.getResult());
      auto mul = LLVM::MulOp::create(rewriter, loc, i64Type, lhsMinusOne.getResult(), rhsUntagged.getResult());
      auto res = LLVM::AddOp::create(rewriter, loc, i64Type, mul.getResult(), one.getResult());
      rewriter.replaceOp(op, res.getResult());
      return success();
    } else if (opName == "/") {
      auto one = LLVM::ConstantOp::create(rewriter, loc, i64Type, 1ULL);
      auto lhsUntagged = LLVM::AShrOp::create(rewriter, loc, i64Type, lhs, one.getResult());
      auto rhsUntagged = LLVM::AShrOp::create(rewriter, loc, i64Type, rhs, one.getResult());
      auto div = LLVM::SDivOp::create(rewriter, loc, i64Type, lhsUntagged.getResult(), rhsUntagged.getResult());
      auto divShifted = LLVM::ShlOp::create(rewriter, loc, i64Type, div.getResult(), one.getResult());
      auto res = LLVM::AddOp::create(rewriter, loc, i64Type, divShifted.getResult(), one.getResult());
      rewriter.replaceOp(op, res.getResult());
      return success();
    }

    return failure();
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
}

} // namespace ocaml
