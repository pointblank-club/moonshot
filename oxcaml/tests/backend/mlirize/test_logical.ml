open Helpers

let%expect_test "logical operators" =
  let t =
    test_compile ~name:"logical"
      ~code:
        "\n\
        \    external ( < ) : int -> int -> bool = \"%lessthan\"\n\
        \    external ( && ) : bool -> bool -> bool = \"%sequand\"\n\
        \    external ( || ) : bool -> bool -> bool = \"%sequor\"\n\
        \    external not : bool -> bool = \"%boolnot\"\n\
        \    let conj = 3 < 5 && 2 < 1\n\
        \    let disj = 1 < 2 || 5 < 4\n\
        \    let neg = not (1 < 2)\n\
        \  "
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Logical {
      ocaml.entry {
        %0 = ocaml.constant 3 : !ocaml.int
        %1 = ocaml.constant 5 : !ocaml.int
        %2 = ocaml.cmp "lt" %0, %1 : !ocaml.int -> !ocaml.bool
        %3 = ocaml.constant 2 : !ocaml.int
        %4 = ocaml.constant 1 : !ocaml.int
        %5 = ocaml.cmp "lt" %3, %4 : !ocaml.int -> !ocaml.bool
        %6 = ocaml.and %2, %5 : !ocaml.bool
        %7 = ocaml.constant 1 : !ocaml.int
        %8 = ocaml.constant 2 : !ocaml.int
        %9 = ocaml.cmp "lt" %7, %8 : !ocaml.int -> !ocaml.bool
        %10 = ocaml.constant 5 : !ocaml.int
        %11 = ocaml.constant 4 : !ocaml.int
        %12 = ocaml.cmp "lt" %10, %11 : !ocaml.int -> !ocaml.bool
        %13 = ocaml.or %9, %12 : !ocaml.bool
        %14 = ocaml.constant 1 : !ocaml.int
        %15 = ocaml.constant 2 : !ocaml.int
        %16 = ocaml.cmp "lt" %14, %15 : !ocaml.int -> !ocaml.bool
        %17 = ocaml.not %16 : !ocaml.bool
      }
    }
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.func @camlLogical__entry() -> i64 {
        %0 = llvm.mlir.constant(7 : i64) : i64
        %1 = llvm.mlir.constant(11 : i64) : i64
        %2 = llvm.icmp "slt" %0, %1 : i64
        %3 = llvm.mlir.constant(3 : i64) : i64
        %4 = llvm.mlir.constant(1 : i64) : i64
        %5 = llvm.select %2, %3, %4 : i1, i64
        %6 = llvm.mlir.constant(5 : i64) : i64
        %7 = llvm.mlir.constant(3 : i64) : i64
        %8 = llvm.icmp "slt" %6, %7 : i64
        %9 = llvm.mlir.constant(3 : i64) : i64
        %10 = llvm.mlir.constant(1 : i64) : i64
        %11 = llvm.select %8, %9, %10 : i1, i64
        %12 = llvm.and %5, %11 : i64
        %13 = llvm.mlir.constant(3 : i64) : i64
        %14 = llvm.mlir.constant(5 : i64) : i64
        %15 = llvm.icmp "slt" %13, %14 : i64
        %16 = llvm.mlir.constant(3 : i64) : i64
        %17 = llvm.mlir.constant(1 : i64) : i64
        %18 = llvm.select %15, %16, %17 : i1, i64
        %19 = llvm.mlir.constant(11 : i64) : i64
        %20 = llvm.mlir.constant(9 : i64) : i64
        %21 = llvm.icmp "slt" %19, %20 : i64
        %22 = llvm.mlir.constant(3 : i64) : i64
        %23 = llvm.mlir.constant(1 : i64) : i64
        %24 = llvm.select %21, %22, %23 : i1, i64
        %25 = llvm.or %18, %24 : i64
        %26 = llvm.mlir.constant(3 : i64) : i64
        %27 = llvm.mlir.constant(5 : i64) : i64
        %28 = llvm.icmp "slt" %26, %27 : i64
        %29 = llvm.mlir.constant(3 : i64) : i64
        %30 = llvm.mlir.constant(1 : i64) : i64
        %31 = llvm.select %28, %29, %30 : i1, i64
        %32 = llvm.mlir.constant(2 : i64) : i64
        %33 = llvm.xor %31, %32 : i64
        %34 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %34 : i64
      }
      llvm.mlir.global external @camlLogical__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlLogical__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlLogical__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlLogical__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlLogical__code_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlLogical__frametable(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'LLVMDialectModule'
    source_filename = "LLVMDialectModule"

    @camlLogical__gc_roots = global i64 0
    @camlLogical__data_begin = global i64 0
    @camlLogical__data_end = global i64 0
    @camlLogical__code_begin = global i64 0
    @camlLogical__code_end = global i64 0
    @camlLogical__frametable = global i64 0

    define i64 @camlLogical__entry() {
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}]
