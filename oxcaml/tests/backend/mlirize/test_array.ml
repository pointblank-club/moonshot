open Helpers

let%expect_test "int_array_constant" =
  let t =
    test_compile ~name:"int_array_constant"
      ~code:{|
    let arr = [| 1; 2; 3 |]
  |}
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Int_array_constant {
      ocaml.entry {
        %0 = ocaml.constant 1 : !ocaml.int loc(#loc1)
        %1 = ocaml.constant 2 : !ocaml.int loc(#loc2)
        %2 = ocaml.constant 3 : !ocaml.int loc(#loc3)
        %3 = ocaml.alloc_array(%0, %1, %2) : (!ocaml.int, !ocaml.int, !ocaml.int) -> !ocaml.array loc(#loc4)
      } loc(#loc)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("int_array_constant.ml":2:18)
    #loc2 = loc("int_array_constant.ml":2:21)
    #loc3 = loc("int_array_constant.ml":2:24)
    #loc4 = loc("int_array_constant.ml":2:15)
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.func @caml_alloc(i64, i32) -> !llvm.ptr
      llvm.func @camlInt_array_constant__entry() -> i64 {
        %0 = llvm.mlir.constant(3 : i64) : i64
        %1 = llvm.mlir.constant(5 : i64) : i64
        %2 = llvm.mlir.constant(7 : i64) : i64
        %3 = llvm.mlir.constant(3 : i64) : i64
        %4 = llvm.mlir.constant(0 : i32) : i32
        %5 = llvm.call @caml_alloc(%3, %4) : (i64, i32) -> !llvm.ptr
        %6 = llvm.mlir.constant(0 : i64) : i64
        %7 = llvm.getelementptr %5[%6] : (!llvm.ptr, i64) -> !llvm.ptr, i64
        llvm.store %0, %7 : i64, !llvm.ptr
        %8 = llvm.mlir.constant(1 : i64) : i64
        %9 = llvm.getelementptr %5[%8] : (!llvm.ptr, i64) -> !llvm.ptr, i64
        llvm.store %1, %9 : i64, !llvm.ptr
        %10 = llvm.mlir.constant(2 : i64) : i64
        %11 = llvm.getelementptr %5[%10] : (!llvm.ptr, i64) -> !llvm.ptr, i64
        llvm.store %2, %11 : i64, !llvm.ptr
        %12 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %12 : i64
      }
      llvm.mlir.global external @camlInt_array_constant__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlInt_array_constant__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlInt_array_constant__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlInt_array_constant__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlInt_array_constant__code_end(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'int_array_constant.ml'
    source_filename = "int_array_constant.ml"

    @camlInt_array_constant__gc_roots = global i64 0
    @camlInt_array_constant__data_begin = global i64 0
    @camlInt_array_constant__data_end = global i64 0
    @camlInt_array_constant__code_begin = global i64 0
    @camlInt_array_constant__code_end = global i64 0

    declare ptr @caml_alloc(i64, i32)

    define i64 @camlInt_array_constant__entry() {
      %1 = call ptr @caml_alloc(i64 3, i32 0)
      %2 = getelementptr i64, ptr %1, i64 0
      store i64 3, ptr %2, align 4
      %3 = getelementptr i64, ptr %1, i64 1
      store i64 5, ptr %3, align 4
      %4 = getelementptr i64, ptr %1, i64 2
      store i64 7, ptr %4, align 4
      ret i64 1
    }

    !llvm.module.flags = !{!0}
    !llvm.ident = !{!1}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    !1 = !{!"OCaml MLIR dialect unknown"}
    |}]

let%expect_test "empty_array_constant" =
  let t =
    test_compile ~name:"empty_array_constant" ~code:{|
    let arr = [||]
  |}
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Empty_array_constant {
      ocaml.entry {
        %0 = ocaml.alloc_array() : () -> !ocaml.array loc(#loc1)
      } loc(#loc)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("empty_array_constant.ml":2:15)
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.func @caml_alloc(i64, i32) -> !llvm.ptr
      llvm.func @camlEmpty_array_constant__entry() -> i64 {
        %0 = llvm.mlir.constant(0 : i64) : i64
        %1 = llvm.mlir.constant(0 : i32) : i32
        %2 = llvm.call @caml_alloc(%0, %1) : (i64, i32) -> !llvm.ptr
        %3 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %3 : i64
      }
      llvm.mlir.global external @camlEmpty_array_constant__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlEmpty_array_constant__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlEmpty_array_constant__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlEmpty_array_constant__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlEmpty_array_constant__code_end(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'empty_array_constant.ml'
    source_filename = "empty_array_constant.ml"

    @camlEmpty_array_constant__gc_roots = global i64 0
    @camlEmpty_array_constant__data_begin = global i64 0
    @camlEmpty_array_constant__data_end = global i64 0
    @camlEmpty_array_constant__code_begin = global i64 0
    @camlEmpty_array_constant__code_end = global i64 0

    declare ptr @caml_alloc(i64, i32)

    define i64 @camlEmpty_array_constant__entry() {
      %1 = call ptr @caml_alloc(i64 0, i32 0)
      ret i64 1
    }

    !llvm.module.flags = !{!0}
    !llvm.ident = !{!1}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    !1 = !{!"OCaml MLIR dialect unknown"}
    |}]

let%expect_test "array_get_set_length" =
  let t =
    test_compile ~name:"array_get_set_length"
      ~code:
        {|
    external ( + ) : int -> int -> int = "%addint"
    external array_get : 'a array -> int -> 'a = "%array_safe_get"
    external array_set : 'a array -> int -> 'a -> unit = "%array_safe_set"
    external array_length : 'a array -> int = "%array_length"

    let test () =
      let arr = [| 10; 20 |] in
      let len = array_length arr in
      let v = array_get arr 0 in
      array_set arr 1 (v + len)
  |}
  in
  verify_mlir t;
  [%expect
    {|
    #loc1 = loc("array_get_set_length.ml":8:7)
    ocaml.module @Array_get_set_length {
      ocaml.entry {
      } loc(#loc)
      ocaml.function @test("camlArray_get_set_length__test_8") : (!ocaml.unit) -> !ocaml.unit {
      ^bb0(%arg0: !ocaml.unit loc("array_get_set_length.ml":8:7)):
        %0 = ocaml.constant 10 : !ocaml.int loc(#loc2)
        %1 = ocaml.constant 20 : !ocaml.int loc(#loc3)
        %2 = ocaml.alloc_array(%0, %1) : (!ocaml.int, !ocaml.int) -> !ocaml.array loc(#loc4)
        %3 = ocaml.array_length %2 : !ocaml.array -> !ocaml.int loc(#loc5)
        %4 = ocaml.constant 0 : !ocaml.int loc(#loc6)
        %5 = ocaml.array_get %2[%4] : !ocaml.array, !ocaml.int -> !ocaml.int loc(#loc7)
        %6 = ocaml.constant 1 : !ocaml.int loc(#loc8)
        %7 = ocaml.binop "+" %5, %3 : !ocaml.int, !ocaml.int -> !ocaml.int loc(#loc9)
        %8 = ocaml.array_set %2[%6] = %7 : !ocaml.array, !ocaml.int, !ocaml.int -> !ocaml.unit loc(#loc10)
        ocaml.return %8 : !ocaml.unit loc(#loc1)
      } loc(#loc1)
    } loc(#loc)
    #loc = loc(unknown)
    #loc2 = loc("array_get_set_length.ml":8:20)
    #loc3 = loc("array_get_set_length.ml":8:24)
    #loc4 = loc("array_get_set_length.ml":8:17)
    #loc5 = loc("array_get_set_length.ml":9:17)
    #loc6 = loc("array_get_set_length.ml":10:29)
    #loc7 = loc("array_get_set_length.ml":10:15)
    #loc8 = loc("array_get_set_length.ml":11:21)
    #loc9 = loc("array_get_set_length.ml":11:23)
    #loc10 = loc("array_get_set_length.ml":11:7)
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.func @caml_alloc(i64, i32) -> !llvm.ptr
      llvm.func @camlArray_get_set_length__entry() -> i64 {
        %0 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %0 : i64
      }
      llvm.func @camlArray_get_set_length__test_8(%arg0: i64) -> i64 {
        %0 = llvm.mlir.constant(21 : i64) : i64
        %1 = llvm.mlir.constant(41 : i64) : i64
        %2 = llvm.mlir.constant(2 : i64) : i64
        %3 = llvm.mlir.constant(0 : i32) : i32
        %4 = llvm.call @caml_alloc(%2, %3) : (i64, i32) -> !llvm.ptr
        %5 = llvm.mlir.constant(0 : i64) : i64
        %6 = llvm.getelementptr %4[%5] : (!llvm.ptr, i64) -> !llvm.ptr, i64
        llvm.store %0, %6 : i64, !llvm.ptr
        %7 = llvm.mlir.constant(1 : i64) : i64
        %8 = llvm.getelementptr %4[%7] : (!llvm.ptr, i64) -> !llvm.ptr, i64
        llvm.store %1, %8 : i64, !llvm.ptr
        %9 = llvm.mlir.constant(-1 : i64) : i64
        %10 = llvm.getelementptr %4[%9] : (!llvm.ptr, i64) -> !llvm.ptr, i64
        %11 = llvm.load %10 : !llvm.ptr -> i64
        %12 = llvm.mlir.constant(9 : i64) : i64
        %13 = llvm.lshr %11, %12 : i64
        %14 = llvm.mlir.constant(1 : i64) : i64
        %15 = llvm.or %13, %14 : i64
        %16 = llvm.mlir.constant(1 : i64) : i64
        %17 = llvm.mlir.constant(1 : i64) : i64
        %18 = llvm.lshr %16, %17 : i64
        %19 = llvm.getelementptr %4[%18] : (!llvm.ptr, i64) -> !llvm.ptr, i64
        %20 = llvm.load %19 : !llvm.ptr -> i64
        %21 = llvm.mlir.constant(3 : i64) : i64
        %22 = llvm.add %20, %15 : i64
        %23 = llvm.mlir.constant(1 : i64) : i64
        %24 = llvm.sub %22, %23 : i64
        %25 = llvm.mlir.constant(1 : i64) : i64
        %26 = llvm.lshr %21, %25 : i64
        %27 = llvm.getelementptr %4[%26] : (!llvm.ptr, i64) -> !llvm.ptr, i64
        llvm.store %24, %27 : i64, !llvm.ptr
        %28 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %28 : i64
      }
      llvm.mlir.global external @camlArray_get_set_length__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlArray_get_set_length__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlArray_get_set_length__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlArray_get_set_length__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlArray_get_set_length__code_end(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'array_get_set_length.ml'
    source_filename = "array_get_set_length.ml"

    @camlArray_get_set_length__gc_roots = global i64 0
    @camlArray_get_set_length__data_begin = global i64 0
    @camlArray_get_set_length__data_end = global i64 0
    @camlArray_get_set_length__code_begin = global i64 0
    @camlArray_get_set_length__code_end = global i64 0

    declare ptr @caml_alloc(i64, i32)

    define i64 @camlArray_get_set_length__entry() {
      ret i64 1
    }

    define i64 @camlArray_get_set_length__test_8(i64 %0) {
      %2 = call ptr @caml_alloc(i64 2, i32 0)
      %3 = getelementptr i64, ptr %2, i64 0
      store i64 21, ptr %3, align 4
      %4 = getelementptr i64, ptr %2, i64 1
      store i64 41, ptr %4, align 4
      %5 = getelementptr i64, ptr %2, i64 -1
      %6 = load i64, ptr %5, align 4
      %7 = lshr i64 %6, 9
      %8 = or i64 %7, 1
      %9 = getelementptr i64, ptr %2, i64 0
      %10 = load i64, ptr %9, align 4
      %11 = add i64 %10, %8
      %12 = sub i64 %11, 1
      %13 = getelementptr i64, ptr %2, i64 1
      store i64 %12, ptr %13, align 4
      ret i64 1
    }

    !llvm.module.flags = !{!0}
    !llvm.ident = !{!1}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    !1 = !{!"OCaml MLIR dialect unknown"}
    |}]

let%expect_test "array_execution_and_print" =
  let t =
    test_compile_and_run ~name:"array_execution_and_print"
      ~code:
        {|
    external ( + ) : int -> int -> int = "%addint"
    external array_get : 'a array -> int -> 'a = "%array_safe_get"
    external array_set : 'a array -> int -> 'a -> unit = "%array_safe_set"
    external array_length : 'a array -> int = "%array_length"
    external print_int : int -> unit = "print_int"

    let () =
      let arr = [| 100; 200; 300 |] in
      let len = array_length arr in
      print_int len;
      let elem0 = array_get arr 0 in
      print_int elem0;
      array_set arr 1 (elem0 + len);
      let elem1 = array_get arr 1 in
      print_int elem1
  |}
  in
  verify_stdout t;
  [%expect {|
    3
    100
    103
    |}]
