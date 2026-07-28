module Ocaml_location = Location
open Omlir
module StringSet = Set.Make (String)

let append block op = Operation.append_owned_operation block op

let named_string_attr ctx name value =
  Attribute.get_named (Identifier.get ctx name) (Attribute.get_string ctx value)

let named_type_attr ctx name ty =
  Attribute.get_named (Identifier.get ctx name) (Attribute.get_type ty)

let ocaml_string_type ctx =
  let str = StringRef.of_string "!ocaml.string" in
  { Type.raw = Omlir_bindings.Ir.mlirTypeParseGet ctx.MlirContext.raw str.raw }

let ocaml_int_type ctx =
  let str = StringRef.of_string "!ocaml.int" in
  { Type.raw = Omlir_bindings.Ir.mlirTypeParseGet ctx.MlirContext.raw str.raw }

let ocaml_float_type ctx =
  let str = StringRef.of_string "!ocaml.float" in
  { Type.raw = Omlir_bindings.Ir.mlirTypeParseGet ctx.MlirContext.raw str.raw }

let ocaml_bool_type ctx =
  let str = StringRef.of_string "!ocaml.bool" in
  { Type.raw = Omlir_bindings.Ir.mlirTypeParseGet ctx.MlirContext.raw str.raw }

let ocaml_unit_type ctx =
  let str = StringRef.of_string "!ocaml.unit" in
  { Type.raw = Omlir_bindings.Ir.mlirTypeParseGet ctx.MlirContext.raw str.raw }

let ocaml_i64_type ctx =
  { Type.raw =
      Omlir_bindings.BuiltinTypes.mlirIntegerTypeGet ctx.MlirContext.raw 64
  }

let file_line_col_loc builder (pos : Lexing.position) =
  let ctx = builder.Builders.OpBuilder.ctx in
  if pos.Lexing.pos_fname = ""
  then Builders.OpBuilder.get_unknown_loc builder
  else
    let filename = StringRef.of_string pos.Lexing.pos_fname in
    let line = pos.Lexing.pos_lnum in
    let col = pos.Lexing.pos_cnum - pos.Lexing.pos_bol + 1 in
    { Location.raw =
        Omlir_bindings.Ir.mlirLocationFileLineColGet ctx.MlirContext.raw
          filename.raw line col;
      Location.ctx
    }

let create_string builder loc block value =
  let ctx = builder.Builders.OpBuilder.ctx in
  let state = Operation.State.get "ocaml.constant" loc in
  Operation.State.add_attributes state [named_string_attr ctx "value" value];
  Operation.State.add_results state [ocaml_string_type ctx];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

let create_int builder loc block value =
  let ctx = builder.Builders.OpBuilder.ctx in
  let state = Operation.State.get "ocaml.constant" loc in
  Operation.State.add_attributes state
    [ Attribute.get_named
        (Identifier.get ctx "value")
        (Attribute.get_integer64 (ocaml_i64_type ctx) (Int64.of_int value)) ];
  Operation.State.add_results state [ocaml_int_type ctx];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

let create_float builder loc block value =
  let ctx = builder.Builders.OpBuilder.ctx in
  let state = Operation.State.get "ocaml.constant" loc in
  Operation.State.add_attributes state
    [ Attribute.get_named
        (Identifier.get ctx "value")
        (Attribute.get_float ctx ~ty:(Type.f64 ctx) ~value) ];
  Operation.State.add_results state [ocaml_float_type ctx];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

let create_unit builder loc block =
  let ctx = builder.Builders.OpBuilder.ctx in
  let state = Operation.State.get "ocaml.constant" loc in
  let unit_attr =
    Omlir_bindings.BuiltinAttributes.mlirUnitAttrGet ctx.MlirContext.raw
  in
  Operation.State.add_attributes state
    [ Attribute.get_named
        (Identifier.get ctx "value")
        { Attribute.raw = unit_attr } ];
  Operation.State.add_results state [ocaml_unit_type ctx];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

