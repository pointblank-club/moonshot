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
  [%expect {| |}];
  verify_std_mlir t;
  [%expect {| |}];
  verify_llvm t;
  [%expect {| |}]
