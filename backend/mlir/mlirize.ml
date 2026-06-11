(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

[@@@warning "-33"]

let init () = ()

let compile_from_typed = Mlir.compile_from_typed

let () =
  Compiler_hooks.register Mlirize
    (fun (module_name, output_prefix, impl, ppf_dump) ->
      compile_from_typed ~module_name ~output_prefix ~ppf_dump impl)
