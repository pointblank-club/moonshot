(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

(** Initialize the MLIR backend *)
val init : unit -> unit

(** Main entry point for the MLIR backend. *)
val compile_from_typed :
  module_name:string ->
  output_prefix:string ->
  ppf_dump:Format.formatter ->
  Typedtree.implementation ->
  unit
