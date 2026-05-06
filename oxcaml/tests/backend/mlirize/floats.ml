(* Float arithmetic + comparison primitives. Compares share the
   polymorphic primitive names (`%lessthan` etc.) with int — the
   translator dispatches to ocaml.cmpf based on operand type. *)

external addf : float -> float -> float = "%addfloat"
external subf : float -> float -> float = "%subfloat"
external mulf : float -> float -> float = "%mulfloat"
external divf : float -> float -> float = "%divfloat"

external eqf : float -> float -> bool = "%equal"
external nef : float -> float -> bool = "%notequal"
external ltf : float -> float -> bool = "%lessthan"
external lef : float -> float -> bool = "%lessequal"
external gtf : float -> float -> bool = "%greaterthan"
external gef : float -> float -> bool = "%greaterequal"

let _ = addf 1.5 2.5
let _ = subf 5.0 3.0
let _ = mulf 2.0 4.0
let _ = divf 10.0 4.0

let _ = eqf 1.0 2.0
let _ = nef 1.0 2.0
let _ = ltf 1.0 2.0
let _ = lef 1.0 2.0
let _ = gtf 1.0 2.0
let _ = gef 1.0 2.0
