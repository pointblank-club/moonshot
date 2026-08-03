open Helpers

let%expect_test "constants" =
  let t =
    test_compile ~name:"constants"
      ~code:{|
    let x = 42
    let s = "hello"
    |}
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Constants {
      ocaml.entry {
        %0 = ocaml.constant 42 : !ocaml.int loc(#loc1)
        %1 = ocaml.constant "hello" : !ocaml.string loc(#loc2)
      } loc(#loc)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("constants.ml":2:13)
    #loc2 = loc("constants.ml":3:13)
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
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'constants.ml'
    source_filename = "constants.ml"

    @camlConstants.1 = constant [16 x i8] c"\FC\07\00\00\00\00\00\00hello\00\00\02"
    @camlConstants__gc_roots = global i64 0
    @camlConstants__data_begin = global i64 0
    @camlConstants__data_end = global i64 0
    @camlConstants__code_begin = global i64 0
    @camlConstants__code_end = global i64 0

    define i64 @camlConstants__entry() {
      ret i64 1
    }

    !llvm.module.flags = !{!0}
    !llvm.ident = !{!1}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    !1 = !{!"OCaml MLIR dialect unknown"}
    |}]

let%expect_test "unit_constant" =
  let t = test_compile ~name:"unit_constant" ~code:{|
    let u = ()
    |} in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Unit_constant {
      ocaml.entry {
        %0 = ocaml.constant unit : !ocaml.unit loc(#loc1)
      } loc(#loc)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("unit_constant.ml":2:13)
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.func @camlUnit_constant__entry() -> i64 {
        %0 = llvm.mlir.constant(1 : i64) : i64
        %1 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %1 : i64
      }
      llvm.mlir.global external @camlUnit_constant__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlUnit_constant__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlUnit_constant__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlUnit_constant__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlUnit_constant__code_end(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'unit_constant.ml'
    source_filename = "unit_constant.ml"

    @camlUnit_constant__gc_roots = global i64 0
    @camlUnit_constant__data_begin = global i64 0
    @camlUnit_constant__data_end = global i64 0
    @camlUnit_constant__code_begin = global i64 0
    @camlUnit_constant__code_end = global i64 0

    define i64 @camlUnit_constant__entry() {
      ret i64 1
    }

    !llvm.module.flags = !{!0}
    !llvm.ident = !{!1}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    !1 = !{!"OCaml MLIR dialect unknown"}
    |}]
