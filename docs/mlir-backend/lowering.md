# Lowering Implementation

This page covers the C++ implementation of the custom OCaml dialect and its lowering passes. It is aimed at contributors who want to modify the dialect or add new operations.

## File layout

```
backend/mlir/lowering/
  CMakeLists.txt              CMake configuration
  include/OCaml/
    OCamlDialect.h            Dialect declaration
    OCamlDialect.td           TableGen dialect definition
    OCamlOps.td               TableGen operation definitions
    Passes.h                  Pass declarations
    Passes.td                 TableGen pass definitions
  lib/
    OCamlDialect.cpp          Dialect implementation
    OcamlInit.cpp             Dialect initialization + pass registration
    OcamlLowering.cpp         Lowering patterns
    OcamlLoweringTypes.cpp    Type conversion
```

## Dialect registration

The dialect is registered in `OcamlInit.cpp`:

```cpp
#include "mlir/IR/Dialect.h"
#include "OCaml/OCamlDialect.h"

void ocaml::registerOcamlDialect(mlir::MLIRContext *context) {
  context->loadDialect<ocaml::OCamlDialect>();
}
```

The pass is registered as a `mlir-opt` plugin:

```cpp
#include "mlir/Tools/mlir-opt/MlirOptMain.h"

int main(int argc, char **argv) {
  mlir::DialectRegistry registry;
  registry.insert<ocaml::OCamlDialect>();
  ocaml::registerConvertOcamlToBuiltin();
  return mlir::MlirOptMain(argc, argv, "OCaml dialect optimizer", registry);
}
```

## TableGen definitions

The dialect and ops are partially defined using MLIR's TableGen system. The `.td` files are in `include/OCaml/`.

### Dialect definition (`OCamlDialect.td`)

```tablegen
def OCamlDialect : Dialect {
  let name = "ocaml";
  let summary = "OCaml-specific dialect for Moonshot";
  let description = [{
    This dialect captures high-level OCaml constructs before lowering
    to standard MLIR dialects like arith, func, scf, and llvm.
  }];
  let cppNamespace = "ocaml";
}
```

### Operation definition (`OCamlOps.td`)

```tablegen
def OCamlIntOp : Op<OCamlDialect, "int", [Pure]> {
  let summary = "OCaml integer constant";
  let arguments = (ins I64Attr:$value);
  let results = (outs OCamlIntType:$result);
  let assemblyFormat = "attr-dict `:` type($result)";
}
```

## Lowering patterns

The lowering is implemented using MLIR's `ConversionPattern` system. Each OCaml op has a corresponding pattern class.

### Entry op lowering

```cpp
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
```

### Int op lowering

```cpp
struct IntOpLowering : public OpConversionPattern<ocaml::IntOp> {
  using OpConversionPattern<ocaml::IntOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(ocaml::IntOp op, OpAdaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto loc = op.getLoc();
    int64_t value = op.getValue();
    // Tag the integer: value * 2 + 1
    int64_t tagged = (value << 1) | 1;
    auto i64Type = rewriter.getI64Type();
    Value constant = rewriter.create<arith::ConstantOp>(
        loc, rewriter.getI64IntegerAttr(tagged));
    rewriter.replaceOp(op, constant);
    return success();
  }
};
```

### Binop lowering

```cpp
struct BinopOpLowering : public OpConversionPattern<ocaml::BinopOp> {
  using OpConversionPattern<ocaml::BinopOp>::OpConversionPattern;

  LogicalResult
  matchAndRewrite(ocaml::BinopOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    auto loc = op.getLoc();
    std::string opName = op.getOpName().str();
    Value lhs = adaptor.getLhs();
    Value rhs = adaptor.getRhs();

    // Untag operands
    Value one = rewriter.create<arith::ConstantOp>(
        loc, rewriter.getI64IntegerAttr(1));
    Value lhs_untag = rewriter.create<arith::SubIOp>(loc, lhs, one);
    Value rhs_untag = rewriter.create<arith::SubIOp>(loc, rhs, one);

    // Shift right by 1
    Value lhs_val = rewriter.create<arith::ShRUIOp>(loc, lhs_untag, one);
    Value rhs_val = rewriter.create<arith::ShRUIOp>(loc, rhs_untag, one);

    // Perform operation
    Value result;
    if (opName == "+") {
      result = rewriter.create<arith::AddIOp>(loc, lhs_val, rhs_val);
    } else if (opName == "-") {
      result = rewriter.create<arith::SubIOp>(loc, lhs_val, rhs_val);
    } else if (opName == "*") {
      result = rewriter.create<arith::MulIOp>(loc, lhs_val, rhs_val);
    } else if (opName == "/") {
      result = rewriter.create<arith::DivSIOp>(loc, lhs_val, rhs_val);
    } else {
      return rewriter.notifyMatchFailure(op, "unsupported binop");
    }

    // Retag result
    Value result_tagged = rewriter.create<arith::AddIOp>(loc, result, one);
    rewriter.replaceOp(op, result_tagged);
    return success();
  }
};
```

## Type conversion

Type conversion is handled by `OcamlLoweringTypes.cpp`:

```cpp
class OcamlTypeConverter : public TypeConverter {
public:
  OcamlTypeConverter(MLIRContext *context) {
    addConversion([](ocaml::IntType type) -> Type {
      return IntegerType::get(type.getContext(), 64);
    });
    addConversion([](ocaml::StringType type) -> Type {
      return LLVM::LLVMPointerType::get(type.getContext());
    });
    addConversion([](ocaml::ValueType type) -> Type {
      return LLVM::LLVMPointerType::get(type.getContext());
    });
  }
};
```

## Building the dialect

```bash
# From the moonshot root
make mlir-dialect
```

This runs:

```bash
cmake -S backend/mlir/lowering -B backend/mlir/lowering/build \
  -DMLIR_DIR=/usr/lib/llvm-22/lib/cmake/mlir
ninja -C backend/mlir/lowering/build
```

## Testing the dialect

You can test the lowering pass manually:

```bash
# Create a test MLIR file
cat > test.mlir << 'EOF'
ocaml.module @Test {
  ocaml.entry {
    %0 = ocaml.int 4 : !ocaml.int
    %1 = ocaml.int 3 : !ocaml.int
    %2 = ocaml.binop "+" %0, %1 : !ocaml.int, !ocaml.int -> !ocaml.int
  }
}
EOF

# Run the custom lowering
/usr/lib/llvm-22/bin/mlir-opt \
  --load-dialect-plugin=backend/mlir/lowering/build/libOCamlDialect.so \
  --convert-ocaml-to-arith \
  test.mlir
```

## Next steps

- [Dialect reference](dialects.md) — operation definitions
- [Pipeline](pipeline.md) — the full lowering sequence
- [Contributing](../developer/contributing.md) — how to add new ops
