open Omlir

module StringSet = Set.Make (String)

let append block op = Operation.append_owned_operation block op

let named_string_attr ctx name value =
  Attribute.get_named (Identifier.get ctx name) (Attribute.get_string ctx value)

let named_type_attr ctx name ty =
  Attribute.get_named (Identifier.get ctx name) (Attribute.get_type ty)

let ocaml_string_type ctx =
  let namespace = StringRef.of_string "ocaml" in
  let data = StringRef.of_string "string" in
  { Type.raw =
      Omlir_bindings.BuiltinTypes.mlirOpaqueTypeGet ctx.MlirContext.raw
        namespace.raw data.raw
  }

let unit_result_types = []

let primitive_function_type builder prim =
  let arg_type = ocaml_string_type builder.Builders.OpBuilder.ctx in
  let args =
    List.map (fun _ -> arg_type) prim.Primitive.prim_native_repr_args
  in
  Builders.OpBuilder.get_function_type builder args unit_result_types

let create_extern builder loc block name prim =
  let ctx = builder.Builders.OpBuilder.ctx in
  let func_type = primitive_function_type builder prim in
  let state = Operation.State.get "ocaml.extern" loc in
  Operation.State.add_attributes state
    [
      named_string_attr ctx "sym_name" name;
      named_type_attr ctx "function_type" func_type;
      named_string_attr ctx "target" (Primitive.native_name prim);
    ];
  append block (Operation.create state)

let create_string builder loc block value =
  let ctx = builder.Builders.OpBuilder.ctx in
  let state = Operation.State.get "ocaml.string" loc in
  Operation.State.add_attributes state [ named_string_attr ctx "value" value ];
  Operation.State.add_results state [ ocaml_string_type ctx ];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

let create_extern_call builder loc block name prim args =
  let ctx = builder.Builders.OpBuilder.ctx in
  let func_type = primitive_function_type builder prim in
  let state = Operation.State.get "ocaml.extern_call" loc in
  Operation.State.add_attributes state
    [
      Attribute.get_named (Identifier.get ctx "callee")
        (Omlir_bindings.BuiltinAttributes.mlirFlatSymbolRefAttrGet
           ctx.MlirContext.raw
           (StringRef.of_string name).raw
        |> fun raw -> { Attribute.raw = raw });
      named_type_attr ctx "callee_type" func_type;
    ];
  Operation.State.add_operands state args;
  append block (Operation.create state)

let rec primitive_calls_expr acc (expr : Typedtree.expression) =
  match expr.exp_desc with
  | Texp_apply
      ( { exp_desc =
            Texp_ident
              { lid = { txt = Longident.Lident name; _ };
                desc = { Types.val_kind = Types.Val_prim prim; _ };
                _
              };
          _ },
        args,
        _,
        _,
        _ ) ->
    List.fold_left
      (fun acc (_label, arg) ->
        match arg with
        | Typedtree.Arg (expr, _) -> primitive_calls_expr acc expr
        | Typedtree.Omitted _ -> acc)
      ((name, prim) :: acc)
      args
  | Texp_let (_, bindings, body) ->
    let acc =
      List.fold_left
        (fun acc (binding : Typedtree.value_binding) ->
          primitive_calls_expr acc binding.vb_expr)
        acc bindings
    in
    primitive_calls_expr acc body
  | Texp_sequence (first, _, second) ->
    primitive_calls_expr (primitive_calls_expr acc first) second
  | _ -> acc

let primitive_calls (impl : Typedtree.implementation) =
  List.fold_left
    (fun acc (item : Typedtree.structure_item) ->
      match item.str_desc with
      | Tstr_eval (expr, _, _) -> primitive_calls_expr acc expr
      | Tstr_value (_, bindings) ->
        List.fold_left
          (fun acc (binding : Typedtree.value_binding) ->
            primitive_calls_expr acc binding.vb_expr)
          acc bindings
      | _ -> acc)
    [] impl.structure.str_items
  |> List.rev

let rec compile_expr builder loc block (expr : Typedtree.expression) =
  match expr.exp_desc with
  | Texp_constant (Const_string (value, _, _)) ->
    Some (create_string builder loc block value)
  | Texp_apply
      ( { exp_desc =
            Texp_ident
              { lid = { txt = Longident.Lident name; _ };
                desc = { Types.val_kind = Types.Val_prim prim; _ };
                _
              };
          _ },
        args,
        _,
        _,
        _ ) ->
    let args =
      List.filter_map
        (fun (_label, arg) ->
          match arg with
          | Typedtree.Arg (expr, _) -> compile_expr builder loc block expr
          | Typedtree.Omitted _ -> None)
        args
    in
    create_extern_call builder loc block name prim args;
    None
  | Texp_let (_, bindings, body) ->
    List.iter
      (fun (binding : Typedtree.value_binding) ->
        ignore
          (compile_expr builder loc block binding.vb_expr : Value.t option))
      bindings;
    compile_expr builder loc block body
  | Texp_sequence (first, _, second) ->
    ignore (compile_expr builder loc block first : Value.t option);
    compile_expr builder loc block second
  | _ -> None

let compile_structure builder loc entry_block (impl : Typedtree.implementation)
    =
  List.iter
    (fun (item : Typedtree.structure_item) ->
      match item.str_desc with
      | Tstr_eval (expr, _, _) ->
        ignore (compile_expr builder loc entry_block expr : Value.t option)
      | Tstr_value (_, bindings) ->
        List.iter
          (fun (binding : Typedtree.value_binding) ->
            ignore
              (compile_expr builder loc entry_block binding.vb_expr
                : Value.t option))
          bindings
      | _ -> ())
    impl.structure.str_items

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

  let externs = primitive_calls _impl in
  let _, _ =
    List.fold_left
      (fun (seen, ()) (name, prim) ->
        if StringSet.mem name seen
        then seen, ()
        else (
          create_extern builder loc block name prim;
          StringSet.add name seen, ()))
      (StringSet.empty, ()) externs
  in

  (* Create ocaml.entry operation *)
  let entry_state = Operation.State.get "ocaml.entry" loc in
  let entry_region = Operation.Region.create () in
  let entry_block = Operation.Block.create () in
  Operation.Region.append_owned_block entry_region entry_block;
  Operation.State.add_owned_regions entry_state [entry_region];
  let ocaml_entry = Operation.create entry_state in
  Operation.append_owned_operation block ocaml_entry;

  compile_structure builder loc entry_block _impl;

  (* Pass the raw pointers to the C++ FFI *)
  let raw_op = Bindings.Ir.mlir_operation_ptr ocaml_mod.raw in

  Caml_bindings.lowering_init ~ctx_ptr:raw_ctx ~op_ptr:raw_op
    ~output_file:(output_prefix ^ ".o");

  Format.fprintf ppf_dump "Generated object file: %s.o\n%!" output_prefix
