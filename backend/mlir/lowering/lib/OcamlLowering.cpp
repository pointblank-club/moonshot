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

struct ConvertOCamlToBuiltin
    : public ::ocaml::impl::ConvertOCamlToBuiltinBase<ConvertOCamlToBuiltin> {
  void runOnOperation() override {
    ModuleOp module = getOperation();
    MLIRContext *context = &getContext();
    TypeConverter typeConverter;
    auto ptrType = LLVM::LLVMPointerType::get(context);
    auto i64Type = IntegerType::get(context, 64);
    typeConverter.addConversion([&](Type type) -> Type {
      if (llvm::isa<ocaml::BoxedTypeInterface>(type)) {
        return ptrType;
      }
      if (llvm::isa<ocaml::UnboxedTypeInterface>(type)) {
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
          if (opaque.getTypeData() == "unit") {
            return i64Type;
          }
        }
      }
      return type;
    });

    auto loweringState = std::make_shared<ocaml::LoweringState>();
    {
      ConversionTarget target(*context);
      target.addLegalDialect<LLVM::LLVMDialect>();
      target.addLegalOp<ocaml::ModuleOp, ocaml::ExternOp, ocaml::EntryOp>();
      target.addIllegalOp<ocaml::ConstantOp, ocaml::ExternCallOp, ocaml::BinOp,
                          ocaml::CmpOp, ocaml::AndOp, ocaml::OrOp, ocaml::NotOp,
                          ocaml::FunctionOp, ocaml::ReturnOp, ocaml::CallOp>();

      RewritePatternSet patterns(context);
      ocaml::populateOcamlOpsPatterns(patterns, typeConverter, context,
                                      loweringState);

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
      ocaml::populateOcamlOpsPatterns(patterns, typeConverter, context,
                                      loweringState);

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
      ocaml::populateOcamlOpsPatterns(patterns, typeConverter, context,
                                      loweringState);

      if (failed(applyPartialConversion(module, target, std::move(patterns)))) {
        signalPassFailure();
        return;
      }
    }
  }
};

} // namespace
