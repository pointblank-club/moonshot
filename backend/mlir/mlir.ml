open Omlir

let compile_from_typed ~module_name ~output_prefix ~ppf_dump _impl =
  Format.fprintf ppf_dump "Compiling module %s to MLIR\n%!" module_name;

  let ctx = MlirContext.create () in
  let raw_ctx = Bindings.Ir.mlir_context_ptr ctx.raw in

  (* Register custom ocaml dialect on the context *)
  Caml_bindings.register_ocaml_dialect raw_ctx;

  (* Register all dialects *)
  let registry = Bindings.Ir.mlirDialectRegistryCreate () in
  Bindings.RegisterEverything.mlirRegisterAllDialects registry;
  Bindings.Ir.mlirContextAppendDialectRegistry ctx.raw registry;
  Bindings.Ir.mlirContextLoadAllAvailableDialects ctx.raw;
  Bindings.RegisterEverything.mlirRegisterAllLLVMTranslations ctx.raw;
  Bindings.Ir.mlirDialectRegistryDestroy registry;

  let builder = Builders.OpBuilder.create ctx in
  let loc = Builders.OpBuilder.get_unknown_loc builder in

  (* Create ocaml.module operation as the top-level operation. *)
  let state = Operation.State.get "ocaml.module" loc in
  let sym_name_attr =
    Attribute.get_named (Identifier.get ctx "sym_name")
      (Attribute.get_string ctx module_name)
  in
  Operation.State.add_attributes state [sym_name_attr];

  let region = Operation.Region.create () in
  let block = Operation.Block.create () in
  Operation.Region.append_owned_block region block;
  Operation.State.add_owned_regions state [region];

  let ocaml_mod = Operation.create state in

  (* Create ocaml.entry operation *)
  let entry_state = Operation.State.get "ocaml.entry" loc in
  let entry_region = Operation.Region.create () in
  let entry_block = Operation.Block.create () in
  Operation.Region.append_owned_block entry_region entry_block;
  Operation.State.add_owned_regions entry_state [entry_region];
  let ocaml_entry = Operation.create entry_state in
  Operation.append_owned_operation block ocaml_entry;

  (* Pass the raw pointers to the C++ FFI *)
  let raw_op = Bindings.Ir.mlir_operation_ptr ocaml_mod.raw in

  Caml_bindings.lowering_init ~ctx_ptr:raw_ctx ~op_ptr:raw_op
    ~output_file:(output_prefix ^ ".o");

  Format.fprintf ppf_dump "Generated object file: %s.o\n%!" output_prefix
