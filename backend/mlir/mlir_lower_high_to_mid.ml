(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

let lower (high : Mlir_dialect_high.module_) =
  (* TODO: per-op rewrite from Mlir_dialect_high to Mlir_dialect_mid. *)
  Mlir_dialect_mid.create_module ~name:(Mlir_dialect_high.module_name high)
