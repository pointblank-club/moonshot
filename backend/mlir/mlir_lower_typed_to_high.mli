(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

(* Lower an OCaml [Typedtree.implementation] into the high-level OxCaml
   MLIR dialect ([Mlir_dialect_high]).

   Currently a stub: it produces an empty high-level module bearing the
   compilation unit's name. *)

val lower
  :  module_name:string
  -> Typedtree.implementation
  -> Mlir_dialect_high.module_