let create_binop builder loc block op_name lhs rhs =
  let ctx = builder.Builders.OpBuilder.ctx in
  let state = Operation.State.get "ocaml.binop" loc in
  Operation.State.add_attributes state [named_string_attr ctx "op_name" op_name];
  Operation.State.add_operands state [lhs; rhs];
  Operation.State.add_results state [ocaml_int_type ctx];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

let create_float_binop builder loc block op_name lhs rhs =
  let ctx = builder.Builders.OpBuilder.ctx in
  let state = Operation.State.get "ocaml.binop" loc in
  Operation.State.add_attributes state [named_string_attr ctx "op_name" op_name];
  Operation.State.add_operands state [lhs; rhs];
  Operation.State.add_results state [ocaml_float_type ctx];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

let map_ocaml_type_to_mlir ctx ty =
  match (Types.Transient_expr.repr ty).desc with
  | Types.Tconstr (path, _, _) when Path.same path Predef.path_int ->
    ocaml_int_type ctx
  | Types.Tconstr (path, _, _) when Path.same path Predef.path_string ->
    ocaml_string_type ctx
  | Types.Tconstr (path, _, _) when Path.same path Predef.path_float ->
    ocaml_float_type ctx
  | Types.Tconstr (path, _, _) when Path.same path Predef.path_bool ->
    ocaml_bool_type ctx
  | Types.Tconstr (path, _, _) when Path.same path Predef.path_unit ->
    ocaml_unit_type ctx
  | _ ->
    failwith
      (Format.asprintf "Unimplemented type: %a" Printtyp.Compat.type_expr ty)

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
    | Primitive.Same_as_ocaml_repr sort -> (
      if sort = Jkind_types.Sort.Const.untagged_immediate
      then ocaml_i64_type ctx
      else
        match ocaml_ty_opt with
        | Some ty -> map_ocaml_type_to_mlir ctx ty
        | None -> failwith "Unimplemented type representation")
    | _ -> failwith "Unimplemented representation"
  with
  | Failure _ as exn -> raise exn
  | _ -> failwith "Failed to map type representation"

let map_repr_to_type ctx repr = map_repr_and_type_to_mlir ctx repr None

(* Compare two tagged ints. Comparing the tagged words directly works since (n
   << 1) | 1 keeps order and equality. *)
let create_cmp builder loc block predicate lhs rhs =
  let ctx = builder.Builders.OpBuilder.ctx in
  let state = Operation.State.get "ocaml.cmp" loc in
  Operation.State.add_attributes state
    [named_string_attr ctx "predicate" predicate];
  Operation.State.add_operands state [lhs; rhs];
  Operation.State.add_results state [ocaml_bool_type ctx];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

(* Compare two boxed floats, yielding an OCaml bool. *)
let create_float_cmp builder loc block predicate lhs rhs =
  let ctx = builder.Builders.OpBuilder.ctx in
  let state = Operation.State.get "ocaml.cmp" loc in
  Operation.State.add_attributes state
    [named_string_attr ctx "predicate" predicate];
  Operation.State.add_operands state [lhs; rhs];
  Operation.State.add_results state [ocaml_bool_type ctx];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

(* ocaml.and / ocaml.or on two bools *)
let create_logical builder loc block op_name lhs rhs =
  let ctx = builder.Builders.OpBuilder.ctx in
  let state = Operation.State.get op_name loc in
  Operation.State.add_operands state [lhs; rhs];
  Operation.State.add_results state [ocaml_bool_type ctx];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

(* ocaml.not on a bool *)
let create_not builder loc block value =
  let ctx = builder.Builders.OpBuilder.ctx in
  let state = Operation.State.get "ocaml.not" loc in
  Operation.State.add_operands state [value];
  Operation.State.add_results state [ocaml_bool_type ctx];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

let primitive_function_type builder prim =
  let ctx = builder.Builders.OpBuilder.ctx in
  let args =
    List.map (map_repr_to_type ctx) prim.Primitive.prim_native_repr_args
  in
  let res_type = map_repr_to_type ctx prim.Primitive.prim_native_repr_res in
  Builders.OpBuilder.get_function_type builder args [res_type]

