open Helpers

let%expect_test "int comparison" =
  let t =
    test_compile ~name:"compare"
      ~code:
        "\n\
        \    external ( < ) : int -> int -> bool = \"%lessthan\"\n\
        \    external ( > ) : int -> int -> bool = \"%greaterthan\"\n\
        \    external ( = ) : int -> int -> bool = \"%equal\"\n\
        \    external ( <> ) : int -> int -> bool = \"%notequal\"\n\
        \    let lt = 2 < 9\n\
        \    let gt = 7 > 3\n\
        \    let eq = 4 = 4\n\
        \    let ne = 4 <> 9\n\
        \  "
  in
  verify_mlir t;
  [%expect {| |}];
  verify_std_mlir t;
  [%expect {| |}];
  verify_llvm t;
  [%expect {| |}]
