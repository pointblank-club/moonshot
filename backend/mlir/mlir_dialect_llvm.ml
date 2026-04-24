(**************************************************************************)
(*                                                                        *)
(*                                 OxCaml                                  *)
(*                                                                        *)
(*                         MLIR backend (experimental)                    *)
(*                                                                        *)
(**************************************************************************)

let dialect_name = "llvm"

type module_ = {
  m_name : string;
  mutable m_ir_text : string
}

let create_module ~name = { m_name = name; m_ir_text = "" }

let pp_module ppf m =
  Format.fprintf ppf "@[<v>// dialect: %s@,module %s {@,%s@,}@]"
    dialect_name m.m_name m.m_ir_text

let to_llvm_ir_text m = m.m_ir_text
