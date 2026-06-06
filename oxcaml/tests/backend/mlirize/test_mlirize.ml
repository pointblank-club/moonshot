open Test_helpers

let%expect_test "empty module" =
  test_compile ~name:"empty" ~code:"";
  [%expect
    {|
    === stdout ===
    Compiling module Empty to MLIR
    Generated object file: <path_to_object_file>
    === mlir ===
    ocaml.module @Empty {
      ocaml.entry {
      }
    }
    === std_mlir ===
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
    === llvm ===
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

let%expect_test "constants" =
  test_compile ~name:"constants"
    ~code:"\n    let x = 42\n    let s = \"hello\"\n  ";
  [%expect
    {|
    === stdout ===
    Compiling module Constants to MLIR
    Generated object file: <path_to_object_file>
    === mlir ===
    ocaml.module @Constants {
      ocaml.entry {
        %0 = ocaml.int 42 : !ocaml.int
        %1 = ocaml.string "hello" : !ocaml.string
      }
    }
    === std_mlir ===
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
    === llvm ===
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

let%expect_test "arithmetic" =
  test_compile ~name:"arith"
    ~code:
      "\n\
      \    external ( + ) : int -> int -> int = \"%addint\"\n\
      \    external ( * ) : int -> int -> int = \"%mulint\"\n\
      \    let add a b = a + b\n\
      \    let res = 1 + 2 * 3\n\
      \  ";
  [%expect
    {|
    === stdout ===
    Compiling module Arith to MLIR
    Generated object file: <path_to_object_file>
    === mlir ===
    ocaml.module @Arith {
      ocaml.entry {
        %0 = ocaml.int 1 : !ocaml.int
        %1 = ocaml.int 2 : !ocaml.int
        %2 = ocaml.int 3 : !ocaml.int
        %3 = ocaml.binop "*" %1, %2 : !ocaml.int, !ocaml.int -> !ocaml.int
        %4 = ocaml.binop "+" %0, %3 : !ocaml.int, !ocaml.int -> !ocaml.int
      }
    }
    === std_mlir ===
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
    === llvm ===
    ; ModuleID = 'LLVMDialectModule'
    source_filename = "LLVMDialectModule"

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

let%expect_test "let bindings and sequences" =
  test_compile ~name:"let_seq"
    ~code:
      "\n\
      \    external ( + ) : int -> int -> int = \"%addint\"\n\
      \    let test () =\n\
      \      let x = 10 in\n\
      \      let y = 20 in\n\
      \      x + y\n\
      \  ";
  [%expect
    {|
    === stdout ===
    Compiling module Let_seq to MLIR
    Generated object file: <path_to_object_file>
    === mlir ===
    ocaml.module @Let_seq {
      ocaml.entry {
      }
    }
    === std_mlir ===
    module {
      llvm.func @camlLet_seq__entry() -> i64 {
        %0 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %0 : i64
      }
      llvm.mlir.global external @camlLet_seq__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlLet_seq__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlLet_seq__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlLet_seq__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlLet_seq__code_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlLet_seq__frametable(0 : i64) {addr_space = 0 : i32} : i64
    }
    === llvm ===
    ; ModuleID = 'LLVMDialectModule'
    source_filename = "LLVMDialectModule"

    @camlLet_seq__gc_roots = global i64 0
    @camlLet_seq__data_begin = global i64 0
    @camlLet_seq__data_end = global i64 0
    @camlLet_seq__code_begin = global i64 0
    @camlLet_seq__code_end = global i64 0
    @camlLet_seq__frametable = global i64 0

    define i64 @camlLet_seq__entry() {
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}]
