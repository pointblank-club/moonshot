(* Exercises top-level [let x = ...], nested [let x = ... in ...],
   and identifier references — checking the translator's value
   environment threads SSA names through both forms. *)

external add : int -> int -> int = "%addint"
external mul : int -> int -> int = "%mulint"
external lt : int -> int -> bool = "%lessthan"
external eq : int -> int -> bool = "%equal"

(* Top-level binding referenced by later items. *)
let base = 10
let _ = lt base 20

(* Nested let-in. *)
let _ =
  let x = 1 in
  let y = 2 in
  add x y

(* Aliased variable. *)
let _ =
  let a = 5 in
  let b = a in
  mul a b

(* Top-level variable used inside a nested let. *)
let _ =
  let bumped = add base 1 in
  eq bumped 11
