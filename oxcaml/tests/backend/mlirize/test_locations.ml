open Helpers

(* Each emitted op should carry the source file:line:col of the expression it
   came from, rather than loc(unknown). *)
let%expect_test "source locations" =
  let t =
    test_compile ~name:"locations"
      ~code:
        {|
    external ( + ) : int -> int -> int = "%addint"
    let a = 10
    let b = a + 20
    |}
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Locations {
      ocaml.entry {
        %0 = ocaml.constant 10 : !ocaml.int loc(#loc1)
        %1 = ocaml.constant 20 : !ocaml.int loc(#loc2)
        %2 = ocaml.binop "+" %0, %1 : !ocaml.int, !ocaml.int -> !ocaml.int loc(#loc3)
      } loc(#loc)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("locations.ml":3:13)
    #loc2 = loc("locations.ml":4:17)
    #loc3 = loc("locations.ml":4:13)
    |}]

(* Constants on different lines/columns get distinct locations. *)
let%expect_test "distinct locations" =
  let t =
    test_compile ~name:"multiloc"
      ~code:{|
    let x = 1
    let y = 22
    let z = "s"
    |}
  in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Multiloc {
      ocaml.entry {
        %0 = ocaml.constant 1 : !ocaml.int loc(#loc1)
        %1 = ocaml.constant 22 : !ocaml.int loc(#loc2)
        %2 = ocaml.constant "s" : !ocaml.string loc(#loc3)
      } loc(#loc)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("multiloc.ml":2:13)
    #loc2 = loc("multiloc.ml":3:13)
    #loc3 = loc("multiloc.ml":4:13)
    |}]

(* ocamlformat: disable test for unimplemented expresssions*)
let%expect_test "unsupported expression diagnostic" =
  let t =
    test_compile ~name:"unsupported"
      ~code:
        {|
    (* This is a long comment to force the formatter to keep the string multiline *)
    let x = (1, 2)
    |}
  in
  verify_build_stdout t;
  [%expect
    {|
    Compiler exited with status 2
    Compiling module Unsupported to MLIR
    File "unsupported.ml", line 3, characters 12-18:
    3 |     let x = (1, 2)
                    ^^^^^^
    Error: unsupported expression
    |}]
