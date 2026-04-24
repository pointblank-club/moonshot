(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

let lower ~module_name (_impl : Typedtree.implementation) =
  (* TODO: walk [_impl.structure] and emit high-level dialect ops. *)
  Mlir_dialect_high.create_module ~name:module_name
