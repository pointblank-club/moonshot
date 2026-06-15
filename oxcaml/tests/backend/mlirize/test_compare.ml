open Helpers

let%expect_test "int comparison" =
  let t =
    test_compile ~name:"compare"
      ~code:
        "\n\
        \    external ( < ) : int -> int -> bool = \"%lessthan\"\n\
        \    external ( > ) : int -> int -> bool = \"%greaterthan\"\n\
        \    external ( <= ) : int -> int -> bool = \"%lessequal\"\n\
        \    external ( >= ) : int -> int -> bool = \"%greaterequal\"\n\
        \    external ( = ) : int -> int -> bool = \"%equal\"\n\
        \    external ( <> ) : int -> int -> bool = \"%notequal\"\n\
        \    let lt = 2 < 9\n\
        \    let gt = 7 > 3\n\
        \    let le = 2 <= 9\n\
        \    let ge = 7 >= 3\n\
        \    let eq = 4 = 4\n\
        \    let ne = 4 <> 9\n\
        \  "
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Compare {
      ocaml.entry {
        %0 = ocaml.constant 2 : !ocaml.int
        %1 = ocaml.constant 9 : !ocaml.int
        %2 = ocaml.cmp "lt" %0, %1 : !ocaml.int -> !ocaml.bool
        %3 = ocaml.constant 7 : !ocaml.int
        %4 = ocaml.constant 3 : !ocaml.int
        %5 = ocaml.cmp "gt" %3, %4 : !ocaml.int -> !ocaml.bool
        %6 = ocaml.constant 2 : !ocaml.int
        %7 = ocaml.constant 9 : !ocaml.int
        %8 = ocaml.cmp "le" %6, %7 : !ocaml.int -> !ocaml.bool
        %9 = ocaml.constant 7 : !ocaml.int
        %10 = ocaml.constant 3 : !ocaml.int
        %11 = ocaml.cmp "ge" %9, %10 : !ocaml.int -> !ocaml.bool
        %12 = ocaml.constant 4 : !ocaml.int
        %13 = ocaml.constant 4 : !ocaml.int
        %14 = ocaml.cmp "eq" %12, %13 : !ocaml.int -> !ocaml.bool
        %15 = ocaml.constant 4 : !ocaml.int
        %16 = ocaml.constant 9 : !ocaml.int
        %17 = ocaml.cmp "ne" %15, %16 : !ocaml.int -> !ocaml.bool
      }
    }
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.func @camlCompare__entry() -> i64 {
        %0 = llvm.mlir.constant(5 : i64) : i64
        %1 = llvm.mlir.constant(19 : i64) : i64
        %2 = llvm.icmp "slt" %0, %1 : i64
        %3 = llvm.mlir.constant(3 : i64) : i64
        %4 = llvm.mlir.constant(1 : i64) : i64
        %5 = llvm.select %2, %3, %4 : i1, i64
        %6 = llvm.mlir.constant(15 : i64) : i64
        %7 = llvm.mlir.constant(7 : i64) : i64
        %8 = llvm.icmp "sgt" %6, %7 : i64
        %9 = llvm.mlir.constant(3 : i64) : i64
        %10 = llvm.mlir.constant(1 : i64) : i64
        %11 = llvm.select %8, %9, %10 : i1, i64
        %12 = llvm.mlir.constant(5 : i64) : i64
        %13 = llvm.mlir.constant(19 : i64) : i64
        %14 = llvm.icmp "sle" %12, %13 : i64
        %15 = llvm.mlir.constant(3 : i64) : i64
        %16 = llvm.mlir.constant(1 : i64) : i64
        %17 = llvm.select %14, %15, %16 : i1, i64
        %18 = llvm.mlir.constant(15 : i64) : i64
        %19 = llvm.mlir.constant(7 : i64) : i64
        %20 = llvm.icmp "sge" %18, %19 : i64
        %21 = llvm.mlir.constant(3 : i64) : i64
        %22 = llvm.mlir.constant(1 : i64) : i64
        %23 = llvm.select %20, %21, %22 : i1, i64
        %24 = llvm.mlir.constant(9 : i64) : i64
        %25 = llvm.mlir.constant(9 : i64) : i64
        %26 = llvm.icmp "eq" %24, %25 : i64
        %27 = llvm.mlir.constant(3 : i64) : i64
        %28 = llvm.mlir.constant(1 : i64) : i64
        %29 = llvm.select %26, %27, %28 : i1, i64
        %30 = llvm.mlir.constant(9 : i64) : i64
        %31 = llvm.mlir.constant(19 : i64) : i64
        %32 = llvm.icmp "ne" %30, %31 : i64
        %33 = llvm.mlir.constant(3 : i64) : i64
        %34 = llvm.mlir.constant(1 : i64) : i64
        %35 = llvm.select %32, %33, %34 : i1, i64
        %36 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %36 : i64
      }
      llvm.mlir.global external @camlCompare__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlCompare__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlCompare__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlCompare__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlCompare__code_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlCompare__frametable(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'LLVMDialectModule'
    source_filename = "LLVMDialectModule"

    @camlCompare__gc_roots = global i64 0
    @camlCompare__data_begin = global i64 0
    @camlCompare__data_end = global i64 0
    @camlCompare__code_begin = global i64 0
    @camlCompare__code_end = global i64 0
    @camlCompare__frametable = global i64 0

    define i64 @camlCompare__entry() {
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}];;

