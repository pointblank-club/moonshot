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

let ocaml_value_type ctx =
  let namespace = StringRef.of_string "ocaml" in
  let data = StringRef.of_string "value" in
  { Type.raw =
      Omlir_bindings.BuiltinTypes.mlirOpaqueTypeGet ctx.MlirContext.raw
        namespace.raw data.raw
  }

let ocaml_ocamlint_type ctx =
  let namespace = StringRef.of_string "ocaml" in
  let data = StringRef.of_string "int" in
  { Type.raw =
      Omlir_bindings.BuiltinTypes.mlirOpaqueTypeGet ctx.MlirContext.raw
        namespace.raw data.raw
  }

let ocaml_i64_type ctx =
  { Type.raw =
      Omlir_bindings.BuiltinTypes.mlirIntegerTypeGet ctx.MlirContext.raw 64
  }

let create_string builder loc block value =
  let ctx = builder.Builders.OpBuilder.ctx in
  let state = Operation.State.get "ocaml.string" loc in
  Operation.State.add_attributes state [ named_string_attr ctx "value" value ];
  Operation.State.add_results state [ ocaml_string_type ctx ];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

let create_int builder loc block value =
  let ctx = builder.Builders.OpBuilder.ctx in
  let state = Operation.State.get "ocaml.int" loc in
  Operation.State.add_attributes state
    [ Attribute.get_named (Identifier.get ctx "value")
        (Attribute.get_integer64 (ocaml_i64_type ctx) (Int64.of_int value))
    ];
  Operation.State.add_results state [ ocaml_ocamlint_type ctx ];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

let create_binop builder loc block op_name lhs rhs =
  let ctx = builder.Builders.OpBuilder.ctx in
  let state = Operation.State.get "ocaml.binop" loc in
  Operation.State.add_attributes state
    [ named_string_attr ctx "op_name" op_name ];
  Operation.State.add_operands state [ lhs; rhs ];
  Operation.State.add_results state [ ocaml_ocamlint_type ctx ];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0


let map_ocaml_type_to_mlir ctx ty =
  match (Types.Transient_expr.repr ty).desc with
  | Types.Tconstr (path, _, _) when Path.same path Predef.path_int ->
      ocaml_ocamlint_type ctx
  | Types.Tconstr (path, _, _) when Path.same path Predef.path_string ->
      ocaml_string_type ctx
  | _ -> ocaml_value_type ctx

let rec decompose_function_type ty =
  match (Types.Transient_expr.repr ty).desc with
  | Types.Tarrow (_, arg, res, _) ->
      let args, ret = decompose_function_type res in
      arg :: args, ret
  | _ -> [], ty

let map_repr_and_type_to_mlir ctx (_mode, repr) ocaml_ty_opt =
  try
    match repr with
    | Primitive.Unboxed_or_untagged_integer _ -> ocaml_i64_type ctx
    | Primitive.Same_as_ocaml_repr sort ->
        if sort = Jkind_types.Sort.Const.untagged_immediate
        then ocaml_i64_type ctx
        else
          (match ocaml_ty_opt with
           | Some ty -> map_ocaml_type_to_mlir ctx ty
           | None -> ocaml_value_type ctx)
    | _ -> ocaml_value_type ctx
  with _ -> ocaml_value_type ctx

let map_repr_to_type ctx repr =
  map_repr_and_type_to_mlir ctx repr None

let primitive_function_type builder prim =
  let ctx = builder.Builders.OpBuilder.ctx in
  let args =
    List.map (map_repr_to_type ctx) prim.Primitive.prim_native_repr_args
  in
  let res_type = map_repr_to_type ctx prim.Primitive.prim_native_repr_res in
  Builders.OpBuilder.get_function_type builder args [res_type]

let create_extern builder loc block name prim func_type_opt =
  let ctx = builder.Builders.OpBuilder.ctx in
  let func_type =
    match func_type_opt with
    | Some t -> t
    | None -> primitive_function_type builder prim
  in
  let state = Operation.State.get "ocaml.extern" loc in
  Operation.State.add_attributes state
    [
      named_string_attr ctx "sym_name" name;
      named_type_attr ctx "function_type" func_type;
      named_string_attr ctx "target" (Primitive.native_name prim);
    ];
  append block (Operation.create state)

let create_extern_call builder loc module_block block created_externs name prim
    val_type args =
  let ctx = builder.Builders.OpBuilder.ctx in
  let _, ocaml_res = decompose_function_type val_type in
  let res_type =
    map_repr_and_type_to_mlir ctx prim.Primitive.prim_native_repr_res
      (Some ocaml_res)
  in
  let arg_types = List.map (fun v -> Value.get_type v) args in
  let func_type =
    Builders.OpBuilder.get_function_type builder arg_types [res_type]
  in

  (* Ensure module-level ocaml.extern with accurate function_type exists *)
  if not (StringSet.mem name !created_externs) then (
    create_extern builder loc module_block name prim (Some func_type);
    created_externs := StringSet.add name !created_externs
  );

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
  Operation.State.add_results state [res_type];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

