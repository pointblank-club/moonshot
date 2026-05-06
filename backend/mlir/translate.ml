(* Typedtree -> textual MLIR with the [ocaml] dialect.
   See backend/mlir/Contributors.md for the design. *)

open Typedtree

let cmpi_pred_of_prim = function
  | "%equal" -> Some "eq"
  | "%notequal" -> Some "ne"
  | "%lessthan" -> Some "slt"
  | "%lessequal" -> Some "sle"
  | "%greaterthan" -> Some "sgt"
  | "%greaterequal" -> Some "sge"
  | "%eq" -> Some "eq"
  | "%noteq" -> Some "ne"
  | _ -> None

let arith_op_of_prim = function
  | "%addint" -> Some "ocaml.addi"
  | "%subint" -> Some "ocaml.subi"
  | "%mulint" -> Some "ocaml.muli"
  | "%divint" -> Some "ocaml.divi"
  | "%modint" -> Some "ocaml.modi"
  | "%addfloat" -> Some "ocaml.addf"
  | "%subfloat" -> Some "ocaml.subf"
  | "%mulfloat" -> Some "ocaml.mulf"
  | "%divfloat" -> Some "ocaml.divf"
  | _ -> None

let is_float_op op =
  op = "ocaml.addf" || op = "ocaml.subf"
  || op = "ocaml.mulf" || op = "ocaml.divf"

(* Polymorphic compare primitives (`%lessthan` etc.) need a per-call
   dispatch because the primitive name itself doesn't distinguish int
   from float operands.  Map a cmpi predicate to its ordered float
   counterpart for use when the first operand is a float. *)
let cmpf_pred_of_cmpi = function
  | "eq" -> "oeq"
  | "ne" -> "one"
  | "slt" -> "olt"
  | "sle" -> "ole"
  | "sgt" -> "ogt"
  | "sge" -> "oge"
  | other -> other

let is_float_type ty =
  match Types.get_desc ty with
  | Tconstr (path, _, _) -> Path.same path Predef.path_float
  | _ -> false

type env = {
  mutable next_id : int;
  vars : (Ident.t, string) Hashtbl.t;
  externals : (string, int) Hashtbl.t;
  buf : Buffer.t;
}

let is_builtin_prim name =
  String.length name > 0 && name.[0] = '%'

let fresh env =
  let n = env.next_id in
  env.next_id <- n + 1;
  Printf.sprintf "%%v%d" n

let unit_value env =
  let v = fresh env in
  Printf.bprintf env.buf "    %s = ocaml.constant 0\n" v;
  v

let rec translate_expr env (expr : expression) : string =
  match expr.exp_desc with
  | Texp_constant (Const_int n) ->
    let v = fresh env in
    Printf.bprintf env.buf "    %s = ocaml.constant %d\n" v n;
    v
  | Texp_constant (Const_float s) ->
    let v = fresh env in
    Printf.bprintf env.buf "    %s = arith.constant %s : f64\n" v s;
    v
  | Texp_ident { path = Path.Pident id; _ } when Hashtbl.mem env.vars id ->
    Hashtbl.find env.vars id
  | Texp_apply
      ( { exp_desc =
            Texp_ident { desc = { val_kind = Types.Val_prim p; _ }; _ };
          _
        },
        args, _, _, _ ) -> begin
    match
      cmpi_pred_of_prim p.prim_name,
      arith_op_of_prim p.prim_name,
      args
    with
    | Some pred, _, [(_, Arg (lhs, _)); (_, Arg (rhs, _))] ->
      let l = translate_expr env lhs in
      let r = translate_expr env rhs in
      let v = fresh env in
      if is_float_type lhs.exp_type then
        Printf.bprintf env.buf "    %s = ocaml.cmpf %s, %s, %s : f64\n"
          v (cmpf_pred_of_cmpi pred) l r
      else
        Printf.bprintf env.buf "    %s = ocaml.cmpi %s, %s, %s : i64\n"
          v pred l r;
      v
    | _, Some op, [(_, Arg (lhs, _)); (_, Arg (rhs, _))] ->
      let l = translate_expr env lhs in
      let r = translate_expr env rhs in
      let v = fresh env in
      let ty = if is_float_op op then "f64" else "i64" in
      Printf.bprintf env.buf "    %s = %s %s, %s : %s\n" v op l r ty;
      v
    | None, None, _ when not (is_builtin_prim p.prim_name) ->
      let arg_vs =
        List.filter_map
          (fun (_, arg) ->
             match arg with
             | Arg (e, _) -> Some (translate_expr env e)
             | _ -> None)
          args
      in
      let arity = List.length arg_vs in
      Hashtbl.replace env.externals p.prim_name arity;
      let v = fresh env in
      let arg_str = String.concat ", " arg_vs in
      let arg_tys = String.concat ", " (List.init arity (fun _ -> "i64")) in
      Printf.bprintf env.buf
        "    %s = func.call @%s(%s) : (%s) -> i64\n"
        v p.prim_name arg_str arg_tys;
      v
    | _ ->
      Printf.bprintf env.buf "    // unsupported primitive: %s\n"
        p.prim_name;
      unit_value env
    end
  | Texp_let (_, [vb], body) ->
    let v = translate_expr env vb.vb_expr in
    (match vb.vb_pat.pat_desc with
     | Tpat_var { id; _ } -> Hashtbl.add env.vars id v
     | _ -> ());
    translate_expr env body
  | _ ->
    Buffer.add_string env.buf "    // unsupported expression\n";
    unit_value env

let translate_str_item env (item : structure_item) =
  match item.str_desc with
  | Tstr_eval (e, _, _) -> ignore (translate_expr env e)
  | Tstr_value (_, vbs) ->
    List.iter
      (fun vb ->
         let v = translate_expr env vb.vb_expr in
         match vb.vb_pat.pat_desc with
         | Tpat_var { id; _ } -> Hashtbl.add env.vars id v
         | _ -> ())
      vbs
  | Tstr_primitive _ -> ()
  | _ -> Buffer.add_string env.buf "    // unsupported str_item\n"

let translate_implementation ~module_name (impl : implementation) : string =
  let env =
    { next_id = 0;
      vars = Hashtbl.create 16;
      externals = Hashtbl.create 4;
      buf = Buffer.create 4096;
    }
  in
  List.iter (translate_str_item env) impl.structure.str_items;
  let unit_v = unit_value env in
  Printf.bprintf env.buf "    func.return %s : i64\n" unit_v;
  let out = Buffer.create 4096 in
  Hashtbl.iter
    (fun name arity ->
       let arg_tys = String.concat ", " (List.init arity (fun _ -> "i64")) in
       Printf.bprintf out "  func.func private @%s(%s) -> i64\n"
         name arg_tys)
    env.externals;
  Printf.bprintf out "  func.func @caml%s__entry() -> i64 {\n" module_name;
  Buffer.add_buffer out env.buf;
  Buffer.add_string out "  }\n";
  Buffer.contents out
