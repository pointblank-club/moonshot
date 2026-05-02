open Omlir.Target.Llvmir

let translate_and_emit ~module_name ~output_prefix ~mlir_mod ~ppf_dump =
  let _ = module_name in
  let _ = ppf_dump in

  let llvm_ctx = Llvm.Context.create () in
  let llvm_mod = Llvm.Module.create_from_mlir_module mlir_mod llvm_ctx in


  Llvm.initialize_x86_target_info ();
  Llvm.initialize_x86_target ();
  Llvm.initialize_x86_target_mc ();
  Llvm.initialize_x86_asm_printer ();

  let triple = Llvm.get_default_target_triple () in

  Llvm.Module.set_target llvm_mod triple;

  let out_file = output_prefix ^ ".o" in

  let target = Llvm.get_target_from_triple triple in

  let target_machine = Llvm.create_target_machine target triple "generic" "" LLVMCodeGenLevelDefault LLVMRelocDefault LLVMCodeModelDefault in

  Llvm.target_machine_emit_to_file target_machine llvm_mod.raw out_file LLVMObjectFile
