open Helpers

let%expect_test "empty module" =
  let t = test_compile ~name:"empty" ~code:"" in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Empty {
      ocaml.entry {
      }
    }
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.func @camlEmpty__entry() -> i64 {
        %0 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %0 : i64
      }
      llvm.mlir.global external @camlEmpty__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlEmpty__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlEmpty__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlEmpty__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlEmpty__code_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlEmpty__frametable(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'LLVMDialectModule'
    source_filename = "LLVMDialectModule"

    @camlEmpty__gc_roots = global i64 0
    @camlEmpty__data_begin = global i64 0
    @camlEmpty__data_end = global i64 0
    @camlEmpty__code_begin = global i64 0
    @camlEmpty__code_end = global i64 0
    @camlEmpty__frametable = global i64 0

    define i64 @camlEmpty__entry() {
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}]
