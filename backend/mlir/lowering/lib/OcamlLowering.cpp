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

void populateOcamlLoweringTypesPatterns(
    ::mlir::RewritePatternSet &patterns,
    const ::mlir::TypeConverter &typeConverter, ::mlir::MLIRContext *context);

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

    // If we can find the corresponding ocaml::ExternOp declaration in the
    // parent module, inspect its function_type attribute to determine which
    // arguments are expected as raw (unboxed) i64s on the C side. For those
    // arguments, untag the OCaml immediate representation before making the
    // direct call (untagging = arithmetic shift right by 1).
    auto i64Type = rewriter.getI64Type();
    for (Operation &child : parent_module.getBody().front()) {
      if (auto externOp = dyn_cast<ocaml::ExternOp>(child)) {
        if (externOp.getSymName() == callee) {
          if (auto funcTypeAttr =
                  child.getAttrOfType<TypeAttr>("function_type")) {
            Type t = funcTypeAttr.getValue();
            if (mlir::isa<FunctionType>(t)) {
              auto funcType = mlir::cast<FunctionType>(t);
              size_t n = std::min<size_t>(args.size(), funcType.getNumInputs());
              OpBuilder::InsertionGuard argGuard(rewriter);
              rewriter.setInsertionPoint(op);
              for (size_t i = 0; i < n; ++i) {
                Type expected = funcType.getInput(i);
                if (expected.isInteger(64)) {
                  // Untag OCaml immediate (tagged = (v<<1)|1) -> raw =
                  // ashr(tagged,1)
                  auto oneConst = LLVM::ConstantOp::create(
                      rewriter, op.getLoc(), i64Type, 1ULL);
                  auto untag =
                      LLVM::AShrOp::create(rewriter, op.getLoc(), i64Type,
                                           args[i], oneConst.getResult());
                  args[i] = untag.getResult();
                }
              }
            }
          }
          break;
        }
      }
    }

    SmallVector<Type> argTypes;
    argTypes.reserve(args.size());
    for (Value arg : args) {
      argTypes.push_back(arg.getType());
    }

    auto targetType = LLVM::LLVMFunctionType::get(i64Type, argTypes, false);
    OpBuilder::InsertionGuard guard(rewriter);
    rewriter.setInsertionPoint(parent_module);
    auto targetFunc =
        ensureFunction(rewriter, op.getLoc(), *target, targetType);

    rewriter.setInsertionPoint(op);
    auto callOp = LLVM::CallOp::create(rewriter, op.getLoc(), targetType,
                                       targetFunc.getName(), args);
    rewriter.replaceOp(op, callOp.getResult());
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
    auto i64Type = IntegerType::get(context, 64);
    typeConverter.addConversion([&](Type type) -> Type {
      if (llvm::isa<ocaml::StringType>(type)) {
        return ptrType;
      }
      if (llvm::isa<ocaml::FloatType>(type)) {
        return ptrType;
      }
      if (llvm::isa<ocaml::IntType>(type)) {
        return i64Type;
      }
      if (auto opaque = llvm::dyn_cast<OpaqueType>(type)) {
        if (opaque.getDialectNamespace() == "ocaml") {
          if (opaque.getTypeData() == "string") {
            return ptrType;
          }
          if (opaque.getTypeData() == "int") {
            return i64Type;
          }
          if (opaque.getTypeData() == "value") {
            return i64Type;
          }
        }
      }
      return type;
    });

    auto loweringState = std::make_shared<LoweringState>();
    {
      ConversionTarget target(*context);
      target.addLegalDialect<LLVM::LLVMDialect>();
      target.addLegalOp<ocaml::ModuleOp, ocaml::ExternOp, ocaml::EntryOp>();
      target.addIllegalOp<ocaml::ConstantOp, ocaml::ExternCallOp, ocaml::BinOp,
                          ocaml::FloatBinOp, ocaml::CmpOp, ocaml::AndOp,
                          ocaml::OrOp, ocaml::NotOp>();

      RewritePatternSet patterns(context);
      patterns.add<EntryOpLowering>(context);
      ocaml::populateOcamlLoweringTypesPatterns(patterns, typeConverter,
                                                context);
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
