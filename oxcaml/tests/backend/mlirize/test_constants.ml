open Helpers

let%expect_test "constants" =
  let t =
    test_compile ~name:"constants"
      ~code:"\n    let x = 42\n    let s = \"hello\"\n  "
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Constants {
      ocaml.entry {
        %0 = ocaml.constant 42 : !ocaml.int
        %1 = ocaml.constant "hello" : !ocaml.string
      }
    }
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.mlir.global external constant @camlConstants.1("\FC\07\00\00\00\00\00\00hello\00\00\02") {addr_space = 0 : i32}
      llvm.func @camlConstants__entry() -> i64 {
        %0 = llvm.mlir.constant(85 : i64) : i64
        %1 = llvm.mlir.addressof @camlConstants.1 : !llvm.ptr
        %2 = llvm.getelementptr %1[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %3 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %3 : i64
      }
      llvm.mlir.global external @camlConstants__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlConstants__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlConstants__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlConstants__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlConstants__code_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlConstants__frametable(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'LLVMDialectModule'
    source_filename = "LLVMDialectModule"

    @camlConstants.1 = constant [16 x i8] c"\FC\07\00\00\00\00\00\00hello\00\00\02"
    @camlConstants__gc_roots = global i64 0
    @camlConstants__data_begin = global i64 0
    @camlConstants__data_end = global i64 0
    @camlConstants__code_begin = global i64 0
    @camlConstants__code_end = global i64 0
    @camlConstants__frametable = global i64 0

    define i64 @camlConstants__entry() {
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}]
