(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

[@@@warning "-33"]
open Omlir

let compile_from_typed ~module_name ~ppf_dump _impl =
    Format.fprintf ppf_dump "Compiling module %s to MLIR\n%!" module_name;


  let ctx = MlirContext.create () in

  let builder = Builders.OpBuilder.create ctx in
  let loc = Builders.OpBuilder.get_unknown_loc builder in
  let modu = BuiltinOps.ModuleOp.create_empty loc in

   BuiltinOps.ModuleOp.dump modu;
  ()

let init () = ()

let () =
  Compiler_hooks.register Mlirize
    (fun (module_name, impl, ppf_dump) ->
       compile_from_typed ~module_name ~ppf_dump impl)
