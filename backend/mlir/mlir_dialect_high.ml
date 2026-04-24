(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

let dialect_name = "oxcaml_high"

type type_ =
  | T_unit
  | T_int
  | T_float
  | T_bool
  | T_box of type_
  | T_tuple of type_ list
  | T_arrow of type_ list * type_
  | T_opaque of string

type value_ = { v_id : int; v_type : type_ }

type op =
  | Const_unit
  | Const_int of int
  | Const_float of float
  | Const_bool of bool
  | Var of string
  | Let of { name : string; rhs : op; body : op }
  | Apply of { fn : op; args : op list }
  | Tuple of op list
  | If of { cond : op; then_ : op; else_ : op }
  | Return of op

type block = { b_label : string; b_ops : op list }

type func = {
  f_name : string;
  f_params : (string * type_) list;
  f_return_type : type_;
  f_body : block list
}

type module_ = {
  m_name : string;
  mutable m_funcs : func list
}

let create_module ~name = { m_name = name; m_funcs = [] }

let module_name m = m.m_name

let pp_module ppf m =
  Format.fprintf ppf "@[<v>// dialect: %s@,module %s {@,  // <%d functions>@,}@]"
    dialect_name m.m_name (List.length m.m_funcs)
