open Helpers

let%expect_test "float" =
  let t =
    test_compile ~name:"float" ~code:"\n    let x = 1.5\n    let y = 2.0\n  "
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Float {
      ocaml.entry {
        %0 = ocaml.constant 1.500000e+00 : f64 : !ocaml.float
        %1 = ocaml.constant 2.000000e+00 : f64 : !ocaml.float
      }
    }
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.mlir.global external constant @camlFloat.1("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlFloat.2("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@") {addr_space = 0 : i32}
      llvm.func @camlFloat__entry() -> i64 {
        %0 = llvm.mlir.addressof @camlFloat.1 : !llvm.ptr
        %1 = llvm.getelementptr %0[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %2 = llvm.mlir.addressof @camlFloat.2 : !llvm.ptr
        %3 = llvm.getelementptr %2[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %4 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %4 : i64
      }
      llvm.mlir.global external @camlFloat__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat__code_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat__frametable(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'LLVMDialectModule'
    source_filename = "LLVMDialectModule"

    @camlFloat.1 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?"
    @camlFloat.2 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@"
    @camlFloat__gc_roots = global i64 0
    @camlFloat__data_begin = global i64 0
    @camlFloat__data_end = global i64 0
    @camlFloat__code_begin = global i64 0
    @camlFloat__code_end = global i64 0
    @camlFloat__frametable = global i64 0

    define i64 @camlFloat__entry() {
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}]

let%expect_test "float_arith" =
  let t =
    test_compile ~name:"float_arith"
      ~code:
        "\n\
        \    external ( +. ) : float -> float -> float = \"%addfloat\"\n\
        \    external ( *. ) : float -> float -> float = \"%mulfloat\"\n\
        \    let res = 1.5 +. 2.0 *. 3.0\n\
        \  "
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Float_arith {
      ocaml.entry {
        %0 = ocaml.constant 1.500000e+00 : f64 : !ocaml.float
        %1 = ocaml.constant 2.000000e+00 : f64 : !ocaml.float
        %2 = ocaml.constant 3.000000e+00 : f64 : !ocaml.float
        %3 = ocaml.float_binop "*" %1, %2 : !ocaml.float, !ocaml.float -> !ocaml.float
        %4 = ocaml.float_binop "+" %0, %3 : !ocaml.float, !ocaml.float -> !ocaml.float
      }
    }
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.mlir.global external constant @camlFloat_arith.1("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlFloat_arith.2("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlFloat_arith.3("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\08@") {addr_space = 0 : i32}
      llvm.func @caml_copy_double(f64) -> i64
      llvm.func @camlFloat_arith__entry() -> i64 {
        %0 = llvm.mlir.addressof @camlFloat_arith.1 : !llvm.ptr
        %1 = llvm.getelementptr %0[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %2 = llvm.mlir.addressof @camlFloat_arith.2 : !llvm.ptr
        %3 = llvm.getelementptr %2[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %4 = llvm.mlir.addressof @camlFloat_arith.3 : !llvm.ptr
        %5 = llvm.getelementptr %4[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %6 = llvm.load %3 : !llvm.ptr -> f64
        %7 = llvm.load %5 : !llvm.ptr -> f64
        %8 = llvm.fmul %6, %7 : f64
        %9 = llvm.call @caml_copy_double(%8) : (f64) -> i64
        %10 = llvm.inttoptr %9 : i64 to !llvm.ptr
        %11 = llvm.load %1 : !llvm.ptr -> f64
        %12 = llvm.load %10 : !llvm.ptr -> f64
        %13 = llvm.fadd %11, %12 : f64
        %14 = llvm.call @caml_copy_double(%13) : (f64) -> i64
        %15 = llvm.inttoptr %14 : i64 to !llvm.ptr
        %16 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %16 : i64
      }
      llvm.mlir.global external @camlFloat_arith__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat_arith__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat_arith__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat_arith__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat_arith__code_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat_arith__frametable(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'LLVMDialectModule'
    source_filename = "LLVMDialectModule"

    @camlFloat_arith.1 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?"
    @camlFloat_arith.2 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@"
    @camlFloat_arith.3 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\08@"
    @camlFloat_arith__gc_roots = global i64 0
    @camlFloat_arith__data_begin = global i64 0
    @camlFloat_arith__data_end = global i64 0
    @camlFloat_arith__code_begin = global i64 0
    @camlFloat_arith__code_end = global i64 0
    @camlFloat_arith__frametable = global i64 0

    declare i64 @caml_copy_double(double)

    define i64 @camlFloat_arith__entry() {
      %1 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlFloat_arith.2, i64 8), align 8
      %2 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlFloat_arith.3, i64 8), align 8
      %3 = fmul double %1, %2
      %4 = call i64 @caml_copy_double(double %3)
      %5 = inttoptr i64 %4 to ptr
      %6 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlFloat_arith.1, i64 8), align 8
      %7 = load double, ptr %5, align 8
      %8 = fadd double %6, %7
      %9 = call i64 @caml_copy_double(double %8)
      %10 = inttoptr i64 %9 to ptr
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}]

let%expect_test "float_arith_run" =
  let t =
    test_compile_and_run ~name:"float_arith_run"
      ~code:
        "\n\
        \    external ( +. ) : float -> float -> float = \"%addfloat\"\n\
        \    external ( *. ) : float -> float -> float = \"%mulfloat\"\n\
        \    external print_float : float -> unit = \"print_float\"\n\
        \    let () = print_float (1.5 +. 2.0 *. 3.0)\n\
        \  "
  in
  verify_stdout t;
  [%expect {| 7.5 |}]
