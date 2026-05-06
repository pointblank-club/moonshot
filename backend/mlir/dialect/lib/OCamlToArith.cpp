#include "OCaml/OCamlDialect.h"
#include "OCaml/Passes.h"

#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Transforms/GreedyPatternRewriteDriver.h"
#include "mlir/Transforms/DialectConversion.h"

namespace ocaml {

#define GEN_PASS_DEF_CONVERTOCAMLTOARITH
#include "OCaml/Passes.h.inc"

} // namespace ocaml

using namespace mlir;

namespace {

static Value i64Const(OpBuilder &b, Location loc, int64_t v) {
  return arith::ConstantOp::create(b, loc, b.getI64IntegerAttr(v));
}

struct ConstantLowering : OpRewritePattern<::ocaml::ConstantOp> {
  using OpRewritePattern::OpRewritePattern;
  LogicalResult matchAndRewrite(::ocaml::ConstantOp op,
                                PatternRewriter &r) const final {
    int64_t v = (int64_t)op.getValue();
    int64_t tagged = (v << 1) | 1;
    r.replaceOpWithNewOp<arith::ConstantOp>(op, r.getI64IntegerAttr(tagged));
    return success();
  }
};

struct AddILowering : OpRewritePattern<::ocaml::AddIOp> {
  using OpRewritePattern::OpRewritePattern;
  LogicalResult matchAndRewrite(::ocaml::AddIOp op,
                                PatternRewriter &r) const final {
    auto loc = op.getLoc();
    Value sum = arith::AddIOp::create(r, loc, op.getLhs(), op.getRhs());
    Value one = i64Const(r, loc, 1);
    r.replaceOpWithNewOp<arith::SubIOp>(op, sum, one);
    return success();
  }
};

struct SubILowering : OpRewritePattern<::ocaml::SubIOp> {
  using OpRewritePattern::OpRewritePattern;
  LogicalResult matchAndRewrite(::ocaml::SubIOp op,
                                PatternRewriter &r) const final {
    auto loc = op.getLoc();
    Value diff = arith::SubIOp::create(r, loc, op.getLhs(), op.getRhs());
    Value one = i64Const(r, loc, 1);
    r.replaceOpWithNewOp<arith::AddIOp>(op, diff, one);
    return success();
  }
};

struct MulILowering : OpRewritePattern<::ocaml::MulIOp> {
  using OpRewritePattern::OpRewritePattern;
  LogicalResult matchAndRewrite(::ocaml::MulIOp op,
                                PatternRewriter &r) const final {
    auto loc = op.getLoc();
    Value one = i64Const(r, loc, 1);
    Value lhsU = arith::ShRSIOp::create(r, loc, op.getLhs(), one);
    Value rhsM1 = arith::SubIOp::create(r, loc, op.getRhs(), one);
    Value prod = arith::MulIOp::create(r, loc, lhsU, rhsM1);
    r.replaceOpWithNewOp<arith::AddIOp>(op, prod, one);
    return success();
  }
};

struct DivILowering : OpRewritePattern<::ocaml::DivIOp> {
  using OpRewritePattern::OpRewritePattern;
  LogicalResult matchAndRewrite(::ocaml::DivIOp op,
                                PatternRewriter &r) const final {
    auto loc = op.getLoc();
    Value one = i64Const(r, loc, 1);
    Value lhsU = arith::ShRSIOp::create(r, loc, op.getLhs(), one);
    Value rhsU = arith::ShRSIOp::create(r, loc, op.getRhs(), one);
    Value q = arith::DivSIOp::create(r, loc, lhsU, rhsU);
    Value shifted = arith::ShLIOp::create(r, loc, q, one);
    r.replaceOpWithNewOp<arith::OrIOp>(op, shifted, one);
    return success();
  }
};

struct ModILowering : OpRewritePattern<::ocaml::ModIOp> {
  using OpRewritePattern::OpRewritePattern;
  LogicalResult matchAndRewrite(::ocaml::ModIOp op,
                                PatternRewriter &r) const final {
    auto loc = op.getLoc();
    Value one = i64Const(r, loc, 1);
    Value lhsU = arith::ShRSIOp::create(r, loc, op.getLhs(), one);
    Value rhsU = arith::ShRSIOp::create(r, loc, op.getRhs(), one);
    Value m = arith::RemSIOp::create(r, loc, lhsU, rhsU);
    Value shifted = arith::ShLIOp::create(r, loc, m, one);
    r.replaceOpWithNewOp<arith::OrIOp>(op, shifted, one);
    return success();
  }
};

struct CmpILowering : OpRewritePattern<::ocaml::CmpIOp> {
  using OpRewritePattern::OpRewritePattern;
  LogicalResult matchAndRewrite(::ocaml::CmpIOp op,
                                PatternRewriter &r) const final {
    arith::CmpIPredicate pred = arith::CmpIPredicate::eq;
    switch (op.getPredicate()) {
    case ::ocaml::CmpIPredicate::eq:  pred = arith::CmpIPredicate::eq;  break;
    case ::ocaml::CmpIPredicate::ne:  pred = arith::CmpIPredicate::ne;  break;
    case ::ocaml::CmpIPredicate::slt: pred = arith::CmpIPredicate::slt; break;
    case ::ocaml::CmpIPredicate::sle: pred = arith::CmpIPredicate::sle; break;
    case ::ocaml::CmpIPredicate::sgt: pred = arith::CmpIPredicate::sgt; break;
    case ::ocaml::CmpIPredicate::sge: pred = arith::CmpIPredicate::sge; break;
    }
    r.replaceOpWithNewOp<arith::CmpIOp>(op, pred, op.getLhs(), op.getRhs());
    return success();
  }
};

struct AddFLowering : OpRewritePattern<::ocaml::AddFOp> {
  using OpRewritePattern::OpRewritePattern;
  LogicalResult matchAndRewrite(::ocaml::AddFOp op,
                                PatternRewriter &r) const final {
    r.replaceOpWithNewOp<arith::AddFOp>(op, op.getLhs(), op.getRhs());
    return success();
  }
};

struct SubFLowering : OpRewritePattern<::ocaml::SubFOp> {
  using OpRewritePattern::OpRewritePattern;
  LogicalResult matchAndRewrite(::ocaml::SubFOp op,
                                PatternRewriter &r) const final {
    r.replaceOpWithNewOp<arith::SubFOp>(op, op.getLhs(), op.getRhs());
    return success();
  }
};

struct MulFLowering : OpRewritePattern<::ocaml::MulFOp> {
  using OpRewritePattern::OpRewritePattern;
  LogicalResult matchAndRewrite(::ocaml::MulFOp op,
                                PatternRewriter &r) const final {
    r.replaceOpWithNewOp<arith::MulFOp>(op, op.getLhs(), op.getRhs());
    return success();
  }
};

struct DivFLowering : OpRewritePattern<::ocaml::DivFOp> {
  using OpRewritePattern::OpRewritePattern;
  LogicalResult matchAndRewrite(::ocaml::DivFOp op,
                                PatternRewriter &r) const final {
    r.replaceOpWithNewOp<arith::DivFOp>(op, op.getLhs(), op.getRhs());
    return success();
  }
};

struct CmpFLowering : OpRewritePattern<::ocaml::CmpFOp> {
  using OpRewritePattern::OpRewritePattern;
  LogicalResult matchAndRewrite(::ocaml::CmpFOp op,
                                PatternRewriter &r) const final {
    arith::CmpFPredicate pred = arith::CmpFPredicate::OEQ;
    switch (op.getPredicate()) {
    case ::ocaml::CmpFPredicate::oeq: pred = arith::CmpFPredicate::OEQ; break;
    case ::ocaml::CmpFPredicate::ogt: pred = arith::CmpFPredicate::OGT; break;
    case ::ocaml::CmpFPredicate::oge: pred = arith::CmpFPredicate::OGE; break;
    case ::ocaml::CmpFPredicate::olt: pred = arith::CmpFPredicate::OLT; break;
    case ::ocaml::CmpFPredicate::ole: pred = arith::CmpFPredicate::OLE; break;
    case ::ocaml::CmpFPredicate::one: pred = arith::CmpFPredicate::ONE; break;
    }
    r.replaceOpWithNewOp<arith::CmpFOp>(op, pred, op.getLhs(), op.getRhs());
    return success();
  }
};

struct ConvertOCamlToArith
    : public ::ocaml::impl::ConvertOCamlToArithBase<ConvertOCamlToArith> {
  void runOnOperation() override {
    auto *ctx = &getContext();
    RewritePatternSet patterns(ctx);
    patterns.add<ConstantLowering, AddILowering, SubILowering, MulILowering,
                 DivILowering, ModILowering, CmpILowering,
                 AddFLowering, SubFLowering, MulFLowering, DivFLowering,
                 CmpFLowering>(ctx);

    ConversionTarget target(*ctx);
    target.addLegalDialect<arith::ArithDialect>();
    target.markUnknownOpDynamicallyLegal([](Operation *) { return true; });
    target.addIllegalDialect<::ocaml::OCamlDialect>();

    if (failed(applyPartialConversion(getOperation(), target,
                                      std::move(patterns))))
      signalPassFailure();
  }
};

} // namespace
