(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

(* Entry point for the experimental MLIR backend.

   Pipeline:
     Typedtree.implementation
         -> Mlir_dialect_high        (Mlir_lower_typed_to_high)
         -> Mlir_dialect_mid         (Mlir_lower_high_to_mid)
         -> Mlir_dialect_llvm        (Mlir_lower_mid_to_llvm)
         -> textual LLVM IR          (handed to the LLVM toolchain)

   This is currently a scaffold: each pass is a stub that threads the
   module through without rewriting ops.  The driver short-circuits after
   this function runs, so a compile with [-mlir-backend] exits 0 without
   producing .cmx/.o files. *)

val compile_from_typed
  :  module_name:string
  -> ppf_dump:Format.formatter
  -> Typedtree.implementation
  -> unit
