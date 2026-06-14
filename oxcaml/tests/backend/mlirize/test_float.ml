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

let%expect_test "float_cmp" =
  let t =
    test_compile ~name:"float_cmp"
      ~code:
        "\n\
        \    external ( < ) : float -> float -> bool = \"%lessthan\"\n\
        \    external ( = ) : float -> float -> bool = \"%equal\"\n\
        \    let a = 1.5 < 2.0\n\
        \    let b = 1.5 = 2.0\n\
        \  "
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Float_cmp {
      ocaml.entry {
        %0 = ocaml.constant 1.500000e+00 : f64 : !ocaml.float
        %1 = ocaml.constant 2.000000e+00 : f64 : !ocaml.float
        %2 = ocaml.float_cmp "lt" %0, %1 : !ocaml.float -> !ocaml.int
        %3 = ocaml.constant 1.500000e+00 : f64 : !ocaml.float
        %4 = ocaml.constant 2.000000e+00 : f64 : !ocaml.float
        %5 = ocaml.float_cmp "eq" %3, %4 : !ocaml.float -> !ocaml.int
      }
    }
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.mlir.global external constant @camlFloat_cmp.1("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlFloat_cmp.2("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlFloat_cmp.3("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlFloat_cmp.4("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@") {addr_space = 0 : i32}
      llvm.func @camlFloat_cmp__entry() -> i64 {
        %0 = llvm.mlir.addressof @camlFloat_cmp.1 : !llvm.ptr
        %1 = llvm.getelementptr %0[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %2 = llvm.mlir.addressof @camlFloat_cmp.2 : !llvm.ptr
        %3 = llvm.getelementptr %2[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %4 = llvm.load %1 : !llvm.ptr -> f64
        %5 = llvm.load %3 : !llvm.ptr -> f64
        %6 = llvm.fcmp "olt" %4, %5 : f64
        %7 = llvm.zext %6 : i1 to i64
        %8 = llvm.mlir.constant(1 : i64) : i64
        %9 = llvm.shl %7, %8 : i64
        %10 = llvm.or %9, %8 : i64
        %11 = llvm.mlir.addressof @camlFloat_cmp.3 : !llvm.ptr
        %12 = llvm.getelementptr %11[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %13 = llvm.mlir.addressof @camlFloat_cmp.4 : !llvm.ptr
        %14 = llvm.getelementptr %13[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %15 = llvm.load %12 : !llvm.ptr -> f64
        %16 = llvm.load %14 : !llvm.ptr -> f64
        %17 = llvm.fcmp "oeq" %15, %16 : f64
        %18 = llvm.zext %17 : i1 to i64
        %19 = llvm.mlir.constant(1 : i64) : i64
        %20 = llvm.shl %18, %19 : i64
        %21 = llvm.or %20, %19 : i64
        %22 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %22 : i64
      }
      llvm.mlir.global external @camlFloat_cmp__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat_cmp__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat_cmp__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat_cmp__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat_cmp__code_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat_cmp__frametable(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'LLVMDialectModule'
    source_filename = "LLVMDialectModule"

    @camlFloat_cmp.1 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?"
    @camlFloat_cmp.2 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@"
    @camlFloat_cmp.3 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?"
    @camlFloat_cmp.4 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@"
    @camlFloat_cmp__gc_roots = global i64 0
    @camlFloat_cmp__data_begin = global i64 0
    @camlFloat_cmp__data_end = global i64 0
    @camlFloat_cmp__code_begin = global i64 0
    @camlFloat_cmp__code_end = global i64 0
    @camlFloat_cmp__frametable = global i64 0

    define i64 @camlFloat_cmp__entry() {
      %1 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlFloat_cmp.1, i64 8), align 8
      %2 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlFloat_cmp.2, i64 8), align 8
      %3 = fcmp olt double %1, %2
      %4 = zext i1 %3 to i64
      %5 = shl i64 %4, 1
      %6 = or i64 %5, 1
      %7 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlFloat_cmp.3, i64 8), align 8
      %8 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlFloat_cmp.4, i64 8), align 8
      %9 = fcmp oeq double %7, %8
      %10 = zext i1 %9 to i64
      %11 = shl i64 %10, 1
      %12 = or i64 %11, 1
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}]

let%expect_test "float_cmp_run" =
  let t =
    test_compile_and_run ~name:"float_cmp_run"
      ~code:
        "\n\
        \    external ( < ) : float -> float -> bool = \"%lessthan\"\n\
        \    external print_int : bool -> unit = \"print_int\"\n\
        \    let () = print_int (1.5 < 2.0)\n\
        \    let () = print_int (2.0 < 1.5)\n\
        \  "
  in
  verify_stdout t;
  [%expect {|
    1
    0
    |}]
