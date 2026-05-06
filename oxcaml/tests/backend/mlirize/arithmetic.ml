(* Exercises every integer arithmetic primitive lowered through ocaml.* ops. *)

external add : int -> int -> int = "%addint"
external sub : int -> int -> int = "%subint"
external mul : int -> int -> int = "%mulint"
external div : int -> int -> int = "%divint"
external rem : int -> int -> int = "%modint"

let _ = add 1 2
let _ = sub 7 3
let _ = mul 4 5
let _ = div 20 4
let _ = rem 17 5