let create_extern ?target builder loc block name prim func_type_opt =
  let ctx = builder.Builders.OpBuilder.ctx in
  let func_type =
    match func_type_opt with
    | Some t -> t
    | None -> primitive_function_type builder prim
  in
  let target =
    match target with Some t -> t | None -> Primitive.native_name prim
  in
  let state = Operation.State.get "ocaml.extern" loc in
  Operation.State.add_attributes state
    [ named_string_attr ctx "sym_name" name;
      named_type_attr ctx "function_type" func_type;
      named_string_attr ctx "target" target ];
  append block (Operation.create state)

(* target overrides the C symbol; val_type is the OCaml type the result is
   derived from. *)
let create_extern_call ?target builder loc module_block block created_externs
    name prim val_type args =
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
  if not (StringSet.mem name !created_externs)
  then (
    create_extern ?target builder loc module_block name prim (Some func_type);
    created_externs := StringSet.add name !created_externs);
  let state = Operation.State.get "ocaml.extern_call" loc in
  Operation.State.add_attributes state
    [ Attribute.get_named
        (Identifier.get ctx "callee")
        ( Omlir_bindings.BuiltinAttributes.mlirFlatSymbolRefAttrGet
            ctx.MlirContext.raw (StringRef.of_string name).raw
        |> fun raw -> { Attribute.raw } ) ];
  Operation.State.add_operands state args;
  Operation.State.add_results state [res_type];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

let is_constr_type path ty =
  match Types.get_desc ty with
  | Types.Tconstr (p, [], _) -> Path.same p path
  | _ -> false

let is_int_type = is_constr_type Predef.path_int

let is_float_type = is_constr_type Predef.path_float

let find_linkage_name cu field_name =
  let cu_prefix =
    Symbol.for_compilation_unit cu
    |> Symbol.linkage_name |> Linkage_name.to_string
  in
  let target_prefix = cu_prefix ^ "__" ^ field_name in
  match Compilenv.get_unit_export_info cu with
  | None -> target_prefix
  | Some cmx -> (
    let typing_env, _ =
      Flambda2_cmx.Flambda_cmx_format.import_typing_env_and_code cmx
    in
    let names = Flambda2_types.Typing_env.Serializable.name_domain typing_env in
    let found = ref None in
    Flambda2_identifiers.Name.Set.iter
      (fun name ->
        Flambda2_identifiers.Name.pattern_match name
          ~var:(fun _var -> ())
          ~symbol:(fun sym ->
            let linkage_str =
              Flambda2_identifiers.Symbol.linkage_name_as_string sym
            in
            if
              linkage_str = target_prefix
              || String.length linkage_str > String.length target_prefix
                 && String.sub linkage_str 0 (String.length target_prefix + 1)
                    = target_prefix ^ "_"
            then found := Some linkage_str))
      names;
    match !found with Some name -> name | None -> target_prefix)

let create_call builder loc block module_name_opt function_name mangled_name
    args res_type =
  let ctx = builder.Builders.OpBuilder.ctx in
  let state = Operation.State.get "ocaml.call" loc in
  let attrs =
    [ named_string_attr ctx "function_name" function_name;
      named_string_attr ctx "mangled_name" mangled_name ]
  in
  let attrs =
    match module_name_opt with
    | Some mod_name -> named_string_attr ctx "module_name" mod_name :: attrs
    | None -> attrs
  in
  Operation.State.add_attributes state attrs;
  Operation.State.add_operands state args;
  Operation.State.add_results state [res_type];
  let op = Operation.create state in
  append block op;
  Operation.get_result op 0

