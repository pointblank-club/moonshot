open Omlir

let compile_from_typed ~module_name ~output_prefix ~ppf_dump _impl =
  Format.fprintf ppf_dump "Compiling module %s to MLIR\n%!" module_name;

  let ctx = MlirContext.create () in
  let builder = Ir.Builders.OpBuilder.create ctx in

  (* For now, we'll just generate a dummy module with the basic functions needed for the runtime. *)
  (* Later, we'll introduce a proper MLIR dialect, which will lower into the required LLVM IR. *)
  let mlir_code = Printf.sprintf "
module {
  llvm.mlir.global @caml%s__gc_roots() {addr_space = 0 : i32} : i64 {
    %%0 = llvm.mlir.constant(0 : i64) : i64
    llvm.return %%0 : i64
  }
  llvm.mlir.global @caml%s__data_begin() {addr_space = 0 : i32} : i64 {
    %%0 = llvm.mlir.constant(0 : i64) : i64
    llvm.return %%0 : i64
  }
  llvm.mlir.global @caml%s__data_end() {addr_space = 0 : i32} : i64 {
    %%0 = llvm.mlir.constant(0 : i64) : i64
    llvm.return %%0 : i64
  }
  llvm.mlir.global @caml%s__code_begin() {addr_space = 0 : i32} : i64 {
    %%0 = llvm.mlir.constant(0 : i64) : i64
    llvm.return %%0 : i64
  }
  llvm.mlir.global @caml%s__code_end() {addr_space = 0 : i32} : i64 {
    %%0 = llvm.mlir.constant(0 : i64) : i64
    llvm.return %%0 : i64
  }
  llvm.mlir.global @caml%s__frametable() {addr_space = 0 : i32} : i64 {
    %%0 = llvm.mlir.constant(0 : i64) : i64
    llvm.return %%0 : i64
  }

  llvm.func @caml%s__entry() -> i64 {
    %%0 = llvm.mlir.constant(1 : i64) : i64
    llvm.return %%0 : i64
  }
}
" module_name module_name module_name module_name module_name module_name module_name in

  (* Register all dialects *)
  let registry = Bindings.Ir.mlirDialectRegistryCreate () in
  Bindings.RegisterEverything.mlirRegisterAllDialects registry;
  Bindings.Ir.mlirContextAppendDialectRegistry ctx.MlirContext.raw registry;
  Bindings.Ir.mlirContextLoadAllAvailableDialects ctx.MlirContext.raw;
  Bindings.RegisterEverything.mlirRegisterAllLLVMTranslations ctx.MlirContext.raw;
  Bindings.Ir.mlirDialectRegistryDestroy registry;

  (* Parse MLIR module *)
  let mlir_mod = Ir.BuiltinOps.ModuleOp.create_parse (Ir.Builders.OpBuilder.get_unknown_loc builder) ctx mlir_code in

  (* Translate MLIR to LLVM IR and emit the final object file *)
  Llvm_emitter.translate_and_emit ~module_name ~output_prefix ~mlir_mod ~ppf_dump;

  Format.fprintf ppf_dump "Generated object file: %s.o\n%!" output_prefix
