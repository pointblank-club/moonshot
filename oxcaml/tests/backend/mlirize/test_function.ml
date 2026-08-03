open Helpers

let%expect_test "function definition" =
  let t =
    test_compile ~name:"function_def"
      ~code:
        "\n\
        \    external ( + ) : int -> int -> int = \"%addint\"\n\
        \    let add x y = x + y\n\
        \  "
  in
  verify_mlir t;
  [%expect
    {|
    #loc1 = loc("function_def.ml":3:19)
    ocaml.module @Function_def {
      ocaml.entry {
      } loc(#loc)
      ocaml.function @add("camlFunction_def__add_5") : (!ocaml.int, !ocaml.int) -> !ocaml.int {
      ^bb0(%arg0: !ocaml.int loc("function_def.ml":3:19), %arg1: !ocaml.int loc("function_def.ml":3:19)):
        %0 = ocaml.binop "+" %arg0, %arg1 : !ocaml.int, !ocaml.int -> !ocaml.int loc(#loc1)
        ocaml.return %0 : !ocaml.int loc(#loc1)
      } loc(#loc1)
    } loc(#loc)
    #loc = loc(unknown)
    |}];
  verify_std_mlir t;
  [%expect
    {|
    module {
      llvm.func @camlFunction_def__entry() -> i64 {
        %0 = llvm.mlir.constant(1 : i64) : i64
        llvm.return %0 : i64
      }
      llvm.func @camlFunction_def__add_5(%arg0: i64, %arg1: i64) -> i64 {
        %0 = llvm.add %arg0, %arg1 : i64
        %1 = llvm.mlir.constant(1 : i64) : i64
        %2 = llvm.sub %0, %1 : i64
        llvm.return %2 : i64
      }
      llvm.mlir.global external @camlFunction_def__gc_roots(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFunction_def__data_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFunction_def__data_end(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFunction_def__code_begin(0 : i64) {addr_space = 0 : i32} : i64
      llvm.mlir.global external @camlFunction_def__code_end(0 : i64) {addr_space = 0 : i32} : i64
    }
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'function_def.ml'
    source_filename = "function_def.ml"

    @camlFunction_def__gc_roots = global i64 0
    @camlFunction_def__data_begin = global i64 0
    @camlFunction_def__data_end = global i64 0
    @camlFunction_def__code_begin = global i64 0
    @camlFunction_def__code_end = global i64 0

    define i64 @camlFunction_def__entry() {
      ret i64 1
    }

    define i64 @camlFunction_def__add_5(i64 %0, i64 %1) {
      %3 = add i64 %0, %1
      %4 = sub i64 %3, 1
      ret i64 %4
    }

    !llvm.module.flags = !{!0}
    !llvm.ident = !{!1}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    !1 = !{!"OCaml MLIR dialect unknown"}
    |}]

let%expect_test "function call" =
  let t =
    test_compile ~name:"function_call"
      ~code:
        "\n\
        \    external ( + ) : int -> int -> int = \"%addint\"\n\
        \    let add x y = x + y\n\
        \    let res = add 1 2\n\
        \  "
  in
  verify_mlir t;
  [%expect
    {|
    #loc4 = loc("function_call.ml":3:19)
    ocaml.module @Function_call {
      ocaml.entry {
        %0 = ocaml.constant 1 : !ocaml.int loc(#loc1)
        %1 = ocaml.constant 2 : !ocaml.int loc(#loc2)
        %2 = ocaml.call "add"("camlFunction_call__add_5") (%0, %1) : (!ocaml.int, !ocaml.int) -> !ocaml.int loc(#loc3)
      } loc(#loc)
      ocaml.function @add("camlFunction_call__add_5") : (!ocaml.int, !ocaml.int) -> !ocaml.int {
      ^bb0(%arg0: !ocaml.int loc("function_call.ml":3:19), %arg1: !ocaml.int loc("function_call.ml":3:19)):
        %0 = ocaml.binop "+" %arg0, %arg1 : !ocaml.int, !ocaml.int -> !ocaml.int loc(#loc4)
        ocaml.return %0 : !ocaml.int loc(#loc4)
      } loc(#loc4)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("function_call.ml":4:19)
    #loc2 = loc("function_call.ml":4:21)
    #loc3 = loc("function_call.ml":4:15)
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'function_call.ml'
    source_filename = "function_call.ml"

    @camlFunction_call__gc_roots = global i64 0
    @camlFunction_call__data_begin = global i64 0
    @camlFunction_call__data_end = global i64 0
    @camlFunction_call__code_begin = global i64 0
    @camlFunction_call__code_end = global i64 0

    define i64 @camlFunction_call__entry() {
      %1 = call i64 @camlFunction_call__add_5(i64 3, i64 5)
      ret i64 1
    }

    define i64 @camlFunction_call__add_5(i64 %0, i64 %1) {
      %3 = add i64 %0, %1
      %4 = sub i64 %3, 1
      ret i64 %4
    }

    !llvm.module.flags = !{!0}
    !llvm.ident = !{!1}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    !1 = !{!"OCaml MLIR dialect unknown"}
    |}]

(* [let f = fun x -> ...] shares its typed tree with [let f x = ...], so it
   lowers to the same ocaml.function. *)
let%expect_test "anonymous function binding" =
  let t =
    test_compile ~name:"function_anon"
      ~code:
        "\n\
        \    external ( + ) : int -> int -> int = \"%addint\"\n\
        \    let increment = fun x -> x + 1\n\
        \  "
  in
  verify_mlir t;
  [%expect
    {|
    #loc1 = loc("function_anon.ml":3:30)
    ocaml.module @Function_anon {
      ocaml.entry {
      } loc(#loc)
      ocaml.function @increment("camlFunction_anon__increment_5") : (!ocaml.int) -> !ocaml.int {
      ^bb0(%arg0: !ocaml.int loc("function_anon.ml":3:30)):
        %0 = ocaml.constant 1 : !ocaml.int loc(#loc2)
        %1 = ocaml.binop "+" %arg0, %0 : !ocaml.int, !ocaml.int -> !ocaml.int loc(#loc1)
        ocaml.return %1 : !ocaml.int loc(#loc1)
      } loc(#loc1)
    } loc(#loc)
    #loc = loc(unknown)
    #loc2 = loc("function_anon.ml":3:34)
    |}]

(* One parameter, a negative literal argument, and a bool result: the tag
   arithmetic and the result type both differ from the two-int case above. *)
let%expect_test "function single param" =
  let t =
    test_compile ~name:"function_single"
      ~code:
        "\n\
        \    external ( < ) : int -> int -> bool = \"%lessthan\"\n\
        \    let is_neg x = x < 0\n\
        \    let res = is_neg (-5)\n\
        \  "
  in
  verify_mlir t;
  [%expect
    {|
    #loc3 = loc("function_single.ml":3:20)
    ocaml.module @Function_single {
      ocaml.entry {
        %0 = ocaml.constant -5 : !ocaml.int loc(#loc1)
        %1 = ocaml.call "is_neg"("camlFunction_single__is_neg_5") (%0) : (!ocaml.int) -> !ocaml.bool loc(#loc2)
      } loc(#loc)
      ocaml.function @is_neg("camlFunction_single__is_neg_5") : (!ocaml.int) -> !ocaml.bool {
      ^bb0(%arg0: !ocaml.int loc("function_single.ml":3:20)):
        %0 = ocaml.constant 0 : !ocaml.int loc(#loc4)
        %1 = ocaml.cmp "lt" %arg0, %0 : !ocaml.int -> !ocaml.bool loc(#loc3)
        ocaml.return %1 : !ocaml.bool loc(#loc3)
      } loc(#loc3)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("function_single.ml":4:22)
    #loc2 = loc("function_single.ml":4:15)
    #loc4 = loc("function_single.ml":3:24)
    |}];
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'function_single.ml'
    source_filename = "function_single.ml"

    @camlFunction_single__gc_roots = global i64 0
    @camlFunction_single__data_begin = global i64 0
    @camlFunction_single__data_end = global i64 0
    @camlFunction_single__code_begin = global i64 0
    @camlFunction_single__code_end = global i64 0

    define i64 @camlFunction_single__entry() {
      %1 = call i64 @camlFunction_single__is_neg_5(i64 -9)
      ret i64 1
    }

    define i64 @camlFunction_single__is_neg_5(i64 %0) {
      %2 = icmp slt i64 %0, 1
      %3 = select i1 %2, i64 3, i64 1
      ret i64 %3
    }

    !llvm.module.flags = !{!0}
    !llvm.ident = !{!1}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    !1 = !{!"OCaml MLIR dialect unknown"}
    |}]
