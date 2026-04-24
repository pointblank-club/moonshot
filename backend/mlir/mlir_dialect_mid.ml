(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

let dialect_name = "oxcaml_mid"

type machine_type =
  | M_int          (* native-word integer *)
  | M_float
  | M_ptr          (* pointer to a heap block *)
  | M_void

type value_ = { v_id : int; v_type : machine_type }

type op =
  | Const_int of int
  | Const_float of float
  | Load of { addr : value_; ty : machine_type }
  | Store of { addr : value_; value : value_ }
  | Add of value_ * value_
  | Sub of value_ * value_
  | Mul of value_ * value_
  | Call_direct of { callee : string; args : value_ list }
  | Call_indirect of { fn : value_; args : value_ list }
  | Branch of { target : string }
  | Cond_branch of
      { cond : value_; if_true : string; if_false : string }
  | Return of value_ option

type block = { b_label : string; b_ops : op list }

type func = {
  f_name : string;
  f_params : (string * machine_type) list;
  f_return_type : machine_type;
  f_body : block list
}

type module_ = {
  m_name : string;
  mutable m_funcs : func list;
  mutable m_data : (string * bytes) list
}

let create_module ~name = { m_name = name; m_funcs = []; m_data = [] }

let module_name m = m.m_name

let pp_module ppf m =
  Format.fprintf ppf
    "@[<v>// dialect: %s@,module %s {@,  // <%d functions, %d data items>@,}@]"
    dialect_name m.m_name
    (List.length m.m_funcs) (List.length m.m_data)
