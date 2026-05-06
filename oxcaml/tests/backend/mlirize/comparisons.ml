(* Exercises every integer comparison primitive lowered to ocaml.cmpi.
   Each [%prim] maps to a predicate in OCaml_CmpIPredicateAttr. *)

external eq : int -> int -> bool = "%equal"
external ne : int -> int -> bool = "%notequal"
external lt : int -> int -> bool = "%lessthan"
external le : int -> int -> bool = "%lessequal"
external gt : int -> int -> bool = "%greaterthan"
external ge : int -> int -> bool = "%greaterequal"
external phys_eq : int -> int -> bool = "%eq"
external phys_ne : int -> int -> bool = "%noteq"

let _ = eq 1 2
let _ = ne 1 2
let _ = lt 1 2
let _ = le 1 2
let _ = gt 1 2
let _ = ge 1 2
let _ = phys_eq 1 2
let _ = phys_ne 1 2
