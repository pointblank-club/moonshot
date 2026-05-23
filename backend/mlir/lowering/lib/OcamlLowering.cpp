#include "OCaml/OCamlDialect.h"

#include <memory>

#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/Transforms/DialectConversion.h"

#include "llvm/ADT/SmallVector.h"

namespace ocaml {

#define GEN_PASS_DEF_CONVERTOCAMLTOBUILTIN
#include "OCaml/Passes.h.inc"

} // namespace ocaml

using namespace mlir;

namespace {

struct LoweringState {
  unsigned stringIndex = 0;
};

std::optional<std::string> findExternTarget(ocaml::ModuleOp module,
                                            StringRef name) {
  for (Operation &op : module.getBody().front()) {
    if (auto externOp = dyn_cast<ocaml::ExternOp>(op)) {
      if (externOp.getSymName() == name) {
        return externOp.getTarget().str();
      }
    }
  }
  return std::nullopt;
}

LLVM::LLVMFuncOp ensureFunction(OpBuilder &builder, Location loc,
                                StringRef name, LLVM::LLVMFunctionType type) {
  if (auto module =
          builder.getBlock() ? builder.getBlock()->getParentOp() : nullptr) {
    if (auto existing = dyn_cast_or_null<LLVM::LLVMFuncOp>(
            SymbolTable::lookupSymbolIn(module, name))) {
      return existing;
    }
  }
  return LLVM::LLVMFuncOp::create(builder, loc, name, type,
                                  LLVM::Linkage::External);
}

// Lowers `ocaml.entry`.
struct EntryOpLowering : public OpConversionPattern<ocaml::EntryOp> {
  using OpConversionPattern<ocaml::EntryOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(ocaml::EntryOp op, OpAdaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto parent_module = op->getParentOfType<ocaml::ModuleOp>();
    if (!parent_module) {
      return rewriter.notifyMatchFailure(op,
                                         "entry has no ocaml.module parent");
    }

    std::string sym_name_str = "";
    if (auto symName = parent_module.getSymName()) {
      sym_name_str = symName->str();
    }
    std::string entry_name = "caml" + sym_name_str + "__entry";

    rewriter.setInsertionPoint(parent_module);

    Location loc = op.getLoc();
    auto i64Type = rewriter.getI64Type();
    auto funcType = LLVM::LLVMFunctionType::get(i64Type, {}, false);
    auto entryFunc = LLVM::LLVMFuncOp::create(
        rewriter, loc, entry_name, funcType, LLVM::Linkage::External);

    auto *block = rewriter.createBlock(&entryFunc.getBody());
    rewriter.mergeBlocks(&op.getBody().front(), block);

    rewriter.setInsertionPointToEnd(block);
    Value unit = LLVM::ConstantOp::create(rewriter, loc, i64Type, 1);
    LLVM::ReturnOp::create(rewriter, loc, unit);

    rewriter.eraseOp(op);
    return success();
  }
};

// Lowers `ocaml.string`.
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

// Lowers `ocaml.extern_call`.
struct ExternCallOpLowering : public OpConversionPattern<ocaml::ExternCallOp> {
  using OpConversionPattern<ocaml::ExternCallOp>::OpConversionPattern;

  ExternCallOpLowering(const TypeConverter &typeConverter, MLIRContext *context)
      : OpConversionPattern<ocaml::ExternCallOp>(typeConverter, context) {}

