(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

(* Lower the mid-level OxCaml MLIR dialect to the MLIR [llvm] dialect.
   This is the final OxCaml-specific pass before handing off to the LLVM
   toolchain. *)

val lower
  :  Mlir_dialect_mid.module_
  -> Mlir_dialect_llvm.module_