let%expect_test "if-then-else basic" =
  let t =
    test_compile ~name:"if_then_else_basic"
      ~code:
        "\n\
        \    external ( < ) : int -> int -> bool = \"%lessthan\"\n\
        \    let x = if 3 < 5 then 10 else 20\n\
        \  "
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @If_then_else_basic {
      ocaml.entry {
        %0 = ocaml.constant 3 : !ocaml.int
        %1 = ocaml.constant 5 : !ocaml.int
        %2 = ocaml.cmp "lt" %0, %1 : !ocaml.int -> !ocaml.bool
        %3 = ocaml.if_then_else %2 : !ocaml.bool -> !ocaml.int {
          %4 = ocaml.constant 10 : !ocaml.int
          ocaml.yield %4 : !ocaml.int
        } else {
          %4 = ocaml.constant 20 : !ocaml.int
          ocaml.yield %4 : !ocaml.int
        }
      }
    }
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.func @camlIf_then_else_basic__entry() -> i64 {
        %0 = llvm.mlir.constant(7 : i64) : i64
        %1 = llvm.mlir.constant(11 : i64) : i64
        %2 = llvm.icmp "slt" %0, %1 : i64
        %3 = llvm.zext %2 : i1 to i64
        %4 = llvm.mlir.constant(1 : i64) : i64
        %5 = llvm.shl %3, %4 : i64
        %6 = llvm.or %5, %4 : i64
        %7 = llvm.mlir.constant(3 : i64) : i64
        %8 = llvm.icmp "eq" %6, %7 : i64
        llvm.cond_br %8, ^bb1, ^bb2
      ^bb1:  // pred: ^bb0
        %9 = llvm.mlir.constant(21 : i64) : i64
        llvm.br ^bb3(%9 : i64)
      ^bb2:  // pred: ^bb0
        %10 = llvm.mlir.constant(41 : i64) : i64
        llvm.br ^bb3(%10 : i64)
      ^bb3(%11: i64):  // 2 preds: ^bb1, ^bb2
        %12 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %12 : i64
      }
      llvm.mlir.global external @camlIf_then_else_basic__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_else_basic__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_else_basic__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_else_basic__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_else_basic__code_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_else_basic__frametable(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'LLVMDialectModule'
    source_filename = "LLVMDialectModule"

    @camlIf_then_else_basic__gc_roots = global i64 0
    @camlIf_then_else_basic__data_begin = global i64 0
    @camlIf_then_else_basic__data_end = global i64 0
    @camlIf_then_else_basic__code_begin = global i64 0
    @camlIf_then_else_basic__code_end = global i64 0
    @camlIf_then_else_basic__frametable = global i64 0

    define i64 @camlIf_then_else_basic__entry() {
      br i1 true, label %1, label %2

    1:                                                ; preds = %0
      br label %3

    2:                                                ; preds = %0
      br label %3

    3:                                                ; preds = %1, %2
      %4 = phi i64 [ 41, %2 ], [ 21, %1 ]
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}]

let%expect_test "if-then-else nested complex" =
  let t =
    test_compile ~name:"if_then_else_complex"
      ~code:
        "\n\
        \    external ( < ) : int -> int -> bool = \"%lessthan\"\n\
        \    let x = \n\
        \      if 1 < 2 then\n\
        \        if 3 < 4 then\n\
        \          if 5 < 6 then 10 else 20\n\
        \        else if 7 < 8 then\n\
        \          30\n\
        \        else\n\
        \          40\n\
        \      else\n\
        \        if 9 < 10 then 50 else 60\n\
        \  "
  in
  verify_mlir t;
  [%expect
    {|
    |}];
  verify_std_mlir t;
  [%expect
    {|
    |}];
  verify_llvm t;
  [%expect
    {|
    |}]


