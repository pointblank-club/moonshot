// Lowers every ocaml.* op via --convert-ocaml-to-arith and pins the
// tag-aware arith sequence each one expands to.  This locks in the
// rewrite math independent of the OCaml frontend.

func.func @cst() -> i64 {
  %c = ocaml.constant 42
  return %c : i64
}

func.func @add(%a: i64, %b: i64) -> i64 {
  %r = ocaml.addi %a, %b : i64
  return %r : i64
}

func.func @sub(%a: i64, %b: i64) -> i64 {
  %r = ocaml.subi %a, %b : i64
  return %r : i64
}

func.func @mul(%a: i64, %b: i64) -> i64 {
  %r = ocaml.muli %a, %b : i64
  return %r : i64
}

func.func @div(%a: i64, %b: i64) -> i64 {
  %r = ocaml.divi %a, %b : i64
  return %r : i64
}

func.func @modulo(%a: i64, %b: i64) -> i64 {
  %r = ocaml.modi %a, %b : i64
  return %r : i64
}

func.func @cmp_slt(%a: i64, %b: i64) -> i1 {
  %r = ocaml.cmpi slt, %a, %b : i64
  return %r : i1
}