let rec compile_expr env builder loc module_block block created_externs
    (expr : Typedtree.expression) =
  match expr.exp_desc with
  | Texp_ident { path; _ } ->
    let name = Path.name path in
    (try Some (List.assoc name env)
     with Not_found -> None)
  | Texp_constant (Const_int value) ->
    Some (create_int builder loc block value)
  | Texp_constant (Const_string (value, _, _)) ->
    Some (create_string builder loc block value)
  | Texp_apply
      ( { exp_desc =
            Texp_ident
              { lid = { txt = Longident.Lident name; _ };
                desc = { Types.val_kind = Types.Val_prim prim; val_type; _ };
                _
              };
          _ },
        args,
        _,
        _,
        _ ) ->
    let op_name_opt =
      match prim.Primitive.prim_name with
      | "%addint" -> Some "+"
      | "%subint" -> Some "-"
      | "%mulint" -> Some "*"
      | "%divint" -> Some "/"
      | _ -> None
    in
    (match op_name_opt, args with
     | Some op_name, [(_, Typedtree.Arg (lhs_expr, _)); (_, Typedtree.Arg (rhs_expr, _))] ->
       (match
          compile_expr env builder loc module_block block created_externs
            lhs_expr,
          compile_expr env builder loc module_block block created_externs
            rhs_expr
        with
        | Some lhs_val, Some rhs_val ->
          Some (create_binop builder loc block op_name lhs_val rhs_val)
        | _ -> None)
     | _ ->
       let args =
         List.filter_map
           (fun (_label, arg) ->
             match arg with
             | Typedtree.Arg (expr, _) ->
               compile_expr env builder loc module_block block
                 created_externs expr
             | Typedtree.Omitted _ -> None)
           args
       in
       Some
         (create_extern_call builder loc module_block block created_externs
            name prim val_type args))
  | Texp_let (_, bindings, body) ->
    let new_env =
      List.fold_left
        (fun acc (binding : Typedtree.value_binding) ->
          let res =
            compile_expr env builder loc module_block block created_externs
              binding.vb_expr
          in
          match res, binding.vb_pat.pat_desc with
          | Some val_obj, Tpat_var { id; _ } ->
            (Ident.name id, val_obj) :: acc
          | _ -> acc)
        env
        bindings
    in
    compile_expr new_env builder loc module_block block created_externs body
  | Texp_sequence (first, _, second) ->
    ignore
      (compile_expr env builder loc module_block block created_externs first
        : Value.t option);
    compile_expr env builder loc module_block block created_externs second
  | _ -> None

let compile_structure builder loc module_block entry_block created_externs
    (impl : Typedtree.implementation) =
  let global_env = ref [] in
  List.iter
    (fun (item : Typedtree.structure_item) ->
      match item.str_desc with
      | Tstr_eval (expr, _, _) ->
        ignore
          (compile_expr !global_env builder loc module_block entry_block
             created_externs expr : Value.t option)
      | Tstr_value (_, bindings) ->
        let new_bindings =
          List.filter_map
            (fun (binding : Typedtree.value_binding) ->
              match
                compile_expr !global_env builder loc module_block entry_block
                  created_externs binding.vb_expr
              with
              | Some val_obj ->
                (match binding.vb_pat.pat_desc with
                 | Tpat_var { id; _ } -> Some (Ident.name id, val_obj)
                 | _ -> None)
              | None -> None)
            bindings
        in
        global_env := new_bindings @ !global_env
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

  let created_externs = ref StringSet.empty in

  (* Create ocaml.entry operation *)
  let entry_state = Operation.State.get "ocaml.entry" loc in
  let entry_region = Operation.Region.create () in
  let entry_block = Operation.Block.create () in
  Operation.Region.append_owned_block entry_region entry_block;
  Operation.State.add_owned_regions entry_state [entry_region];
  let ocaml_entry = Operation.create entry_state in
  Operation.append_owned_operation block ocaml_entry;

  compile_structure builder loc block entry_block created_externs _impl;

  (* Pass the raw pointers to the C++ FFI *)
  let raw_op = Bindings.Ir.mlir_operation_ptr ocaml_mod.raw in

  Caml_bindings.lowering_init ~ctx_ptr:raw_ctx ~op_ptr:raw_op
    ~output_file:(output_prefix ^ ".o");

  Format.fprintf ppf_dump "Generated object file: %s.o\n%!" output_prefix
