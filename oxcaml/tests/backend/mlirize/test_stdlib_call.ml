open Helpers

let%expect_test "stdlib call" =
  let t =
    test_compile_stdlib ~name:"stdlib_call" ~code:"let () = print_newline ()"
  in
  Printf.printf "%s\n" t.mlir;
  [%expect
    {|
    ocaml.module @Stdlib_call {
      ocaml.entry {
        %0 = ocaml.constant unit : !ocaml.unit loc(#loc1)
        %1 = ocaml.call["Stdlib"] "print_newline"("camlStdlib__print_newline_139") (%0) : (!ocaml.unit) -> !ocaml.unit loc(#loc2)
      } loc(#loc)
    } loc(#loc)
    #loc = loc(unknown)
    #loc1 = loc("stdlib_call.ml":1:24)
    #loc2 = loc("stdlib_call.ml":1:10)
    |}]
