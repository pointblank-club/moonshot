type t =
  { exit_status : int;
    stdout : string;
    mlir : string;
    std_mlir : string;
    llvm : string
  }

let read_file path =
  if not (Sys.file_exists path)
  then Printf.sprintf "<file %s does not exist>\n" path
  else
    let ic = open_in path in
    let len = in_channel_length ic in
    let content = really_input_string ic len in
    close_in ic;
    content

let clean_temp_files prefix =
  let extensions =
    [".ml"; ".o"; ".cmi"; ".cmx"; ".mlir"; "_std.mlir"; ".ll"; ".stdout"]
  in
  List.iter
    (fun ext ->
      let path = prefix ^ ext in
      if Sys.file_exists path then try Sys.remove path with _ -> ())
    extensions

let find_ocamlopt () =
  let rec find_root dir =
    if Sys.file_exists (Filename.concat dir "dune-project")
    then dir
    else
      let parent = Filename.dirname dir in
      if parent = dir
      then failwith "Could not find repo root"
      else find_root parent
  in
  let root = find_root (Sys.getcwd ()) in
  Filename.concat root "_build/_bootinstall/bin/ocamlopt.opt"

let clean_llvm content =
  let lines = String.split_on_char '\n' content in
  let filtered =
    List.filter
      (fun line ->
        not
          (String.starts_with ~prefix:"target datalayout" line
          || String.starts_with ~prefix:"target triple" line))
      lines
  in
  String.concat "\n" filtered

let test_compile ~name ~code =
  let ocamlopt = find_ocamlopt () in
  let prefix = name in
  clean_temp_files prefix;
  (* Write source *)
  let oc = open_out (prefix ^ ".ml") in
  output_string oc code;
  close_out oc;
  (* Run compiler *)
  let cmd =
    Printf.sprintf
      "%s -nostdlib -nopervasives -mlir-backend -c %s.ml > %s.stdout 2>&1"
      ocamlopt prefix prefix
  in
  let exit_status = Sys.command cmd in
  (* Print compiler stdout *)
  let stdout_content = read_file (prefix ^ ".stdout") in
  (* Normalize paths in stdout *)
  let lines = String.split_on_char '\n' stdout_content in
  let cleaned_lines =
    List.map
      (fun line ->
        if String.starts_with ~prefix:"Generated object file:" line
        then "Generated object file: <path_to_object_file>"
        else line)
      lines
  in
  let stdout = String.concat "\n" cleaned_lines in
  let mlir = read_file (prefix ^ ".mlir") in
  let std_mlir = read_file (prefix ^ "_std.mlir") in
  let llvm_raw = read_file (prefix ^ ".ll") in
  let llvm = clean_llvm llvm_raw in
  (* Cleanup *)
  clean_temp_files prefix;
  { exit_status; stdout; mlir; std_mlir; llvm }

let verify_build_stdout t =
  if t.exit_status <> 0
  then Printf.printf "Compiler exited with status %d\n" t.exit_status;
  Printf.printf "%s" t.stdout

let verify_mlir t = Printf.printf "%s" t.mlir

let verify_std_mlir t = Printf.printf "%s" t.std_mlir

let verify_llvm t = Printf.printf "%s" t.llvm
