#ifndef OCAML_PASSES_TD
#define OCAML_PASSES_TD

include "mlir/Pass/PassBase.td"

def ConvertOCamlToArith : Pass<"convert-ocaml-to-arith", "::mlir::ModuleOp"> {
  let summary = "Lower the ocaml dialect to arith";
  let description = [{
    Replaces `!ocaml.int` with `i64` and rewrites `ocaml.*` ops to
    tag-aware sequences over `arith`. Tagged representation is
    `T(n) = 2n + 1`, so:

      ocaml.addi a, b  ->  arith.addi (arith.subi (arith.addi a, b), 1)
      ocaml.subi a, b  ->  arith.addi (arith.subi a, b), 1
      ocaml.muli a, b  ->  arith.addi (arith.muli (arith.shrsi a, 1),
                                       (arith.subi b, 1)), 1
      ocaml.divi a, b  ->  tag(arith.divsi(untag a, untag b))
      ocaml.modi a, b  ->  tag(arith.remsi(untag a, untag b))
      ocaml.cmpi p a b ->  arith.cmpi p, a, b
      ocaml.tag x      ->  arith.ori (arith.shli x, 1), 1
      ocaml.untag x    ->  arith.shrsi x, 1
      ocaml.constant n ->  arith.constant (n << 1) | 1
  }];
  let dependentDialects = ["::mlir::arith::ArithDialect"];
}

#endif
