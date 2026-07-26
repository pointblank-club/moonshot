#include "OCaml/OCamlDialect.h"

#include <memory>

#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/Transforms/DialectConversion.h"

#include "llvm/ADT/SmallVector.h"

using namespace mlir;

namespace {

/// Finds the target symbol name for an external OCaml declaration.
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

/// Assures the presence of an LLVM function declaration in the parent module.
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

/// Dereferences the pointer value if it is boxed, otherwise returns it.
Value getValue(ConversionPatternRewriter &rewriter, Location loc, Value val) {
  if (llvm::isa<LLVM::LLVMPointerType>(val.getType())) {
    return LLVM::LoadOp::create(rewriter, loc, rewriter.getF64Type(), val);
  }
  return val;
}

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

struct ExternCallOpLowering : public OpConversionPattern<ocaml::ExternCallOp> {
  using OpConversionPattern<ocaml::ExternCallOp>::OpConversionPattern;

  // TODO: extern_call should be calling `caml_c_call`, by passing the target
  // pointer to %rax, but for now we just lower it to a direct call.
  ExternCallOpLowering(const TypeConverter &typeConverter, MLIRContext *context)
      : OpConversionPattern<ocaml::ExternCallOp>(typeConverter, context) {}

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
    Type resultType = getTypeConverter()->convertType(op.getType());
    auto targetType = LLVM::LLVMFunctionType::get(resultType, argTypes, false);
    OpBuilder::InsertionGuard guard(rewriter);
    rewriter.setInsertionPoint(parent_module);
    auto targetFunc =
        ensureFunction(rewriter, op.getLoc(), *target, targetType);

    rewriter.setInsertionPoint(op);
    Location loc = op.getLoc();

    SmallVector<Value> callArgs;
    // TODO: Use 0 i64s for r12/r14/r15 for now.
    auto zeroConst = LLVM::ConstantOp::create(rewriter, loc, i64Type, 0ULL);
    callArgs.push_back(zeroConst); // R14
    callArgs.push_back(zeroConst); // R15

    auto ptrType = LLVM::LLVMPointerType::get(rewriter.getContext());
    auto addrOf =
        LLVM::AddressOfOp::create(rewriter, loc, ptrType, targetFunc.getName());
    callArgs.push_back(addrOf); // RAX

    callArgs.push_back(zeroConst); // R12

    callArgs.append(args.begin(), args.end()); // C args

    auto cCallDeclType = LLVM::LLVMFunctionType::get(
        i64Type, {i64Type, i64Type, ptrType, i64Type}, false);
    rewriter.setInsertionPoint(parent_module);
    auto cCallFunc =
        ensureFunction(rewriter, loc, "caml_c_call", cCallDeclType);

    rewriter.setInsertionPoint(op);
    auto cCallAddr =
        LLVM::AddressOfOp::create(rewriter, loc, ptrType, cCallFunc.getName());

    SmallVector<Value> operands;
    operands.push_back(cCallAddr.getResult());
    operands.append(callArgs.begin(), callArgs.end());

    auto callOp = LLVM::CallOp::create(rewriter, loc, TypeRange{i64Type},
                                       ValueRange{operands});
    SmallVector<int32_t> segmentSizes = {static_cast<int32_t>(operands.size()),
                                         0};
    callOp->setAttr("operandSegmentSizes",
                    rewriter.getDenseI32ArrayAttr(segmentSizes));
    callOp->setAttr("op_bundle_sizes", rewriter.getDenseI32ArrayAttr({}));

    Value result = callOp.getResult();
    if (resultType != i64Type) {
      if (llvm::isa<LLVM::LLVMPointerType>(resultType)) {
        result = LLVM::IntToPtrOp::create(rewriter, loc, resultType, result);
      } else {
        result = LLVM::BitcastOp::create(rewriter, loc, resultType, result);
      }
    }

    rewriter.replaceOp(op, result);
    return success();
  }
};

struct ExternOpLowering : public OpConversionPattern<ocaml::ExternOp> {
  using OpConversionPattern<ocaml::ExternOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(ocaml::ExternOp op, OpAdaptor,
                  ConversionPatternRewriter &rewriter) const override {
    rewriter.eraseOp(op);
    return success();
  }
};

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

    rewriter.eraseOp(op);
    return success();
  }
};

struct ConstantOpLowering : public OpConversionPattern<ocaml::ConstantOp> {
  using OpConversionPattern<ocaml::ConstantOp>::OpConversionPattern;

