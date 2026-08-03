open Helpers

let%expect_test "float" =
  let t =
    test_compile ~name:"float" ~code:{|
    let x = 1.5
    let y = 2.0
    |}
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Float {
      ocaml.entry {
        %0 = ocaml.constant 1.500000e+00 : f64 : !ocaml.float loc(#loc1)
        %1 = ocaml.constant 2.000000e+00 : f64 : !ocaml.float loc(#loc2)
      } loc(#loc)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("float.ml":2:13)
    #loc2 = loc("float.ml":3:13)
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
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'float.ml'
    source_filename = "float.ml"

    @camlFloat.1 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?"
    @camlFloat.2 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@"
    @camlFloat__gc_roots = global i64 0
    @camlFloat__data_begin = global i64 0
    @camlFloat__data_end = global i64 0
    @camlFloat__code_begin = global i64 0
    @camlFloat__code_end = global i64 0

    define i64 @camlFloat__entry() {
      ret i64 1
    }

    !llvm.module.flags = !{!0}
    !llvm.ident = !{!1}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    !1 = !{!"OCaml MLIR dialect unknown"}
    |}]

let%expect_test "float_arith" =
  let t =
    test_compile ~name:"float_arith"
      ~code:
        {|
    external ( +. ) : float -> float -> float = "%addfloat"
    external ( *. ) : float -> float -> float = "%mulfloat"
    let res = 1.5 +. 2.0 *. 3.0
    |}
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Float_arith {
      ocaml.entry {
        %0 = ocaml.constant 1.500000e+00 : f64 : !ocaml.float loc(#loc1)
        %1 = ocaml.constant 2.000000e+00 : f64 : !ocaml.float loc(#loc2)
        %2 = ocaml.constant 3.000000e+00 : f64 : !ocaml.float loc(#loc3)
        %3 = ocaml.binop "*" %1, %2 : !ocaml.float, !ocaml.float -> !ocaml.float loc(#loc2)
        %4 = ocaml.binop "+" %0, %3 : !ocaml.float, !ocaml.float -> !ocaml.float loc(#loc1)
      } loc(#loc)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("float_arith.ml":4:15)
    #loc2 = loc("float_arith.ml":4:22)
    #loc3 = loc("float_arith.ml":4:29)
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
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'float_arith.ml'
    source_filename = "float_arith.ml"

    @camlFloat_arith.1 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?"
    @camlFloat_arith.2 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@"
    @camlFloat_arith.3 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\08@"
    @camlFloat_arith__gc_roots = global i64 0
    @camlFloat_arith__data_begin = global i64 0
    @camlFloat_arith__data_end = global i64 0
    @camlFloat_arith__code_begin = global i64 0
    @camlFloat_arith__code_end = global i64 0

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
    !llvm.ident = !{!1}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    !1 = !{!"OCaml MLIR dialect unknown"}
    |}]

let%expect_test "float_arith_run" =
  let t =
    test_compile_and_run ~name:"float_arith_run"
      ~code:
        {|
    external ( +. ) : float -> float -> float = "%addfloat"
    external ( *. ) : float -> float -> float = "%mulfloat"
    external print_float : float -> unit = "print_float"
    let () = print_float (1.5 +. 2.0 *. 3.0)
    |}
  in
  verify_stdout t;
  [%expect {| 7.5 |}]

let%expect_test "float_cmp" =
  let t =
    test_compile ~name:"float_cmp"
      ~code:
        {|
    external ( < ) : float -> float -> bool = "%lessthan"
    external ( <= ) : float -> float -> bool = "%lessequal"
    external ( >= ) : float -> float -> bool = "%greaterequal"
    external ( = ) : float -> float -> bool = "%equal"
    let a = 1.5 < 2.0
    let c = 1.5 <= 2.0
    let d = 2.0 >= 1.5
    let b = 1.5 = 2.0
    |}
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Float_cmp {
      ocaml.entry {
        %0 = ocaml.constant 1.500000e+00 : f64 : !ocaml.float loc(#loc1)
        %1 = ocaml.constant 2.000000e+00 : f64 : !ocaml.float loc(#loc2)
        %2 = ocaml.cmp "lt" %0, %1 : !ocaml.float -> !ocaml.bool loc(#loc1)
        %3 = ocaml.constant 1.500000e+00 : f64 : !ocaml.float loc(#loc3)
        %4 = ocaml.constant 2.000000e+00 : f64 : !ocaml.float loc(#loc4)
        %5 = ocaml.cmp "le" %3, %4 : !ocaml.float -> !ocaml.bool loc(#loc3)
        %6 = ocaml.constant 2.000000e+00 : f64 : !ocaml.float loc(#loc5)
        %7 = ocaml.constant 1.500000e+00 : f64 : !ocaml.float loc(#loc6)
        %8 = ocaml.cmp "ge" %6, %7 : !ocaml.float -> !ocaml.bool loc(#loc5)
        %9 = ocaml.constant 1.500000e+00 : f64 : !ocaml.float loc(#loc7)
        %10 = ocaml.constant 2.000000e+00 : f64 : !ocaml.float loc(#loc8)
        %11 = ocaml.cmp "eq" %9, %10 : !ocaml.float -> !ocaml.bool loc(#loc7)
      } loc(#loc)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("float_cmp.ml":6:13)
    #loc2 = loc("float_cmp.ml":6:19)
    #loc3 = loc("float_cmp.ml":7:13)
    #loc4 = loc("float_cmp.ml":7:20)
    #loc5 = loc("float_cmp.ml":8:13)
    #loc6 = loc("float_cmp.ml":8:20)
    #loc7 = loc("float_cmp.ml":9:13)
    #loc8 = loc("float_cmp.ml":9:19)
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.mlir.global external constant @camlFloat_cmp.1("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlFloat_cmp.2("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlFloat_cmp.3("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlFloat_cmp.4("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlFloat_cmp.5("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlFloat_cmp.6("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlFloat_cmp.7("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?") {addr_space = 0 : i32}
      llvm.mlir.global external constant @camlFloat_cmp.8("\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@") {addr_space = 0 : i32}
      llvm.func @camlFloat_cmp__entry() -> i64 {
        %0 = llvm.mlir.addressof @camlFloat_cmp.1 : !llvm.ptr
        %1 = llvm.getelementptr %0[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %2 = llvm.mlir.addressof @camlFloat_cmp.2 : !llvm.ptr
        %3 = llvm.getelementptr %2[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %4 = llvm.load %1 : !llvm.ptr -> f64
        %5 = llvm.load %3 : !llvm.ptr -> f64
        %6 = llvm.fcmp "olt" %4, %5 : f64
        %7 = llvm.mlir.constant(3 : i64) : i64
        %8 = llvm.mlir.constant(1 : i64) : i64
        %9 = llvm.select %6, %7, %8 : i1, i64
        %10 = llvm.mlir.addressof @camlFloat_cmp.3 : !llvm.ptr
        %11 = llvm.getelementptr %10[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %12 = llvm.mlir.addressof @camlFloat_cmp.4 : !llvm.ptr
        %13 = llvm.getelementptr %12[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %14 = llvm.load %11 : !llvm.ptr -> f64
        %15 = llvm.load %13 : !llvm.ptr -> f64
        %16 = llvm.fcmp "ole" %14, %15 : f64
        %17 = llvm.mlir.constant(3 : i64) : i64
        %18 = llvm.mlir.constant(1 : i64) : i64
        %19 = llvm.select %16, %17, %18 : i1, i64
        %20 = llvm.mlir.addressof @camlFloat_cmp.5 : !llvm.ptr
        %21 = llvm.getelementptr %20[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %22 = llvm.mlir.addressof @camlFloat_cmp.6 : !llvm.ptr
        %23 = llvm.getelementptr %22[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %24 = llvm.load %21 : !llvm.ptr -> f64
        %25 = llvm.load %23 : !llvm.ptr -> f64
        %26 = llvm.fcmp "oge" %24, %25 : f64
        %27 = llvm.mlir.constant(3 : i64) : i64
        %28 = llvm.mlir.constant(1 : i64) : i64
        %29 = llvm.select %26, %27, %28 : i1, i64
        %30 = llvm.mlir.addressof @camlFloat_cmp.7 : !llvm.ptr
        %31 = llvm.getelementptr %30[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %32 = llvm.mlir.addressof @camlFloat_cmp.8 : !llvm.ptr
        %33 = llvm.getelementptr %32[8] : (!llvm.ptr) -> !llvm.ptr, i8
        %34 = llvm.load %31 : !llvm.ptr -> f64
        %35 = llvm.load %33 : !llvm.ptr -> f64
        %36 = llvm.fcmp "oeq" %34, %35 : f64
        %37 = llvm.mlir.constant(3 : i64) : i64
        %38 = llvm.mlir.constant(1 : i64) : i64
        %39 = llvm.select %36, %37, %38 : i1, i64
        %40 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %40 : i64
      }
      llvm.mlir.global external @camlFloat_cmp__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat_cmp__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat_cmp__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat_cmp__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloat_cmp__code_end(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'float_cmp.ml'
    source_filename = "float_cmp.ml"

    @camlFloat_cmp.1 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?"
    @camlFloat_cmp.2 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@"
    @camlFloat_cmp.3 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?"
    @camlFloat_cmp.4 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@"
    @camlFloat_cmp.5 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@"
    @camlFloat_cmp.6 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?"
    @camlFloat_cmp.7 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\F8?"
    @camlFloat_cmp.8 = constant [16 x i8] c"\FD\07\00\00\00\00\00\00\00\00\00\00\00\00\00@"
    @camlFloat_cmp__gc_roots = global i64 0
    @camlFloat_cmp__data_begin = global i64 0
    @camlFloat_cmp__data_end = global i64 0
    @camlFloat_cmp__code_begin = global i64 0
    @camlFloat_cmp__code_end = global i64 0

    define i64 @camlFloat_cmp__entry() {
      %1 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlFloat_cmp.1, i64 8), align 8
      %2 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlFloat_cmp.2, i64 8), align 8
      %3 = fcmp olt double %1, %2
      %4 = select i1 %3, i64 3, i64 1
      %5 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlFloat_cmp.3, i64 8), align 8
      %6 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlFloat_cmp.4, i64 8), align 8
      %7 = fcmp ole double %5, %6
      %8 = select i1 %7, i64 3, i64 1
      %9 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlFloat_cmp.5, i64 8), align 8
      %10 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlFloat_cmp.6, i64 8), align 8
      %11 = fcmp oge double %9, %10
      %12 = select i1 %11, i64 3, i64 1
      %13 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlFloat_cmp.7, i64 8), align 8
      %14 = load double, ptr getelementptr inbounds nuw (i8, ptr @camlFloat_cmp.8, i64 8), align 8
      %15 = fcmp oeq double %13, %14
      %16 = select i1 %15, i64 3, i64 1
      ret i64 1
    }

    !llvm.module.flags = !{!0}
    !llvm.ident = !{!1}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    !1 = !{!"OCaml MLIR dialect unknown"}
    |}]

let%expect_test "float_cmp_run" =
  let t =
    test_compile_and_run ~name:"float_cmp_run"
      ~code:
        {|
    external ( < ) : float -> float -> bool = "%lessthan"
    external print_int : bool -> unit = "print_int"
    let () = print_int (1.5 < 2.0)
    let () = print_int (2.0 < 1.5)
    |}
  in
  verify_stdout t;
  [%expect {|
    1
    0
    |}]
