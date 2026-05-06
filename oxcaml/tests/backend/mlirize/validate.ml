(* End-to-end validation: pure OCaml.  Exercises arithmetic +
   comparisons, then exits with the computed result as the process
   status so the shell can verify via [$?].  No C harness involved
   beyond the standard libc [_exit] syscall wrapper, which is declared
   here as a regular OCaml [external]. *)

external add : int -> int -> int = "%addint"
external sub : int -> int -> int = "%subint"
external mul : int -> int -> int = "%mulint"

external _exit : int -> int = "_exit"

let _ =
  let a = add 3 4 in        (* 7  *)
  let b = mul a 2 in        (* 14 *)
  let c = sub b 1 in        (* 13 *)
  _exit c                   (* exits the process with status 13 *)
