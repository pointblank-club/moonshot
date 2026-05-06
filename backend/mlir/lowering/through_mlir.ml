open Omlir

let read_file path =
  let ic = open_in path in
  let n = in_channel_length ic in
  let s = Bytes.create n in
  really_input ic s 0 n;
  close_in ic;
  Bytes.to_string s

let write_file path contents =
  let oc = open_out path in
  output_string oc contents;
  close_out oc

let ocaml_mlir_opt = "_build/mlir-dialect/tools/ocaml-mlir-opt/ocaml-mlir-opt"

let lower_to_llvm_dialect ~module_name input =
  let in_file = Filename.temp_file (module_name ^ "_high_") ".mlir" in
  let out_file = Filename.temp_file (module_name ^ "_llvm_") ".mlir" in
  write_file in_file input;
  let cmd =
    Printf.sprintf
      "%s --convert-ocaml-to-arith --convert-arith-to-llvm \
       --convert-func-to-llvm --reconcile-unrealized-casts %s -o %s"
      ocaml_mlir_opt
      (Filename.quote in_file)
      (Filename.quote out_file)
  in
  let rc = Sys.command cmd in
  if rc <> 0 then begin
    Sys.remove in_file;
    failwith (Printf.sprintf "mlir lowering failed (exit %d)" rc)
  end;
  let result = read_file out_file in
  Sys.remove in_file;
  Sys.remove out_file;
  result

let runtime_globals module_name =
  let g name =
    Printf.sprintf
      "  llvm.mlir.global @caml%s__%s() {addr_space = 0 : i32} : i64 {\n\
      \    %%0 = llvm.mlir.constant(0 : i64) : i64\n\
      \    llvm.return %%0 : i64\n\
      \  }\n"
      module_name name
  in
  String.concat "" (List.map g [
    "gc_roots"; "data_begin"; "data_end";
    "code_begin"; "code_end"; "frametable"
  ])

let compile_from_typed ~module_name ~output_prefix ~ppf_dump impl =
  Format.fprintf ppf_dump "Compiling module %s to MLIR\n%!" module_name;

  let entry_body = Translate.translate_implementation ~module_name impl in
  let high_level =
    Printf.sprintf "module {\n%s%s}\n" (runtime_globals module_name) entry_body
  in
  Format.fprintf ppf_dump "// high-level MLIR\n%s%!" high_level;

  let lowered = lower_to_llvm_dialect ~module_name high_level in

  let ctx = MlirContext.create () in
  let registry = Bindings.Ir.mlirDialectRegistryCreate () in
  Bindings.RegisterEverything.mlirRegisterAllDialects registry;
  Bindings.Ir.mlirContextAppendDialectRegistry ctx.MlirContext.raw registry;
  Bindings.Ir.mlirContextLoadAllAvailableDialects ctx.MlirContext.raw;
  Bindings.RegisterEverything.mlirRegisterAllLLVMTranslations
    ctx.MlirContext.raw;
  Bindings.Ir.mlirDialectRegistryDestroy registry;

  let builder = Ir.Builders.OpBuilder.create ctx in
  let loc = Ir.Builders.OpBuilder.get_unknown_loc builder in
  let mlir_mod = Ir.BuiltinOps.ModuleOp.create_parse loc ctx lowered in

  Llvm_emitter.translate_and_emit ~module_name ~output_prefix ~mlir_mod
    ~ppf_dump;

  Format.fprintf ppf_dump "Generated object file: %s.o\n%!" output_prefix
