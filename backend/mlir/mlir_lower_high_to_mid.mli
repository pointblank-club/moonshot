(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

(* Lower the high-level OxCaml MLIR dialect to the mid-level dialect.
   This pass commits representation choices (boxing, tag bits, closure
   layout) and rewrites structured control flow into basic blocks. *)

val lower
  :  Mlir_dialect_high.module_
  -> Mlir_dialect_mid.module_