let rec compile_expr env builder module_block block created_externs
    (expr : Typedtree.expression) =
  let loc = file_line_col_loc builder expr.exp_loc.loc_start in
  match expr.exp_desc with
  | Texp_ident { path; _ } -> (
    let name = Path.name path in
    try Some (List.assoc name env) with Not_found -> None)
  | Texp_constant (Const_int value) -> Some (create_int builder loc block value)
  | Texp_constant (Const_string (value, _, _)) ->
    Some (create_string builder loc block value)
  | Texp_constant (Const_float value) ->
    Some (create_float builder loc block (float_of_string value))
  | Texp_construct (_, { cstr_name = "()"; _ }, _, _) ->
    Some (create_unit builder loc block)
  | Texp_apply
      ( { exp_desc =
            Texp_ident
              { lid = { txt = Longident.Lident name; _ };
                desc = { Types.val_kind = Types.Val_prim prim; val_type; _ };
                _
              };
          _
        },
        args,
        _,
        _,
        _ ) -> (
    let arg_exprs =
      List.filter_map
        (fun (_label, arg) ->
          match arg with
          | Typedtree.Arg (expr, _) -> Some expr
          | Typedtree.Omitted _ -> None)
        args
    in
    let args =
      List.map
        (compile_expr env builder module_block block created_externs)
        arg_exprs
      |> List.filter_map Fun.id
    in
    let fallback () =
      Some
        (create_extern_call builder loc module_block block created_externs name
           prim val_type args)
    in
    let all_operands pred =
      List.for_all (fun e -> pred e.Typedtree.exp_type) arg_exprs
    in
    let binop op_name =
      match args with
      | [lhs; rhs] -> Some (create_binop builder loc block op_name lhs rhs)
      | _ -> fallback ()
    in
    (* int and float compares lower natively; anything else (strings, ...) goes
       through the runtime compare (caml_lessthan, ...). *)
    let cmp ?runtime_sym predicate =
      match args with
      | [lhs; rhs] when all_operands is_int_type ->
        Some (create_cmp builder loc block predicate lhs rhs)
      | [lhs; rhs] when all_operands is_float_type ->
        Some (create_float_cmp builder loc block predicate lhs rhs)
      | [lhs; rhs] -> (
        match runtime_sym with
        | Some sym ->
          Some
            (create_extern_call ~target:sym builder loc module_block block
               created_externs sym prim val_type [lhs; rhs])
        | None -> fallback ())
      | _ -> fallback ()
    in
    let logical op_name =
      match args with
      | [lhs; rhs] -> Some (create_logical builder loc block op_name lhs rhs)
      | _ -> fallback ()
    in
    let float_binop op_name =
      match args with
      | [lhs; rhs] ->
        Some (create_float_binop builder loc block op_name lhs rhs)
      | _ -> fallback ()
    in
    match prim.Primitive.prim_name with
    | "%addint" -> binop "+"
    | "%subint" -> binop "-"
    | "%mulint" -> binop "*"
    | "%divint" -> binop "/"
    | "%andint" -> binop "land"
    | "%orint" -> binop "lor"
    | "%xorint" -> binop "lxor"
    | "%lslint" -> binop "lsl"
    | "%lsrint" -> binop "lsr"
    | "%asrint" -> binop "asr"
    | "%addfloat" -> float_binop "+"
    | "%subfloat" -> float_binop "-"
    | "%mulfloat" -> float_binop "*"
    | "%divfloat" -> float_binop "/"
    | "%lessthan" -> cmp ~runtime_sym:"caml_lessthan" "lt"
    | "%greaterthan" -> cmp ~runtime_sym:"caml_greaterthan" "gt"
    | "%lessequal" -> cmp ~runtime_sym:"caml_lessequal" "le"
    | "%greaterequal" -> cmp ~runtime_sym:"caml_greaterequal" "ge"
    | "%equal" -> cmp ~runtime_sym:"caml_equal" "eq"
    | "%notequal" -> cmp ~runtime_sym:"caml_notequal" "ne"
    (* physical ==, != : ints only *)
    | "%eq" -> cmp "eq"
    | "%noteq" -> cmp "ne"
    | "%sequand" -> logical "ocaml.and"
    | "%sequor" -> logical "ocaml.or"
    | "%boolnot" -> (
      match args with
      | [value] -> Some (create_not builder loc block value)
      | _ -> fallback ())
    | _ -> fallback ())
  | Texp_let (_, bindings, body) ->
    let new_env =
      List.fold_left
        (fun acc (binding : Typedtree.value_binding) ->
          let res =
            compile_expr env builder module_block block created_externs
              binding.vb_expr
          in
          match res, binding.vb_pat.pat_desc with
          | Some val_obj, Tpat_var { id; _ } -> (Ident.name id, val_obj) :: acc
          | _ -> acc)
        env bindings
    in
    compile_expr new_env builder module_block block created_externs body
  | Texp_sequence (first, _, second) ->
    ignore
      (compile_expr env builder module_block block created_externs first
        : Value.t option);
    compile_expr env builder module_block block created_externs second
  | Texp_apply (func, args, _, _, _) -> (
    let arg_values =
      List.filter_map
        (fun (_label, arg) ->
          match arg with
          | Typedtree.Arg (expr, _) ->
            compile_expr env builder module_block block created_externs expr
          | Typedtree.Omitted _ -> None)
        args
    in
    match func.exp_desc with
    | Texp_ident { path; _ } -> (
      let address_opt =
        try Some (Env.find_value_address path expr.exp_env) with _ -> None
      in
      match address_opt with
      | Some address -> (
        let resolved =
          try
            match address with
            | Env.Alocal id ->
              let sym = Symbol.for_local_ident id in
              let mangled = Symbol.linkage_name sym |> Linkage_name.to_string in
              Some (None, Ident.name id, mangled)
            | Env.Adot (Env.Aunit cu, _, _pos) ->
              let field_name = Path.last path in
              let mangled = find_linkage_name cu field_name in
              let mod_name = Compilation_unit.name_as_string cu in
              Some (Some mod_name, field_name, mangled)
            | Env.Aunit cu ->
              let sym = Symbol.for_compilation_unit cu in
              let mangled = Symbol.linkage_name sym |> Linkage_name.to_string in
              let mod_name = Compilation_unit.name_as_string cu in
              Some (Some mod_name, Path.last path, mangled)
            | _ -> None
          with _ -> None
        in
        match resolved with
        | Some (module_name_opt, function_name, mangled_name) ->
          let res_type =
            map_ocaml_type_to_mlir builder.Builders.OpBuilder.ctx expr.exp_type
          in
          Some
            (create_call builder loc block module_name_opt function_name
               mangled_name arg_values res_type)
        | None -> None)
      | None -> None)
    | _ -> None)
  | _ -> Ocaml_location.raise_errorf ~loc:expr.exp_loc "unsupported expression"

let compile_structure builder module_block entry_block created_externs
    (impl : Typedtree.implementation) =
  let global_env = ref [] in
  List.iter
    (fun (item : Typedtree.structure_item) ->
      match item.str_desc with
      | Tstr_eval (expr, _, _) ->
        ignore
          (compile_expr !global_env builder module_block entry_block
             created_externs expr
            : Value.t option)
      | Tstr_value (_, bindings) ->
        let new_bindings =
          List.filter_map
            (fun (binding : Typedtree.value_binding) ->
              match
                compile_expr !global_env builder module_block entry_block
                  created_externs binding.vb_expr
              with
              | Some val_obj -> (
                match binding.vb_pat.pat_desc with
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
    Attribute.get_named
      (Identifier.get ctx "sym_name")
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
  compile_structure builder block entry_block created_externs _impl;
  (* Pass the raw pointers to the C++ FFI *)
  let raw_op = Bindings.Ir.mlir_operation_ptr ocaml_mod.raw in
  Caml_bindings.lowering_init ~ctx_ptr:raw_ctx ~op_ptr:raw_op
    ~output_file:(output_prefix ^ ".o");
  Format.fprintf ppf_dump "Generated object file: %s.o\n%!" output_prefix
