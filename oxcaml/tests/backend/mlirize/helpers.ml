type t =
  { exit_status : int;
    stdout : string;
    run_stdout : string;
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
    [ ".ml";
      ".o";
      ".cmi";
      ".cmx";
      ".mlir";
      "_std.mlir";
      ".ll";
      ".stdout";
      ".exe";
      ".build_bin.stdout";
      ".run.stdout";
      "_main.c" ]
  in
  List.iter
    (fun ext ->
      let path = prefix ^ ext in
      if Sys.file_exists path then try Sys.remove path with _ -> ())
    extensions

let find_root () =
  let cwd = Sys.getcwd () in
  let parts = String.split_on_char '/' cwd in
  let rec keep_before_build acc = function
    | [] -> List.rev acc
    | "_build" :: _ -> List.rev acc
    | x :: xs -> keep_before_build (x :: acc) xs
  in
  let real_parts = keep_before_build [] parts in
  String.concat "/" real_parts

let find_ocamlopt () =
  let root = find_root () in
  Filename.concat root "_build/_bootinstall/bin/ocamlopt.opt"

let find_ocamllib () =
  let root = find_root () in
  Filename.concat root "runtime"

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

let test_compile_impl ~cleanup ~name ~code =
  let ocamlopt = find_ocamlopt () in
  let ocamllib = find_ocamllib () in
  let prefix = name in
  clean_temp_files prefix;
  (* Write source *)
  let oc = open_out (prefix ^ ".ml") in
  output_string oc code;
  close_out oc;
  (* Run compiler *)
  let cmd =
    Printf.sprintf
      "env OCAML_COLOR=never %s -nostdlib -nopervasives -mlir-backend -ccopt \
       -I%s -c %s.ml helpers.c > %s.stdout 2>&1"
      ocamlopt ocamllib prefix prefix
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
  if cleanup then clean_temp_files prefix;
  { exit_status; stdout; run_stdout = ""; mlir; std_mlir; llvm }

let test_compile ~name ~code = test_compile_impl ~cleanup:true ~name ~code

let test_compile_and_run ~name ~code =
  let t = test_compile_impl ~cleanup:false ~name ~code in
  let prefix = name in
  let main_c = prefix ^ "_main.c" in
  let entry_sym = "caml" ^ String.capitalize_ascii prefix ^ "__entry" in
  let oc = open_out main_c in
  Printf.fprintf oc
    "extern long %s(void);\nint main(void) {\n  %s();\n  return 0;\n}\n"
    entry_sym entry_sym;
  close_out oc;
  let bin_cmd =
    Printf.sprintf "gcc -o %s.exe %s.o helpers.o %s > %s.build_bin.stdout 2>&1"
      prefix prefix main_c prefix
  in
  let bin_exit = Sys.command bin_cmd in
  let run_stdout =
    if bin_exit <> 0
    then
      let build_bin_stdout = read_file (prefix ^ ".build_bin.stdout") in
      let compile_stdout = read_file (prefix ^ ".stdout") in
      Printf.sprintf
        "<link failed with exit code %d>\n\
         Compiler used: %s\n\
         Compile output:\n\
         %s\n\
         Link output:\n\
         %s"
        bin_exit (find_ocamlopt ()) compile_stdout build_bin_stdout
    else
      let run_cmd =
        Printf.sprintf "./%s.exe > %s.run.stdout 2>&1" prefix prefix
      in
      let run_exit = Sys.command run_cmd in
      let run_output = read_file (prefix ^ ".run.stdout") in
      if run_exit <> 0
      then
        Printf.sprintf "<run failed with exit code %d>\nStdout:\n%s" run_exit
          run_output
      else run_output
  in
  (* Cleanup *)
  clean_temp_files prefix;
  { t with run_stdout }

let verify_build_stdout t =
  if t.exit_status <> 0
  then Printf.printf "Compiler exited with status %d\n" t.exit_status;
  Printf.printf "%s" t.stdout

let verify_mlir t = Printf.printf "%s" t.mlir

let verify_std_mlir t = Printf.printf "%s" t.std_mlir

let verify_llvm t = Printf.printf "%s" t.llvm

let verify_stdout t = Printf.printf "%s" t.run_stdout