  // TODO: extern_call should be calling `caml_c_call`, by passing the target
  // pointer to %rax, but for now we just lower it to a direct call.
  LogicalResult
  matchAndRewrite(ocaml::ExternCallOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto parent_module = op->getParentOfType<ocaml::ModuleOp>();
    if (!parent_module) {
      return rewriter.notifyMatchFailure(op, "call has no ocaml.module parent");
    }

    StringRef callee = op.getCallee().getRootReference();
    std::optional<std::string> target = findExternTarget(parent_module, callee);
    if (!target) {
      return rewriter.notifyMatchFailure(op, "extern target not found");
    }

    SmallVector<Value> args(adaptor.getArgs().begin(), adaptor.getArgs().end());
    SmallVector<Type> argTypes;
    argTypes.reserve(args.size());
    for (Value arg : args) {
      argTypes.push_back(arg.getType());
    }

    auto i64Type = rewriter.getI64Type();
    auto targetType = LLVM::LLVMFunctionType::get(i64Type, argTypes, false);
    OpBuilder::InsertionGuard guard(rewriter);
    rewriter.setInsertionPoint(parent_module);
    auto targetFunc =
        ensureFunction(rewriter, op.getLoc(), *target, targetType);

    rewriter.setInsertionPoint(op);
    LLVM::CallOp::create(rewriter, op.getLoc(), targetType,
                         targetFunc.getName(), args);
    rewriter.eraseOp(op);
    return success();
  }
};

// Lowers `ocaml.extern`.
struct ExternOpLowering : public OpConversionPattern<ocaml::ExternOp> {
  using OpConversionPattern<ocaml::ExternOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(ocaml::ExternOp op, OpAdaptor,
                  ConversionPatternRewriter &rewriter) const override {
    rewriter.eraseOp(op);
    return success();
  }
};

// Lowers `ocaml.module`.
struct ModuleOpLowering : public OpConversionPattern<ocaml::ModuleOp> {
  using OpConversionPattern<ocaml::ModuleOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(ocaml::ModuleOp op, OpAdaptor,
                  ConversionPatternRewriter &rewriter) const override {
    std::string sym_name_str = "";
    if (auto symName = op.getSymName()) {
      sym_name_str = symName->str();
    }
    Location loc = op.getLoc();

    std::string gc_roots_name = "caml" + sym_name_str + "__gc_roots";
    std::string data_begin_name = "caml" + sym_name_str + "__data_begin";
    std::string data_end_name = "caml" + sym_name_str + "__data_end";
    std::string code_begin_name = "caml" + sym_name_str + "__code_begin";
    std::string code_end_name = "caml" + sym_name_str + "__code_end";
    std::string frametable_name = "caml" + sym_name_str + "__frametable";

    rewriter.setInsertionPoint(op);

    auto i64Type = rewriter.getI64Type();
    auto zeroAttr = rewriter.getI64IntegerAttr(0);

    LLVM::GlobalOp::create(rewriter, loc, i64Type, false,
                           LLVM::Linkage::External, gc_roots_name, zeroAttr);
    LLVM::GlobalOp::create(rewriter, loc, i64Type, false,
                           LLVM::Linkage::External, data_begin_name, zeroAttr);
    LLVM::GlobalOp::create(rewriter, loc, i64Type, false,
                           LLVM::Linkage::External, data_end_name, zeroAttr);
    LLVM::GlobalOp::create(rewriter, loc, i64Type, false,
                           LLVM::Linkage::External, code_begin_name, zeroAttr);
    LLVM::GlobalOp::create(rewriter, loc, i64Type, false,
                           LLVM::Linkage::External, code_end_name, zeroAttr);
    LLVM::GlobalOp::create(rewriter, loc, i64Type, false,
                           LLVM::Linkage::External, frametable_name, zeroAttr);

    rewriter.eraseOp(op);
    return success();
  }
};

struct ConvertOCamlToBuiltin
    : public ::ocaml::impl::ConvertOCamlToBuiltinBase<ConvertOCamlToBuiltin> {
  void runOnOperation() override {
    ModuleOp module = getOperation();
    MLIRContext *context = &getContext();
    TypeConverter typeConverter;
    auto ptrType = LLVM::LLVMPointerType::get(context);
    typeConverter.addConversion([&](Type type) -> Type {
      if (auto opaque = llvm::dyn_cast<OpaqueType>(type)) {
        if (opaque.getDialectNamespace() == "ocaml" &&
            opaque.getTypeData() == "string") {
          return ptrType;
        }
      }
      return type;
    });
    auto loweringState = std::make_shared<LoweringState>();
    {
      ConversionTarget target(*context);
      target.addLegalDialect<LLVM::LLVMDialect>();
      target.addLegalOp<ocaml::ModuleOp, ocaml::ExternOp, ocaml::EntryOp>();
      target.addIllegalOp<ocaml::StringOp, ocaml::ExternCallOp>();

      RewritePatternSet patterns(context);
      patterns.add<EntryOpLowering>(context);
      patterns.add<StringOpLowering>(typeConverter, context, loweringState);
      patterns.add<ExternCallOpLowering>(typeConverter, context);

      if (failed(applyPartialConversion(module, target, std::move(patterns)))) {
        signalPassFailure();
        return;
      }
    }

    {
      ConversionTarget target(*context);
      target.addLegalDialect<LLVM::LLVMDialect>();
      target.addLegalOp<ocaml::ModuleOp, ocaml::ExternOp>();
      target.addIllegalOp<ocaml::EntryOp>();

      RewritePatternSet patterns(context);
      patterns.add<EntryOpLowering>(context);

      if (failed(applyPartialConversion(module, target, std::move(patterns)))) {
        signalPassFailure();
        return;
      }
    }

    {
      ConversionTarget target(*context);
      target.addLegalDialect<LLVM::LLVMDialect>();
      target.addIllegalDialect<ocaml::OCamlDialect>();

      RewritePatternSet patterns(context);
      patterns.add<ExternOpLowering>(context);
      patterns.add<ModuleOpLowering>(context);

      if (failed(applyPartialConversion(module, target, std::move(patterns)))) {
        signalPassFailure();
        return;
      }
    }
  }
};

} // namespace
