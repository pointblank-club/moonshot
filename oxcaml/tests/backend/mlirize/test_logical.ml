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
  [%expect {| |}];
  verify_std_mlir t;
  [%expect {| |}];
  verify_llvm t;
  [%expect {| |}]
