open Helpers

let%expect_test "float comparison" =
  let t =
    test_compile ~name:"floatcmp"
      ~code:
        "\n\
        \    external ( < ) : float -> float -> bool = \"%lessthan\"\n\
        \    external ( > ) : float -> float -> bool = \"%greaterthan\"\n\
        \    external ( = ) : float -> float -> bool = \"%equal\"\n\
        \    let lt = 1.5 < 2.5\n\
        \    let gt = 3.0 > 1.0\n\
        \    let eq = 2.0 = 2.0\n\
        \  "
  in
  verify_mlir t;
  [%expect {|
    ocaml.module @Floatcmp {
      ocaml.entry {
        %0 = ocaml.float 1.500000e+00 : !ocaml.float
        %1 = ocaml.float 2.500000e+00 : !ocaml.float
        %2 = ocaml.fcmp "lt" %0, %1 : !ocaml.float -> !ocaml.int
        %3 = ocaml.float 3.000000e+00 : !ocaml.float
        %4 = ocaml.float 1.000000e+00 : !ocaml.float
        %5 = ocaml.fcmp "gt" %3, %4 : !ocaml.float -> !ocaml.int
        %6 = ocaml.float 2.000000e+00 : !ocaml.float
        %7 = ocaml.float 2.000000e+00 : !ocaml.float
        %8 = ocaml.fcmp "eq" %6, %7 : !ocaml.float -> !ocaml.int
      }
    }
    |}];
  verify_std_mlir t;
  [%expect {|
    module {
      llvm.func @camlFloatcmp__entry() -> i64 {
        %0 = llvm.mlir.constant(1.500000e+00 : f64) : f64
        %1 = llvm.mlir.constant(2.500000e+00 : f64) : f64
        %2 = llvm.fcmp "olt" %0, %1 : f64
        %3 = llvm.zext %2 : i1 to i64
        %4 = llvm.mlir.constant(1 : i64) : i64
        %5 = llvm.shl %3, %4 : i64
        %6 = llvm.or %5, %4 : i64
        %7 = llvm.mlir.constant(3.000000e+00 : f64) : f64
        %8 = llvm.mlir.constant(1.000000e+00 : f64) : f64
        %9 = llvm.fcmp "ogt" %7, %8 : f64
        %10 = llvm.zext %9 : i1 to i64
        %11 = llvm.mlir.constant(1 : i64) : i64
        %12 = llvm.shl %10, %11 : i64
        %13 = llvm.or %12, %11 : i64
        %14 = llvm.mlir.constant(2.000000e+00 : f64) : f64
        %15 = llvm.mlir.constant(2.000000e+00 : f64) : f64
        %16 = llvm.fcmp "oeq" %14, %15 : f64
        %17 = llvm.zext %16 : i1 to i64
        %18 = llvm.mlir.constant(1 : i64) : i64
        %19 = llvm.shl %17, %18 : i64
        %20 = llvm.or %19, %18 : i64
        %21 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %21 : i64
      }
      llvm.mlir.global external @camlFloatcmp__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloatcmp__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloatcmp__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloatcmp__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloatcmp__code_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFloatcmp__frametable(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect {|
    ; ModuleID = 'LLVMDialectModule'
    source_filename = "LLVMDialectModule"

    @camlFloatcmp__gc_roots = global i64 0
    @camlFloatcmp__data_begin = global i64 0
    @camlFloatcmp__data_end = global i64 0
    @camlFloatcmp__code_begin = global i64 0
    @camlFloatcmp__code_end = global i64 0
    @camlFloatcmp__frametable = global i64 0

    define i64 @camlFloatcmp__entry() {
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}]
