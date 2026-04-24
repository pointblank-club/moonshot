(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

let lower (mid : Mlir_dialect_mid.module_) =
  (* TODO: per-op rewrite from Mlir_dialect_mid to the llvm dialect. *)
  Mlir_dialect_llvm.create_module ~name:(Mlir_dialect_mid.module_name mid)
