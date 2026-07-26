open Helpers

let%expect_test "extern call assignment" =
  let t =
    test_compile ~name:"extern_call_assign"
      ~code:
        "\n\
        \    external puts : string -> int = \"caml_puts\"\n\
        \    external puts_int : int -> unit = \"caml_puts_int\"\n\
        \    let a = puts \"Hello from C puts!\"\n\
        \    let () = puts_int a\n\
        \  "
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
      llvm.mlir.global external constant @camlExtern_call_assign.1("\FC\0F\00\00\00\00\00\00Hello from C puts!\00\00\00\00\00\05") {addr_space = 0 : i32}
      llvm.func @caml_puts(!llvm.ptr) -> i64
      llvm.func @caml_puts_int(i64) -> i64
      llvm.func @camlExtern_call_assign__entry() -> i64 {
        %0 = llvm.mlir.addressof @camlExtern_call_assign.1 : !llvm.ptr
        %1 = llvm.getelementptr %0[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %2 = llvm.call @caml_puts(%1) : (!llvm.ptr) -> i64
        %3 = llvm.call @caml_puts_int(%2) : (i64) -> i64
        %4 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %4 : i64
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

    @camlExtern_call_assign.1 = constant [32 x i8] c"\FC\0F\00\00\00\00\00\00Hello from C puts!\00\00\00\00\00\05"
    @camlExtern_call_assign__gc_roots = global i64 0
    @camlExtern_call_assign__data_begin = global i64 0
    @camlExtern_call_assign__data_end = global i64 0
    @camlExtern_call_assign__code_begin = global i64 0
    @camlExtern_call_assign__code_end = global i64 0

    declare i64 @caml_puts(ptr)

    declare i64 @caml_puts_int(i64)

    define i64 @camlExtern_call_assign__entry() {
      %1 = call i64 @caml_puts(ptr getelementptr inbounds nuw (i8, ptr @camlExtern_call_assign.1, i64 8))
      %2 = call i64 @caml_puts_int(i64 %1)
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}]

let%expect_test "extern call helpers" =
  let t =
    test_compile_and_run ~name:"extern_call_helpers"
      ~code:
        "\n\
        \    external ( + ) : int -> int -> int = \"%addint\"\n\
        \    external print_int : int -> unit = \"print_int\"\n\
        \    external print_str : string -> unit = \"print_str\"\n\
        \    let () = print_str \"Hello, MLIR!\"\n\
        \    let () = print_int (41 + 1)\n\
        \  "
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
      llvm.mlir.global external constant @camlExtern_call_helpers.1("\FC\0B\00\00\00\00\00\00Hello, MLIR!\00\00\00\03") {addr_space = 0 : i32}
      llvm.func @print_str(!llvm.ptr) -> i64
      llvm.func @print_int(i64) -> i64
      llvm.func @camlExtern_call_helpers__entry() -> i64 {
        %0 = llvm.mlir.addressof @camlExtern_call_helpers.1 : !llvm.ptr
        %1 = llvm.getelementptr %0[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %2 = llvm.call @print_str(%1) : (!llvm.ptr) -> i64
        %3 = llvm.mlir.constant(83 : i64) : i64
        %4 = llvm.mlir.constant(3 : i64) : i64
        %5 = llvm.add %3, %4 : i64
        %6 = llvm.mlir.constant(1 : i64) : i64
        %7 = llvm.sub %5, %6 : i64
        %8 = llvm.call @print_int(%7) : (i64) -> i64
        %9 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %9 : i64
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

    @camlExtern_call_helpers.1 = constant [24 x i8] c"\FC\0B\00\00\00\00\00\00Hello, MLIR!\00\00\00\03"
    @camlExtern_call_helpers__gc_roots = global i64 0
    @camlExtern_call_helpers__data_begin = global i64 0
    @camlExtern_call_helpers__data_end = global i64 0
    @camlExtern_call_helpers__code_begin = global i64 0
    @camlExtern_call_helpers__code_end = global i64 0

    declare i64 @print_str(ptr)

    declare i64 @print_int(i64)

    define i64 @camlExtern_call_helpers__entry() {
      %1 = call i64 @print_str(ptr getelementptr inbounds nuw (i8, ptr @camlExtern_call_helpers.1, i64 8))
      %2 = call i64 @print_int(i64 85)
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}];
  verify_stdout t;
  [%expect {|
    Hello, MLIR!
    42
    |}]
