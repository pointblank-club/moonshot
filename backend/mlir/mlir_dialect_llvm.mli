(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

(* Wrapper for the standard MLIR [llvm] dialect.  We do not redefine it
   here; we just model enough of it to emit textual LLVM IR once the
   OxCaml-specific passes have run. *)

val dialect_name : string

type module_

val create_module : name:string -> module_

val pp_module : Format.formatter -> module_ -> unit

(* Render the module as textual LLVM IR. *)
val to_llvm_ir_text : module_ -> string
