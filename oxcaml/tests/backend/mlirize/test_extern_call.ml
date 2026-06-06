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
        %0 = ocaml.string "Hello from C puts!" : !ocaml.string
        %1 = ocaml.extern_call @puts(%0 : !ocaml.string) : (!ocaml.string) -> !ocaml.int -> !ocaml.int
        %2 = ocaml.extern_call @puts_int(%1 : !ocaml.int) : (!ocaml.int) -> !ocaml.value -> !ocaml.value
      }
      ocaml.extern @puts {target = "caml_puts"} : (!ocaml.string) -> !ocaml.int
      ocaml.extern @puts_int {target = "caml_puts_int"} : (!ocaml.int) -> !ocaml.value
    }
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
      llvm.mlir.global external @camlExtern_call_assign__frametable(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'LLVMDialectModule'
    source_filename = "LLVMDialectModule"

    @camlExtern_call_assign.1 = constant [32 x i8] c"\FC\0F\00\00\00\00\00\00Hello from C puts!\00\00\00\00\00\05"
    @camlExtern_call_assign__gc_roots = global i64 0
    @camlExtern_call_assign__data_begin = global i64 0
    @camlExtern_call_assign__data_end = global i64 0
    @camlExtern_call_assign__code_begin = global i64 0
    @camlExtern_call_assign__code_end = global i64 0
    @camlExtern_call_assign__frametable = global i64 0

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