  ConstantOpLowering(const TypeConverter &typeConverter, MLIRContext *context,
                     std::shared_ptr<ocaml::LoweringState> state)
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
  std::shared_ptr<ocaml::LoweringState> state;
};

struct BinOpLowering : public OpConversionPattern<ocaml::BinOp> {
  using OpConversionPattern<ocaml::BinOp>::OpConversionPattern;

  BinOpLowering(const TypeConverter &typeConverter, MLIRContext *context,
                std::shared_ptr<ocaml::LoweringState> state)
      : OpConversionPattern<ocaml::BinOp>(typeConverter, context),
        state(std::move(state)) {}

  LogicalResult
  matchAndRewrite(ocaml::BinOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    Location loc = op.getLoc();
    StringRef opName = op.getOpName();
    Value lhs = getValue(rewriter, loc, adaptor.getLhs());
    Value rhs = getValue(rewriter, loc, adaptor.getRhs());
    bool isFloat = llvm::isa<ocaml::FloatType>(op.getLhs().getType());

    if (isFloat) {
      auto f64Type = rewriter.getF64Type();
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

      auto parent_module = op->template getParentOfType<ocaml::ModuleOp>();
      if (!parent_module)
        return failure();
      auto i64Type = rewriter.getI64Type();
      auto copyType = LLVM::LLVMFunctionType::get(i64Type, {f64Type}, false);
      if (!state->copyDoubleDeclared) {
        OpBuilder::InsertionGuard guard(rewriter);
        rewriter.setInsertionPoint(parent_module);
        LLVM::LLVMFuncOp::create(rewriter, loc, "caml_copy_double", copyType,
                                 LLVM::Linkage::External);
        state->copyDoubleDeclared = true;
      }
      auto boxed = LLVM::CallOp::create(
          rewriter, loc, copyType, "caml_copy_double", ValueRange{computed});
      auto ptrType = LLVM::LLVMPointerType::get(op.getContext());
      auto asPtr =
          LLVM::IntToPtrOp::create(rewriter, loc, ptrType, boxed.getResult());
      rewriter.replaceOp(op, asPtr.getResult());
      return success();
    } else {
      auto i64Type = rewriter.getI64Type();
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
        auto div = LLVM::SDivOp::create(rewriter, loc, i64Type,
                                        lhsUntagged.getResult(),
                                        rhsUntagged.getResult());
        auto divShifted = LLVM::ShlOp::create(rewriter, loc, i64Type,
                                              div.getResult(), one.getResult());
        auto res = LLVM::AddOp::create(rewriter, loc, i64Type,
                                       divShifted.getResult(), one.getResult());
        rewriter.replaceOp(op, res.getResult());
        return success();
      } else if (opName == "land") {
        auto res = LLVM::AndOp::create(rewriter, loc, i64Type, lhs, rhs);
        rewriter.replaceOp(op, res.getResult());
        return success();
      } else if (opName == "lor") {
        auto res = LLVM::OrOp::create(rewriter, loc, i64Type, lhs, rhs);
        rewriter.replaceOp(op, res.getResult());
        return success();
      } else if (opName == "lxor") {
        auto one = LLVM::ConstantOp::create(rewriter, loc, i64Type, 1ULL);
        auto xored = LLVM::XOrOp::create(rewriter, loc, i64Type, lhs, rhs);
        auto res = LLVM::OrOp::create(rewriter, loc, i64Type, xored.getResult(),
                                      one.getResult());
        rewriter.replaceOp(op, res.getResult());
        return success();
      } else if (opName == "lsl") {
        auto one = LLVM::ConstantOp::create(rewriter, loc, i64Type, 1ULL);
        auto count =
            LLVM::AShrOp::create(rewriter, loc, i64Type, rhs, one.getResult());
        auto lhsUntagged =
            LLVM::SubOp::create(rewriter, loc, i64Type, lhs, one.getResult());
        auto shifted = LLVM::ShlOp::create(
            rewriter, loc, i64Type, lhsUntagged.getResult(), count.getResult());
        auto res = LLVM::OrOp::create(rewriter, loc, i64Type,
                                      shifted.getResult(), one.getResult());
        rewriter.replaceOp(op, res.getResult());
        return success();
      } else if (opName == "lsr" || opName == "asr") {
        auto one = LLVM::ConstantOp::create(rewriter, loc, i64Type, 1ULL);
        auto count =
            LLVM::AShrOp::create(rewriter, loc, i64Type, rhs, one.getResult());
        Value lhsUntagged = opName == "lsr"
                                ? LLVM::LShrOp::create(rewriter, loc, i64Type,
                                                       lhs, one.getResult())
                                      .getResult()
                                : LLVM::AShrOp::create(rewriter, loc, i64Type,
                                                       lhs, one.getResult())
                                      .getResult();
        Value shifted =
            opName == "lsr"
                ? LLVM::LShrOp::create(rewriter, loc, i64Type, lhsUntagged,
                                       count.getResult())
                      .getResult()
                : LLVM::AShrOp::create(rewriter, loc, i64Type, lhsUntagged,
                                       count.getResult())
                      .getResult();
        auto retagged = LLVM::ShlOp::create(rewriter, loc, i64Type, shifted,
                                            one.getResult());
        auto res = LLVM::OrOp::create(rewriter, loc, i64Type,
                                      retagged.getResult(), one.getResult());
        rewriter.replaceOp(op, res.getResult());
        return success();
      }
      return failure();
    }
  }

