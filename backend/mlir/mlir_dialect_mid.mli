(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

(* Mid-level OxCaml MLIR dialect.

   Representation choices (boxed/unboxed, tags, closure layout) have been
   committed.  The IR is still structured (functions, blocks, SSA values)
   but the operations are close to Cmm: machine-word arithmetic, memory
   loads/stores, direct/indirect calls, branches.  The only remaining
   lowering step to LLVM is register-sized type erasure. *)

val dialect_name : string

type machine_type
type value_
type op
type block
type func
type module_

val create_module : name:string -> module_

val module_name : module_ -> string

val pp_module : Format.formatter -> module_ -> unit
