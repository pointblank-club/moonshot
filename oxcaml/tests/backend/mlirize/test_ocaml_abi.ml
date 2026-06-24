open Helpers

(* A call to a compiled-OCaml symbol (ending in "_code") must use OCaml's native
   calling convention rather than the C ABI. LLVM has no such convention, so the
   call is lowered to inline assembly that pins each argument to the registers
   OCaml expects (rax, rbx, ...) and reads the result from rax. The argument
   stays tagged (85 = (42 << 1) | 1). *)
let%expect_test "ocaml convention call lowers to register-pinned inline asm" =
  let t =
    test_compile ~name:"ocaml_abi"
      ~code:
        "\n\
        \    external id : int -> unit = \"camlAbitest__id_code\"\n\
        \    let () = id 42\n\
        \  "
  in
  verify_llvm t;
  [%expect
    {|
    ; ModuleID = 'ocaml_abi.ml'
    source_filename = "ocaml_abi.ml"

    @camlOcaml_abi__gc_roots = global i64 0
    @camlOcaml_abi__data_begin = global i64 0
    @camlOcaml_abi__data_end = global i64 0
    @camlOcaml_abi__code_begin = global i64 0
    @camlOcaml_abi__code_end = global i64 0
    @camlOcaml_abi__frametable = global i64 0

    define i64 @camlOcaml_abi__entry() {
      %1 = call i64 asm sideeffect alignstack "call camlAbitest__id_code", "={ax},0,~{rbx},~{rdi},~{rsi},~{rdx},~{rcx},~{r8},~{r9},~{r12},~{r13},~{r10},~{r11},~{xmm0},~{xmm1},~{xmm2},~{xmm3},~{xmm4},~{xmm5},~{xmm6},~{xmm7},~{xmm8},~{xmm9},~{xmm10},~{xmm11},~{xmm12},~{xmm13},~{xmm14},~{xmm15},~{memory},~{cc}"(i64 85)
      ret i64 1
    }

    !llvm.module.flags = !{!0}

    !0 = !{i32 2, !"Debug Info Version", i32 3}
    |}]
