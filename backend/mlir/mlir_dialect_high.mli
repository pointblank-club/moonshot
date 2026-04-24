(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

(* High-level OxCaml MLIR dialect.

   This dialect sits directly below Typedtree.  Its operations preserve
   OCaml-level structure: modules, functions, let-bindings, applications
   and pattern-constructed values, with types that still mention OCaml
   boxedness (so that later passes can decide boxing/representation). *)

val dialect_name : string

type type_
type value_
type op
type block
type func
type module_

val create_module : name:string -> module_

val module_name : module_ -> string

val pp_module : Format.formatter -> module_ -> unit
