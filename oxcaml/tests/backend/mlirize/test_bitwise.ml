open Helpers

let%expect_test "bitwise and shift" =
  let t =
    test_compile ~name:"bitwise"
      ~code:
        {|
    external ( land ) : int -> int -> int = "%andint"
    external ( lor ) : int -> int -> int = "%orint"
    external ( lxor ) : int -> int -> int = "%xorint"
    external ( lsl ) : int -> int -> int = "%lslint"
    external ( lsr ) : int -> int -> int = "%lsrint"
    external ( asr ) : int -> int -> int = "%asrint"
    let a = 12 land 10
    let b = 12 lor 10
    let c = 12 lxor 10
    let d = 1 lsl 4
    let e = 64 lsr 2
    let f = -64 asr 2
    |}
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Bitwise {
      ocaml.entry {
        %0 = ocaml.constant 12 : !ocaml.int loc(#loc1)
        %1 = ocaml.constant 10 : !ocaml.int loc(#loc2)
        %2 = ocaml.binop "land" %0, %1 : !ocaml.int, !ocaml.int -> !ocaml.int loc(#loc1)
        %3 = ocaml.constant 12 : !ocaml.int loc(#loc3)
        %4 = ocaml.constant 10 : !ocaml.int loc(#loc4)
        %5 = ocaml.binop "lor" %3, %4 : !ocaml.int, !ocaml.int -> !ocaml.int loc(#loc3)
        %6 = ocaml.constant 12 : !ocaml.int loc(#loc5)
        %7 = ocaml.constant 10 : !ocaml.int loc(#loc6)
        %8 = ocaml.binop "lxor" %6, %7 : !ocaml.int, !ocaml.int -> !ocaml.int loc(#loc5)
        %9 = ocaml.constant 1 : !ocaml.int loc(#loc7)
        %10 = ocaml.constant 4 : !ocaml.int loc(#loc8)
        %11 = ocaml.binop "lsl" %9, %10 : !ocaml.int, !ocaml.int -> !ocaml.int loc(#loc7)
        %12 = ocaml.constant 64 : !ocaml.int loc(#loc9)
        %13 = ocaml.constant 2 : !ocaml.int loc(#loc10)
        %14 = ocaml.binop "lsr" %12, %13 : !ocaml.int, !ocaml.int -> !ocaml.int loc(#loc9)
        %15 = ocaml.constant -64 : !ocaml.int loc(#loc11)
        %16 = ocaml.constant 2 : !ocaml.int loc(#loc12)
        %17 = ocaml.binop "asr" %15, %16 : !ocaml.int, !ocaml.int -> !ocaml.int loc(#loc11)
      } loc(#loc)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("bitwise.ml":8:13)
    #loc2 = loc("bitwise.ml":8:21)
    #loc3 = loc("bitwise.ml":9:13)
    #loc4 = loc("bitwise.ml":9:20)
    #loc5 = loc("bitwise.ml":10:13)
    #loc6 = loc("bitwise.ml":10:21)
    #loc7 = loc("bitwise.ml":11:13)
    #loc8 = loc("bitwise.ml":11:19)
    #loc9 = loc("bitwise.ml":12:13)
    #loc10 = loc("bitwise.ml":12:20)
    #loc11 = loc("bitwise.ml":13:13)
    #loc12 = loc("bitwise.ml":13:21)
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.func @camlBitwise__entry() -> i64 {
        %0 = llvm.mlir.constant(25 : i64) : i64
        %1 = llvm.mlir.constant(21 : i64) : i64
        %2 = llvm.and %0, %1 : i64
        %3 = llvm.mlir.constant(25 : i64) : i64
        %4 = llvm.mlir.constant(21 : i64) : i64
        %5 = llvm.or %3, %4 : i64
        %6 = llvm.mlir.constant(25 : i64) : i64
        %7 = llvm.mlir.constant(21 : i64) : i64
        %8 = llvm.mlir.constant(1 : i64) : i64
        %9 = llvm.xor %6, %7 : i64
        %10 = llvm.or %9, %8 : i64
        %11 = llvm.mlir.constant(3 : i64) : i64
        %12 = llvm.mlir.constant(9 : i64) : i64
        %13 = llvm.mlir.constant(1 : i64) : i64
        %14 = llvm.ashr %12, %13 : i64
        %15 = llvm.sub %11, %13 : i64
        %16 = llvm.shl %15, %14 : i64
        %17 = llvm.or %16, %13 : i64
        %18 = llvm.mlir.constant(129 : i64) : i64
        %19 = llvm.mlir.constant(5 : i64) : i64
        %20 = llvm.mlir.constant(1 : i64) : i64
        %21 = llvm.ashr %19, %20 : i64
        %22 = llvm.lshr %18, %20 : i64
        %23 = llvm.lshr %22, %21 : i64
        %24 = llvm.shl %23, %20 : i64
        %25 = llvm.or %24, %20 : i64
        %26 = llvm.mlir.constant(-127 : i64) : i64
        %27 = llvm.mlir.constant(5 : i64) : i64
        %28 = llvm.mlir.constant(1 : i64) : i64
        %29 = llvm.ashr %27, %28 : i64
        %30 = llvm.ashr %26, %28 : i64
        %31 = llvm.ashr %30, %29 : i64
        %32 = llvm.shl %31, %28 : i64
        %33 = llvm.or %32, %28 : i64
        %34 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %34 : i64
      }
      llvm.mlir.global external @camlBitwise__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlBitwise__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlBitwise__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlBitwise__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlBitwise__code_end(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}]
