#include "OCaml/OCamlDialect.h"

#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Transforms/DialectConversion.h"

namespace ocaml {

#define GEN_PASS_DEF_CONVERTOCAMLTOBUILTIN
#include "OCaml/Passes.h.inc"

} // namespace ocaml

using namespace mlir;

namespace {

struct EntryOpLowering : public OpConversionPattern<ocaml::EntryOp> {
  using OpConversionPattern<ocaml::EntryOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(ocaml::EntryOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto parent_module = op->getParentOfType<ocaml::ModuleOp>();
    if (!parent_module) {
      return rewriter.notifyMatchFailure(op,
                                         "entry has no ocaml.module parent");
    }

    for (auto &block : op.getBody()) {
      if (!block.empty()) {
        return rewriter.notifyMatchFailure(op, "entry body not empty");
      }
    }

    std::string sym_name_str = "";
    if (auto symName = parent_module.getSymName()) {
      sym_name_str = symName->str();
    }
    std::string entry_name = "caml" + sym_name_str + "__entry";

    rewriter.setInsertionPoint(parent_module);

    Location loc = op.getLoc();
    auto voidType = LLVM::LLVMVoidType::get(op.getContext());
    auto funcType =
        LLVM::LLVMFunctionType::get(voidType, {}, /*isVarArg=*/false);
    auto entryFunc = LLVM::LLVMFuncOp::create(
        rewriter, loc, entry_name, funcType, LLVM::Linkage::External);

    auto *block = rewriter.createBlock(&entryFunc.getBody());
    rewriter.setInsertionPointToStart(block);
    LLVM::ReturnOp::create(rewriter, loc, ValueRange{});

    rewriter.eraseOp(op);
    return success();
  }
};

struct ModuleOpLowering : public OpConversionPattern<ocaml::ModuleOp> {
  using OpConversionPattern<ocaml::ModuleOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(ocaml::ModuleOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    for (auto &block : op.getBody()) {
      if (!block.empty()) {
        return rewriter.notifyMatchFailure(op, "module body not empty");
      }
    }

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
    {
      ConversionTarget target(*context);
      target.addLegalDialect<LLVM::LLVMDialect>();
      target.addLegalDialect<ocaml::OCamlDialect>();
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
      patterns.add<ModuleOpLowering>(context);

      if (failed(applyPartialConversion(module, target, std::move(patterns)))) {
        signalPassFailure();
        return;
      }
    }
  }
};

} // namespace
