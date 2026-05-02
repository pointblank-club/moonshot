val translate_and_emit :
  module_name:string ->
  output_prefix:string ->
  mlir_mod:Ir.BuiltinOps.ModuleOp.t ->
  ppf_dump:Format.formatter ->
  unit
