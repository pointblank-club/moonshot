// All ocaml.* ops parse, verify, and print canonically.

func.func @cst() -> i64 {
  %c = ocaml.constant 42
  return %c : i64
}

func.func @arith(%a: i64, %b: i64) -> i64 {
  %1 = ocaml.addi %a, %b : i64
  %2 = ocaml.subi %1, %b : i64
  %3 = ocaml.muli %2, %b : i64
  %4 = ocaml.divi %3, %b : i64
  %5 = ocaml.modi %4, %b : i64
  return %5 : i64
}

func.func @cmp(%a: i64, %b: i64) -> i1 {
  %eq  = ocaml.cmpi eq,  %a, %b : i64
  %ne  = ocaml.cmpi ne,  %a, %b : i64
  %slt = ocaml.cmpi slt, %a, %b : i64
  %sle = ocaml.cmpi sle, %a, %b : i64
  %sgt = ocaml.cmpi sgt, %a, %b : i64
  %sge = ocaml.cmpi sge, %a, %b : i64
  return %eq : i1
}
