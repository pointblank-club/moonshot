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
        %0 = ocaml.constant 2 : !ocaml.int loc(#loc1)
        %1 = ocaml.constant 9 : !ocaml.int loc(#loc2)
        %2 = ocaml.cmp "lt" %0, %1 : !ocaml.int -> !ocaml.bool loc(#loc1)
        %3 = ocaml.constant 7 : !ocaml.int loc(#loc3)
        %4 = ocaml.constant 3 : !ocaml.int loc(#loc4)
        %5 = ocaml.cmp "gt" %3, %4 : !ocaml.int -> !ocaml.bool loc(#loc3)
        %6 = ocaml.constant 2 : !ocaml.int loc(#loc5)
        %7 = ocaml.constant 9 : !ocaml.int loc(#loc6)
        %8 = ocaml.cmp "le" %6, %7 : !ocaml.int -> !ocaml.bool loc(#loc5)
        %9 = ocaml.constant 7 : !ocaml.int loc(#loc7)
        %10 = ocaml.constant 3 : !ocaml.int loc(#loc8)
        %11 = ocaml.cmp "ge" %9, %10 : !ocaml.int -> !ocaml.bool loc(#loc7)
        %12 = ocaml.constant 4 : !ocaml.int loc(#loc9)
        %13 = ocaml.constant 4 : !ocaml.int loc(#loc10)
        %14 = ocaml.cmp "eq" %12, %13 : !ocaml.int -> !ocaml.bool loc(#loc9)
        %15 = ocaml.constant 4 : !ocaml.int loc(#loc11)
        %16 = ocaml.constant 9 : !ocaml.int loc(#loc12)
        %17 = ocaml.cmp "ne" %15, %16 : !ocaml.int -> !ocaml.bool loc(#loc11)
      } loc(#loc)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("compare.ml":8:14)
    #loc2 = loc("compare.ml":8:18)
    #loc3 = loc("compare.ml":9:14)
    #loc4 = loc("compare.ml":9:18)
    #loc5 = loc("compare.ml":10:14)
    #loc6 = loc("compare.ml":10:19)
    #loc7 = loc("compare.ml":11:14)
    #loc8 = loc("compare.ml":11:19)
    #loc9 = loc("compare.ml":12:14)
    #loc10 = loc("compare.ml":12:18)
    #loc11 = loc("compare.ml":13:14)
    #loc12 = loc("compare.ml":13:19)
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
    ; ModuleID = 'compare.ml'
    source_filename = "compare.ml"

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
    |}]

let%expect_test "if-then-else basic" =
  let t =
    test_compile ~name:"if_then_else_basic"
      ~code:
        "\n\
        \    external ( < ) : int -> int -> bool = \"%lessthan\"\n\
        \    let x = if 3 < 5 then 10 else 20\n\
        \  "
  in
  verify_build_stdout t;
  verify_mlir t;
  [%expect
    {|
    Compiling module If_then_else_basic to MLIR
    Generated object file: <path_to_object_file>
    ocaml.module @If_then_else_basic {
      ocaml.entry {
        %0 = ocaml.constant 3 : !ocaml.int
        %1 = ocaml.constant 5 : !ocaml.int
        %2 = ocaml.cmp "lt" %0, %1 : !ocaml.int -> !ocaml.bool
        %3 = ocaml.if_then_else %2 : !ocaml.bool -> !ocaml.int then {
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
        %3 = llvm.mlir.constant(3 : i64) : i64
        %4 = llvm.mlir.constant(1 : i64) : i64
        %5 = llvm.select %2, %3, %4 : i1, i64
        %6 = llvm.mlir.constant(3 : i64) : i64
        %7 = llvm.icmp "eq" %5, %6 : i64
        llvm.cond_br %7, ^bb1, ^bb2
      ^bb1:  // pred: ^bb0
        %8 = llvm.mlir.constant(21 : i64) : i64
        llvm.br ^bb3(%8 : i64)
      ^bb2:  // pred: ^bb0
        %9 = llvm.mlir.constant(41 : i64) : i64
        llvm.br ^bb3(%9 : i64)
      ^bb3(%10: i64):  // 2 preds: ^bb1, ^bb2
        %11 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %11 : i64
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
    test_compile_and_run ~name:"if_then_else_complex"
      ~code:
        "\n\
        \    external ( < ) : int -> int -> bool = \"%lessthan\"\n\
        \    external print_int : int -> unit = \"print_int\"\n\
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
        \    let () = print_int x\n\
        \  "
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @If_then_else_complex {
      ocaml.entry {
        %0 = ocaml.constant 1 : !ocaml.int
        %1 = ocaml.constant 2 : !ocaml.int
        %2 = ocaml.cmp "lt" %0, %1 : !ocaml.int -> !ocaml.bool
        %3 = ocaml.if_then_else %2 : !ocaml.bool -> !ocaml.int then {
          %5 = ocaml.constant 3 : !ocaml.int
          %6 = ocaml.constant 4 : !ocaml.int
          %7 = ocaml.cmp "lt" %5, %6 : !ocaml.int -> !ocaml.bool
          %8 = ocaml.if_then_else %7 : !ocaml.bool -> !ocaml.int then {
            %9 = ocaml.constant 5 : !ocaml.int
            %10 = ocaml.constant 6 : !ocaml.int
            %11 = ocaml.cmp "lt" %9, %10 : !ocaml.int -> !ocaml.bool
            %12 = ocaml.if_then_else %11 : !ocaml.bool -> !ocaml.int then {
              %13 = ocaml.constant 10 : !ocaml.int
              ocaml.yield %13 : !ocaml.int
            } else {
              %13 = ocaml.constant 20 : !ocaml.int
              ocaml.yield %13 : !ocaml.int
            }
            ocaml.yield %12 : !ocaml.int
          } else {
            %9 = ocaml.constant 7 : !ocaml.int
            %10 = ocaml.constant 8 : !ocaml.int
            %11 = ocaml.cmp "lt" %9, %10 : !ocaml.int -> !ocaml.bool
            %12 = ocaml.if_then_else %11 : !ocaml.bool -> !ocaml.int then {
              %13 = ocaml.constant 30 : !ocaml.int
              ocaml.yield %13 : !ocaml.int
            } else {
              %13 = ocaml.constant 40 : !ocaml.int
              ocaml.yield %13 : !ocaml.int
            }
            ocaml.yield %12 : !ocaml.int
          }
          ocaml.yield %8 : !ocaml.int
        } else {
          %5 = ocaml.constant 9 : !ocaml.int
          %6 = ocaml.constant 10 : !ocaml.int
          %7 = ocaml.cmp "lt" %5, %6 : !ocaml.int -> !ocaml.bool
          %8 = ocaml.if_then_else %7 : !ocaml.bool -> !ocaml.int then {
            %9 = ocaml.constant 50 : !ocaml.int
            ocaml.yield %9 : !ocaml.int
          } else {
            %9 = ocaml.constant 60 : !ocaml.int
            ocaml.yield %9 : !ocaml.int
          }
          ocaml.yield %8 : !ocaml.int
        }
        %4 = ocaml.extern_call @print_int(%3) : (!ocaml.int) -> !ocaml.unit
      }
      ocaml.extern @print_int {target = "print_int"} : (!ocaml.int) -> !ocaml.unit
    }
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.func @print_int(i64) -> i64
      llvm.func @camlIf_then_else_complex__entry() -> i64 {
        %0 = llvm.mlir.constant(3 : i64) : i64
        %1 = llvm.mlir.constant(5 : i64) : i64
        %2 = llvm.icmp "slt" %0, %1 : i64
        %3 = llvm.mlir.constant(3 : i64) : i64
        %4 = llvm.mlir.constant(1 : i64) : i64
        %5 = llvm.select %2, %3, %4 : i1, i64
        %6 = llvm.mlir.constant(3 : i64) : i64
        %7 = llvm.icmp "eq" %5, %6 : i64
        llvm.cond_br %7, ^bb1, ^bb11
      ^bb1:  // pred: ^bb0
        %8 = llvm.mlir.constant(7 : i64) : i64
        %9 = llvm.mlir.constant(9 : i64) : i64
        %10 = llvm.icmp "slt" %8, %9 : i64
        %11 = llvm.mlir.constant(3 : i64) : i64
        %12 = llvm.mlir.constant(1 : i64) : i64
        %13 = llvm.select %10, %11, %12 : i1, i64
        %14 = llvm.mlir.constant(3 : i64) : i64
        %15 = llvm.icmp "eq" %13, %14 : i64
        llvm.cond_br %15, ^bb2, ^bb6
      ^bb2:  // pred: ^bb1
        %16 = llvm.mlir.constant(11 : i64) : i64
        %17 = llvm.mlir.constant(13 : i64) : i64
        %18 = llvm.icmp "slt" %16, %17 : i64
        %19 = llvm.mlir.constant(3 : i64) : i64
        %20 = llvm.mlir.constant(1 : i64) : i64
        %21 = llvm.select %18, %19, %20 : i1, i64
        %22 = llvm.mlir.constant(3 : i64) : i64
        %23 = llvm.icmp "eq" %21, %22 : i64
        llvm.cond_br %23, ^bb3, ^bb4
      ^bb3:  // pred: ^bb2
        %24 = llvm.mlir.constant(21 : i64) : i64
        llvm.br ^bb5(%24 : i64)
      ^bb4:  // pred: ^bb2
        %25 = llvm.mlir.constant(41 : i64) : i64
        llvm.br ^bb5(%25 : i64)
      ^bb5(%26: i64):  // 2 preds: ^bb3, ^bb4
        llvm.br ^bb10(%26 : i64)
      ^bb6:  // pred: ^bb1
        %27 = llvm.mlir.constant(15 : i64) : i64
        %28 = llvm.mlir.constant(17 : i64) : i64
        %29 = llvm.icmp "slt" %27, %28 : i64
        %30 = llvm.mlir.constant(3 : i64) : i64
        %31 = llvm.mlir.constant(1 : i64) : i64
        %32 = llvm.select %29, %30, %31 : i1, i64
        %33 = llvm.mlir.constant(3 : i64) : i64
        %34 = llvm.icmp "eq" %32, %33 : i64
        llvm.cond_br %34, ^bb7, ^bb8
      ^bb7:  // pred: ^bb6
        %35 = llvm.mlir.constant(61 : i64) : i64
        llvm.br ^bb9(%35 : i64)
      ^bb8:  // pred: ^bb6
        %36 = llvm.mlir.constant(81 : i64) : i64
        llvm.br ^bb9(%36 : i64)
      ^bb9(%37: i64):  // 2 preds: ^bb7, ^bb8
        llvm.br ^bb10(%37 : i64)
      ^bb10(%38: i64):  // 2 preds: ^bb5, ^bb9
        llvm.br ^bb15(%38 : i64)
      ^bb11:  // pred: ^bb0
        %39 = llvm.mlir.constant(19 : i64) : i64
        %40 = llvm.mlir.constant(21 : i64) : i64
        %41 = llvm.icmp "slt" %39, %40 : i64
        %42 = llvm.mlir.constant(3 : i64) : i64
        %43 = llvm.mlir.constant(1 : i64) : i64
        %44 = llvm.select %41, %42, %43 : i1, i64
        %45 = llvm.mlir.constant(3 : i64) : i64
        %46 = llvm.icmp "eq" %44, %45 : i64
        llvm.cond_br %46, ^bb12, ^bb13
      ^bb12:  // pred: ^bb11
        %47 = llvm.mlir.constant(101 : i64) : i64
        llvm.br ^bb14(%47 : i64)
      ^bb13:  // pred: ^bb11
        %48 = llvm.mlir.constant(121 : i64) : i64
        llvm.br ^bb14(%48 : i64)
      ^bb14(%49: i64):  // 2 preds: ^bb12, ^bb13
        llvm.br ^bb15(%49 : i64)
      ^bb15(%50: i64):  // 2 preds: ^bb10, ^bb14
        %51 = llvm.call @print_int(%50) : (i64) -> i64
        %52 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %52 : i64
      }
      llvm.mlir.global external @camlIf_then_else_complex__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_else_complex__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_else_complex__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_else_complex__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_else_complex__code_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_else_complex__frametable(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'LLVMDialectModule'
    source_filename = "LLVMDialectModule"

    @camlIf_then_else_complex__gc_roots = global i64 0
    @camlIf_then_else_complex__data_begin = global i64 0
    @camlIf_then_else_complex__data_end = global i64 0
    @camlIf_then_else_complex__code_begin = global i64 0
    @camlIf_then_else_complex__code_end = global i64 0
    @camlIf_then_else_complex__frametable = global i64 0

    declare i64 @print_int(i64)

    define i64 @camlIf_then_else_complex__entry() {
      br i1 true, label %1, label %14

    1:                                                ; preds = %0
      br i1 true, label %2, label %7

    2:                                                ; preds = %1
      br i1 true, label %3, label %4

    3:                                                ; preds = %2
      br label %5

    4:                                                ; preds = %2
      br label %5

    5:                                                ; preds = %3, %4
      %6 = phi i64 [ 41, %4 ], [ 21, %3 ]
      br label %12

    7:                                                ; preds = %1
      br i1 true, label %8, label %9

    8:                                                ; preds = %7
      br label %10

    9:                                                ; preds = %7
      br label %10

    10:                                               ; preds = %8, %9
      %11 = phi i64 [ 81, %9 ], [ 61, %8 ]
      br label %12

    12:                                               ; preds = %5, %10
      %13 = phi i64 [ %11, %10 ], [ %6, %5 ]
      br label %19

    14:                                               ; preds = %0
      br i1 true, label %15, label %16

    15:                                               ; preds = %14
      br label %17

    16:                                               ; preds = %14
      br label %17

    17:                                               ; preds = %15, %16
      %18 = phi i64 [ 121, %16 ], [ 101, %15 ]
      br label %19

    19:                                               ; preds = %12, %17
      %20 = phi i64 [ %18, %17 ], [ %13, %12 ]
      %21 = call i64 @print_int(i64 %20)
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}];
  verify_stdout t;
  [%expect {| 10 |}]

let%expect_test "if-then-else float" =
  let t =
    test_compile ~name:"if_then_else_float"
      ~code:
        "\n\
        \    external ( < ) : float -> float -> bool = \"%lessthan\"\n\
        \    let x = if 3.0 < 5.0 then 10.0 else 20.0\n\
        \  "
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @If_then_else_float {
      ocaml.entry {
        %0 = ocaml.constant 3.000000e+00 : f64 : !ocaml.float
        %1 = ocaml.constant 5.000000e+00 : f64 : !ocaml.float
        %2 = ocaml.cmp "lt" %0, %1 : !ocaml.float -> !ocaml.bool
        %3 = ocaml.if_then_else %2 : !ocaml.bool -> !ocaml.float then {
          %4 = ocaml.constant 1.000000e+01 : f64 : !ocaml.float
          ocaml.yield %4 : !ocaml.float
        } else {
          %4 = ocaml.constant 2.000000e+01 : f64 : !ocaml.float
          ocaml.yield %4 : !ocaml.float
        }
      }
    }
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.mlir.global external constant @camlIf_then_else_float.1("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\08@") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlIf_then_else_float.2("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\14@") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlIf_then_else_float.3("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00$@") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlIf_then_else_float.4("\FD\07\00\00\00\00\00\00\00\00\00\00\00\004@") {addr_space = 0 : i32}
      llvm.func @camlIf_then_else_float__entry() -> i64 {
        %0 = llvm.mlir.addressof @camlIf_then_else_float.1 : !llvm.ptr
        %1 = llvm.getelementptr %0[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %2 = llvm.mlir.addressof @camlIf_then_else_float.2 : !llvm.ptr
        %3 = llvm.getelementptr %2[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %4 = llvm.load %1 : !llvm.ptr -> f64
        %5 = llvm.load %3 : !llvm.ptr -> f64
        %6 = llvm.fcmp "olt" %4, %5 : f64
        %7 = llvm.mlir.constant(3 : i64) : i64
        %8 = llvm.mlir.constant(1 : i64) : i64
        %9 = llvm.select %6, %7, %8 : i1, i64
        %10 = llvm.mlir.constant(3 : i64) : i64
        %11 = llvm.icmp "eq" %9, %10 : i64
        llvm.cond_br %11, ^bb1, ^bb2
      ^bb1:  // pred: ^bb0
        %12 = llvm.mlir.addressof @camlIf_then_else_float.3 : !llvm.ptr
        %13 = llvm.getelementptr %12[8] : (!llvm.ptr) -> !llvm.ptr, i8
        llvm.br ^bb3(%13 : !llvm.ptr)
      ^bb2:  // pred: ^bb0
        %14 = llvm.mlir.addressof @camlIf_then_else_float.4 : !llvm.ptr
        %15 = llvm.getelementptr %14[8] : (!llvm.ptr) -> !llvm.ptr, i8
        llvm.br ^bb3(%15 : !llvm.ptr)
      ^bb3(%16: !llvm.ptr):  // 2 preds: ^bb1, ^bb2
        %17 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %17 : i64
      }
      llvm.mlir.global external @camlIf_then_else_float__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_else_float__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_else_float__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_else_float__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_else_float__code_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_else_float__frametable(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'LLVMDialectModule'
    source_filename = "LLVMDialectModule"

    @camlIf_then_else_float.1 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\08@"
    @camlIf_then_else_float.2 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\14@"
    @camlIf_then_else_float.3 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00$@"
    @camlIf_then_else_float.4 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\004@"
    @camlIf_then_else_float__gc_roots = global i64 0
    @camlIf_then_else_float__data_begin = global i64 0
    @camlIf_then_else_float__data_end = global i64 0
    @camlIf_then_else_float__code_begin = global i64 0
    @camlIf_then_else_float__code_end = global i64 0
    @camlIf_then_else_float__frametable = global i64 0

    define i64 @camlIf_then_else_float__entry() {
      %1 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlIf_then_else_float.1, i64 8), align 8
      %2 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlIf_then_else_float.2, i64 8), align 8
      %3 = fcmp olt double %1, %2
      %4 = select i1 %3, i64 3, i64 1
      %5 = icmp eq i64 %4, 3
      br i1 %5, label %6, label %7

    6:                                                ; preds = %0
      br label %8

    7:                                                ; preds = %0
      br label %8

    8:                                                ; preds = %6, %7
      %9 = phi ptr [ getelementptr inbounds nuw (i8, ptr @camlIf_then_else_float.4, i64 8), %7 ], [ getelementptr inbounds nuw (i8, ptr @camlIf_then_else_float.3, i64 8), %6 ]
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}]

let%expect_test "if-then basic" =
  let t =
    test_compile ~name:"if_then_basic"
      ~code:
        "\n\
        \    external ( < ) : int -> int -> bool = \"%lessthan\"\n\
        \    let x = if 3 < 5 then ()\n\
        \  "
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @If_then_basic {
      ocaml.entry {
        %0 = ocaml.constant 3 : !ocaml.int
        %1 = ocaml.constant 5 : !ocaml.int
        %2 = ocaml.cmp "lt" %0, %1 : !ocaml.int -> !ocaml.bool
        %3 = ocaml.if_then_else %2 : !ocaml.bool -> !ocaml.unit then {
          %4 = ocaml.constant unit : !ocaml.unit
          ocaml.yield %4 : !ocaml.unit
        } else {
          %4 = ocaml.constant unit : !ocaml.unit
          ocaml.yield %4 : !ocaml.unit
        }
      }
    }
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.func @camlIf_then_basic__entry() -> i64 {
        %0 = llvm.mlir.constant(7 : i64) : i64
        %1 = llvm.mlir.constant(11 : i64) : i64
        %2 = llvm.icmp "slt" %0, %1 : i64
        %3 = llvm.mlir.constant(3 : i64) : i64
        %4 = llvm.mlir.constant(1 : i64) : i64
        %5 = llvm.select %2, %3, %4 : i1, i64
        %6 = llvm.mlir.constant(3 : i64) : i64
        %7 = llvm.icmp "eq" %5, %6 : i64
        llvm.cond_br %7, ^bb1, ^bb2
      ^bb1:  // pred: ^bb0
        %8 = llvm.mlir.constant(1 : i64) : i64
        llvm.br ^bb3(%8 : i64)
      ^bb2:  // pred: ^bb0
        %9 = llvm.mlir.constant(1 : i64) : i64
        llvm.br ^bb3(%9 : i64)
      ^bb3(%10: i64):  // 2 preds: ^bb1, ^bb2
        %11 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %11 : i64
      }
      llvm.mlir.global external @camlIf_then_basic__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_basic__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_basic__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_basic__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_basic__code_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlIf_then_basic__frametable(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'LLVMDialectModule'
    source_filename = "LLVMDialectModule"

    @camlIf_then_basic__gc_roots = global i64 0
    @camlIf_then_basic__data_begin = global i64 0
    @camlIf_then_basic__data_end = global i64 0
    @camlIf_then_basic__code_begin = global i64 0
    @camlIf_then_basic__code_end = global i64 0
    @camlIf_then_basic__frametable = global i64 0

    define i64 @camlIf_then_basic__entry() {
      br i1 true, label %1, label %2

    1:                                                ; preds = %0
      br label %3

    2:                                                ; preds = %0
      br label %3

    3:                                                ; preds = %1, %2
      %4 = phi i64 [ 1, %2 ], [ 1, %1 ]
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}]

let%expect_test "if-then-else execution" =
  let t =
    test_compile_and_run ~name:"if_then_else_exec"
      ~code:
        "\n\
        \    external ( < ) : int -> int -> bool = \"%lessthan\"\n\
        \    external print_int : int -> unit = \"print_int\"\n\
        \    let () = \n\
        \      if 3 < 5 then \n\
        \        print_int 10\n\
        \      else \n\
        \        print_int 20\n\
        \    let () = \n\
        \      if 5 < 3 then \n\
        \        print_int 30\n\
        \      else \n\
        \        print_int 40\n\
        \    let () = \n\
        \      if 3 < 5 then \n\
        \        print_int 50\n\
        \  "
  in
  verify_stdout t;
  [%expect {|
    10
    40
    50
    |}]

let%expect_test "if-then-else float execution" =
  let t =
    test_compile_and_run ~name:"if_then_else_float_exec"
      ~code:
        "\n\
        \    external ( < ) : float -> float -> bool = \"%lessthan\"\n\
        \    external print_float : float -> unit = \"print_float\"\n\
        \    let () = \n\
        \      if 3.0 < 5.0 then \n\
        \        print_float 10.5\n\
        \      else \n\
        \        print_float 20.5\n\
        \    let () = \n\
        \      if 5.0 < 3.0 then \n\
        \        print_float 30.5\n\
        \      else \n\
        \        print_float 40.5\n\
        \  "
  in
  verify_stdout t;
  [%expect {|
    10.5
    40.5
    |}]