private:
  std::shared_ptr<ocaml::LoweringState> state;
};

struct CmpOpLowering : public OpConversionPattern<ocaml::CmpOp> {
  using OpConversionPattern<ocaml::CmpOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(ocaml::CmpOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    Location loc = op.getLoc();
    StringRef predicateStr = op.getPredicate();
    Value lhs = getValue(rewriter, loc, adaptor.getLhs());
    Value rhs = getValue(rewriter, loc, adaptor.getRhs());
    bool isFloat = llvm::isa<ocaml::FloatType>(op.getLhs().getType());

    Value cmpResult;
    if (isFloat) {
      LLVM::FCmpPredicate pred;
      if (predicateStr == "lt") {
        pred = LLVM::FCmpPredicate::olt;
      } else if (predicateStr == "gt") {
        pred = LLVM::FCmpPredicate::ogt;
      } else if (predicateStr == "le") {
        pred = LLVM::FCmpPredicate::ole;
      } else if (predicateStr == "ge") {
        pred = LLVM::FCmpPredicate::oge;
      } else if (predicateStr == "eq") {
        pred = LLVM::FCmpPredicate::oeq;
      } else if (predicateStr == "ne") {
        pred = LLVM::FCmpPredicate::une;
      } else {
        return rewriter.notifyMatchFailure(op, "unknown float cmp predicate");
      }
      auto cmp = LLVM::FCmpOp::create(rewriter, loc, pred, lhs, rhs);
      cmpResult = cmp.getResult();
    } else {
      LLVM::ICmpPredicate pred;
      if (predicateStr == "lt") {
        pred = LLVM::ICmpPredicate::slt;
      } else if (predicateStr == "gt") {
        pred = LLVM::ICmpPredicate::sgt;
      } else if (predicateStr == "le") {
        pred = LLVM::ICmpPredicate::sle;
      } else if (predicateStr == "ge") {
        pred = LLVM::ICmpPredicate::sge;
      } else if (predicateStr == "eq") {
        pred = LLVM::ICmpPredicate::eq;
      } else if (predicateStr == "ne") {
        pred = LLVM::ICmpPredicate::ne;
      } else {
        return rewriter.notifyMatchFailure(op, "unknown cmp predicate");
      }
      auto cmp = LLVM::ICmpOp::create(rewriter, loc, pred, lhs, rhs);
      cmpResult = cmp.getResult();
    }

    auto i64Type = rewriter.getI64Type();
    auto trueVal = LLVM::ConstantOp::create(rewriter, loc, i64Type, 3ULL);
    auto falseVal = LLVM::ConstantOp::create(rewriter, loc, i64Type, 1ULL);
    auto select = LLVM::SelectOp::create(
        rewriter, loc, cmpResult, trueVal.getResult(), falseVal.getResult());
    rewriter.replaceOp(op, select.getResult());
    return success();
  }
};

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

/// Populates the rewrite pattern set with lowering patterns for OCaml
/// operations.
void ocaml::populateOcamlOpsPatterns(
    RewritePatternSet &patterns, const TypeConverter &typeConverter,
    MLIRContext *context, std::shared_ptr<ocaml::LoweringState> state) {
  patterns.add<EntryOpLowering>(context);
  patterns.add<ExternCallOpLowering>(typeConverter, context);
  patterns.add<ExternOpLowering>(context);
  patterns.add<ModuleOpLowering>(context);
  patterns.add<ConstantOpLowering>(typeConverter, context, state);
  patterns.add<BinOpLowering>(typeConverter, context, state);
  patterns.add<CmpOpLowering, AndOpLowering, OrOpLowering, NotOpLowering>(
      typeConverter, context);
}
