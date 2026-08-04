open Helpers

let%expect_test "extern call assignment" =
  let t =
    test_compile ~name:"extern_call_assign"
      ~code:
        {|
    external puts : string -> int = "caml_puts"
    external puts_int : int -> unit = "caml_puts_int"
    let a = puts "Hello from C puts!"
    let () = puts_int a
    |}
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Extern_call_assign {
      ocaml.entry {
        %0 = ocaml.constant "Hello from C puts!" : !ocaml.string loc(#loc1)
        %1 = ocaml.extern_call @puts(%0) : (!ocaml.string) -> !ocaml.int loc(#loc2)
        %2 = ocaml.extern_call @puts_int(%1) : (!ocaml.int) -> !ocaml.unit loc(#loc3)
      } loc(#loc)
      ocaml.extern @puts {target = "caml_puts"} : (!ocaml.string) -> !ocaml.int loc(#loc2)
      ocaml.extern @puts_int {target = "caml_puts_int"} : (!ocaml.int) -> !ocaml.unit loc(#loc3)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("extern_call_assign.ml":4:18)
    #loc2 = loc("extern_call_assign.ml":4:13)
    #loc3 = loc("extern_call_assign.ml":5:14)
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.func @caml_puts_int(i64) -> i64
      llvm.func @caml_c_call(i64, i64, !llvm.ptr, i64) -> i64
      llvm.mlir.global external thread_local @caml_state() {addr_space = 0 : i32} : !llvm.ptr
      llvm.func @caml_puts(!llvm.ptr) -> i64
      llvm.mlir.global external constant @camlExtern_call_assign.1("\FC\0F\00\00\00\00\00\00Hello from C puts!\00\00\00\00\00\05") {addr_space = 0 : i32}
      llvm.func @camlExtern_call_assign__entry() -> i64 {
        %0 = llvm.mlir.addressof @camlExtern_call_assign.1 : !llvm.ptr
        %1 = llvm.getelementptr %0[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %2 = llvm.mlir.addressof @caml_state : !llvm.ptr
        %3 = llvm.load %2 : !llvm.ptr -> !llvm.ptr
        %4 = llvm.ptrtoint %3 : !llvm.ptr to i64
        %5 = llvm.getelementptr %3[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %6 = llvm.load %5 : !llvm.ptr -> !llvm.ptr
        %7 = llvm.ptrtoint %6 : !llvm.ptr to i64
        %8 = llvm.mlir.addressof @caml_puts : !llvm.ptr
        %9 = llvm.mlir.constant(0 : i64) : i64
        %10 = llvm.mlir.addressof @caml_c_call : !llvm.ptr
        %11 = llvm.call %10(%4, %7, %8, %9, %1) : !llvm.ptr, (i64, i64, !llvm.ptr, i64, !llvm.ptr) -> i64
        %12 = llvm.mlir.addressof @caml_state : !llvm.ptr
        %13 = llvm.load %12 : !llvm.ptr -> !llvm.ptr
        %14 = llvm.ptrtoint %13 : !llvm.ptr to i64
        %15 = llvm.getelementptr %13[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %16 = llvm.load %15 : !llvm.ptr -> !llvm.ptr
        %17 = llvm.ptrtoint %16 : !llvm.ptr to i64
        %18 = llvm.mlir.addressof @caml_puts_int : !llvm.ptr
        %19 = llvm.mlir.constant(0 : i64) : i64
        %20 = llvm.mlir.addressof @caml_c_call : !llvm.ptr
        %21 = llvm.call %20(%14, %17, %18, %19, %11) : !llvm.ptr, (i64, i64, !llvm.ptr, i64, i64) -> i64
        %22 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %22 : i64
      }
      llvm.mlir.global external @camlExtern_call_assign__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlExtern_call_assign__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlExtern_call_assign__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlExtern_call_assign__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlExtern_call_assign__code_end(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'extern_call_assign.ml'
    source_filename = "extern_call_assign.ml"

    @caml_state = external thread_local global ptr
    @camlExtern_call_assign.1 = constant [32 x i8] c"\FC\0F\00\00\00\00\00\00Hello from C puts!\00\00\00\00\00\05"
    @camlExtern_call_assign__gc_roots = global i64 0
    @camlExtern_call_assign__data_begin = global i64 0
    @camlExtern_call_assign__data_end = global i64 0
    @camlExtern_call_assign__code_begin = global i64 0
    @camlExtern_call_assign__code_end = global i64 0

    declare i64 @caml_puts_int(i64)

    declare cc129 i64 @caml_c_call(i64, i64, ptr, i64)

    declare i64 @caml_puts(ptr)

    define i64 @camlExtern_call_assign__entry() {
      %1 = load ptr, ptr @caml_state, align 8
      %2 = ptrtoint ptr %1 to i64
      %3 = getelementptr i8, ptr %1, i32 8
      %4 = load ptr, ptr %3, align 8
      %5 = ptrtoint ptr %4 to i64
      %6 = call cc129 i64 @caml_c_call(i64 %2, i64 %5, ptr @caml_puts, i64 0, ptr getelementptr inbounds nuw (i8, ptr @camlExtern_call_assign.1, i64 8))
      %7 = load ptr, ptr @caml_state, align 8
      %8 = ptrtoint ptr %7 to i64
      %9 = getelementptr i8, ptr %7, i32 8
      %10 = load ptr, ptr %9, align 8
      %11 = ptrtoint ptr %10 to i64
      %12 = call cc129 i64 @caml_c_call(i64 %8, i64 %11, ptr @caml_puts_int, i64 0, i64 %6)
      ret i64 1
    }

    !llvm.module.flags = !{!0}
    !llvm.ident = !{!1}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    !1 = !{!"OCaml MLIR dialect unknown"}
    |}]

let%expect_test "extern call helpers" =
  let t =
    test_compile_and_run ~name:"extern_call_helpers"
      ~code:
        {|
    external ( + ) : int -> int -> int = "%addint"
    external print_int : int -> unit = "print_int"
    external print_str : string -> unit = "print_str"
    let () = print_str "Hello, MLIR!"
    let () = print_int (41 + 1)
    |}
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Extern_call_helpers {
      ocaml.entry {
        %0 = ocaml.constant "Hello, MLIR!" : !ocaml.string loc(#loc1)
        %1 = ocaml.extern_call @print_str(%0) : (!ocaml.string) -> !ocaml.unit loc(#loc2)
        %2 = ocaml.constant 41 : !ocaml.int loc(#loc3)
        %3 = ocaml.constant 1 : !ocaml.int loc(#loc4)
        %4 = ocaml.binop "+" %2, %3 : !ocaml.int, !ocaml.int -> !ocaml.int loc(#loc5)
        %5 = ocaml.extern_call @print_int(%4) : (!ocaml.int) -> !ocaml.unit loc(#loc6)
      } loc(#loc)
      ocaml.extern @print_str {target = "print_str"} : (!ocaml.string) -> !ocaml.unit loc(#loc2)
      ocaml.extern @print_int {target = "print_int"} : (!ocaml.int) -> !ocaml.unit loc(#loc6)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("extern_call_helpers.ml":5:24)
    #loc2 = loc("extern_call_helpers.ml":5:14)
    #loc3 = loc("extern_call_helpers.ml":6:25)
    #loc4 = loc("extern_call_helpers.ml":6:30)
    #loc5 = loc("extern_call_helpers.ml":6:24)
    #loc6 = loc("extern_call_helpers.ml":6:14)
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.func @print_int(i64) -> i64
      llvm.func @caml_c_call(i64, i64, !llvm.ptr, i64) -> i64
      llvm.mlir.global external thread_local @caml_state() {addr_space = 0 : i32} : !llvm.ptr
      llvm.func @print_str(!llvm.ptr) -> i64
      llvm.mlir.global external constant @camlExtern_call_helpers.1("\FC\0B\00\00\00\00\00\00Hello, MLIR!\00\00\00\03") {addr_space = 0 : i32}
      llvm.func @camlExtern_call_helpers__entry() -> i64 {
        %0 = llvm.mlir.addressof @camlExtern_call_helpers.1 : !llvm.ptr
        %1 = llvm.getelementptr %0[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %2 = llvm.mlir.addressof @caml_state : !llvm.ptr
        %3 = llvm.load %2 : !llvm.ptr -> !llvm.ptr
        %4 = llvm.ptrtoint %3 : !llvm.ptr to i64
        %5 = llvm.getelementptr %3[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %6 = llvm.load %5 : !llvm.ptr -> !llvm.ptr
        %7 = llvm.ptrtoint %6 : !llvm.ptr to i64
        %8 = llvm.mlir.addressof @print_str : !llvm.ptr
        %9 = llvm.mlir.constant(0 : i64) : i64
        %10 = llvm.mlir.addressof @caml_c_call : !llvm.ptr
        %11 = llvm.call %10(%4, %7, %8, %9, %1) : !llvm.ptr, (i64, i64, !llvm.ptr, i64, !llvm.ptr) -> i64
        %12 = llvm.mlir.constant(83 : i64) : i64
        %13 = llvm.mlir.constant(3 : i64) : i64
        %14 = llvm.add %12, %13 : i64
        %15 = llvm.mlir.constant(1 : i64) : i64
        %16 = llvm.sub %14, %15 : i64
        %17 = llvm.mlir.addressof @caml_state : !llvm.ptr
        %18 = llvm.load %17 : !llvm.ptr -> !llvm.ptr
        %19 = llvm.ptrtoint %18 : !llvm.ptr to i64
        %20 = llvm.getelementptr %18[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %21 = llvm.load %20 : !llvm.ptr -> !llvm.ptr
        %22 = llvm.ptrtoint %21 : !llvm.ptr to i64
        %23 = llvm.mlir.addressof @print_int : !llvm.ptr
        %24 = llvm.mlir.constant(0 : i64) : i64
        %25 = llvm.mlir.addressof @caml_c_call : !llvm.ptr
        %26 = llvm.call %25(%19, %22, %23, %24, %16) : !llvm.ptr, (i64, i64, !llvm.ptr, i64, i64) -> i64
        %27 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %27 : i64
      }
      llvm.mlir.global external @camlExtern_call_helpers__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlExtern_call_helpers__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlExtern_call_helpers__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlExtern_call_helpers__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlExtern_call_helpers__code_end(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'extern_call_helpers.ml'
    source_filename = "extern_call_helpers.ml"

    @caml_state = external thread_local global ptr
    @camlExtern_call_helpers.1 = constant [24 x i8] c"\FC\0B\00\00\00\00\00\00Hello, MLIR!\00\00\00\03"
    @camlExtern_call_helpers__gc_roots = global i64 0
    @camlExtern_call_helpers__data_begin = global i64 0
    @camlExtern_call_helpers__data_end = global i64 0
    @camlExtern_call_helpers__code_begin = global i64 0
    @camlExtern_call_helpers__code_end = global i64 0

    declare i64 @print_int(i64)

    declare cc129 i64 @caml_c_call(i64, i64, ptr, i64)

    declare i64 @print_str(ptr)

    define i64 @camlExtern_call_helpers__entry() {
      %1 = load ptr, ptr @caml_state, align 8
      %2 = ptrtoint ptr %1 to i64
      %3 = getelementptr i8, ptr %1, i32 8
      %4 = load ptr, ptr %3, align 8
      %5 = ptrtoint ptr %4 to i64
      %6 = call cc129 i64 @caml_c_call(i64 %2, i64 %5, ptr @print_str, i64 0, ptr getelementptr inbounds nuw (i8, ptr @camlExtern_call_helpers.1, i64 8))
      %7 = load ptr, ptr @caml_state, align 8
      %8 = ptrtoint ptr %7 to i64
      %9 = getelementptr i8, ptr %7, i32 8
      %10 = load ptr, ptr %9, align 8
      %11 = ptrtoint ptr %10 to i64
      %12 = call cc129 i64 @caml_c_call(i64 %8, i64 %11, ptr @print_int, i64 0, i64 85)
      ret i64 1
    }

    !llvm.module.flags = !{!0}
    !llvm.ident = !{!1}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    !1 = !{!"OCaml MLIR dialect unknown"}
    |}];
  verify_stdout t;
  [%expect {|
    Hello, MLIR!
    42
    |}]
