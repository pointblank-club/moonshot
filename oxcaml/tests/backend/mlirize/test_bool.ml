open Helpers

let%expect_test "boolean constants" =
  let t = test_compile ~name:"bool_const" ~code:"let a = true\nlet b = false" in
  verify_mlir t;
  [%expect
    {|
    ocaml.module @Bool_const {
      ocaml.entry {
        %0 = ocaml.constant 1 : !ocaml.bool loc(#loc1)
        %1 = ocaml.constant 0 : !ocaml.bool loc(#loc2)
      } loc(#loc)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("bool_const.ml":1:9)
    #loc2 = loc("bool_const.ml":2:9)
    |}]
