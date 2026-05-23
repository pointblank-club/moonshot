external register_ocaml_dialect : nativeint -> unit =
  "caml_mlirContextRegisterOCamlDialect"

external lowering_init :
  ctx_ptr:nativeint -> op_ptr:nativeint -> output_file:string -> unit =
  "caml_OcamlLoweringInit"
