open Helpers

let%expect_test "arithmetic" =
  let t =
    test_compile ~name:"arith"
      ~code:
        "\n\
        \    external ( + ) : int -> int -> int = \"%addint\"\n\
        \    external ( * ) : int -> int -> int = \"%mulint\"\n\
        \    let res = 1 + 2 * 3\n\
        \  "
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Arith {
      ocaml.entry {
        %0 = ocaml.constant 1 : !ocaml.int loc(#loc1)
        %1 = ocaml.constant 2 : !ocaml.int loc(#loc2)
        %2 = ocaml.constant 3 : !ocaml.int loc(#loc3)
        %3 = ocaml.binop "*" %1, %2 : !ocaml.int, !ocaml.int -> !ocaml.int loc(#loc2)
        %4 = ocaml.binop "+" %0, %3 : !ocaml.int, !ocaml.int -> !ocaml.int loc(#loc1)
      } loc(#loc)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("arith.ml":4:15)
    #loc2 = loc("arith.ml":4:19)
    #loc3 = loc("arith.ml":4:23)
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.func @camlArith__entry() -> i64 {
        %0 = llvm.mlir.constant(3 : i64) : i64
        %1 = llvm.mlir.constant(5 : i64) : i64
        %2 = llvm.mlir.constant(7 : i64) : i64
        %3 = llvm.mlir.constant(1 : i64) : i64
        %4 = llvm.sub %1, %3 : i64
        %5 = llvm.ashr %2, %3 : i64
        %6 = llvm.mul %4, %5 : i64
        %7 = llvm.add %6, %3 : i64
        %8 = llvm.add %0, %7 : i64
        %9 = llvm.mlir.constant(1 : i64) : i64
        %10 = llvm.sub %8, %9 : i64
        %11 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %11 : i64
      }
      llvm.mlir.global external @camlArith__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlArith__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlArith__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlArith__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlArith__code_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlArith__frametable(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'arith.ml'
    source_filename = "arith.ml"

    @camlArith__gc_roots = global i64 0
    @camlArith__data_begin = global i64 0
    @camlArith__data_end = global i64 0
    @camlArith__code_begin = global i64 0
    @camlArith__code_end = global i64 0
    @camlArith__frametable = global i64 0

    define i64 @camlArith__entry() {
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}]
