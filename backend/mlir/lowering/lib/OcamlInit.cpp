#include "OCaml/OCamlDialect.h"
#include "OCaml/Passes.h"

#include "mlir/CAPI/IR.h" // Needed for unwrap/wrap of MLIR C-API types
#include "mlir/Conversion/Passes.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/Location.h"
#include "mlir/InitAllDialects.h"
#include "mlir/Parser/Parser.h"
#include "mlir/Pass/PassManager.h"
#include "mlir/Target/LLVMIR/Export.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/Target/TargetOptions.h"
#include "llvm/TargetParser/Host.h"
#include "llvm/TargetParser/Triple.h"

#include <optional>

#define CAML_NAME_SPACE
#include <caml/alloc.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>

inline constexpr int OCaml_CC = 128;
inline constexpr int OCaml_C_Call_CC = 129;

extern "C" {
CAMLprim value mlirContextRegisterOCamlDialect(value v_ctx_ptr) {
  CAMLparam1(v_ctx_ptr);
  MlirContext c_ctx = {(void *)Nativeint_val(v_ctx_ptr)};
  mlir::MLIRContext *context = unwrap(c_ctx);
  context->getOrLoadDialect<ocaml::OCamlDialect>();
  CAMLreturn(Val_unit);
}

CAMLprim value OcamlLoweringInit(value v_ctx_ptr, value v_op_ptr,
                                 value v_output_file) {
  CAMLparam3(v_ctx_ptr, v_op_ptr, v_output_file);
  const char *output_file = String_val(v_output_file);

  llvm::InitializeNativeTarget();
  llvm::InitializeNativeTargetAsmPrinter();
  llvm::InitializeNativeTargetAsmParser();

  MlirContext c_ctx = {(void *)Nativeint_val(v_ctx_ptr)};
  MlirOperation c_op = {(void *)Nativeint_val(v_op_ptr)};

  mlir::MLIRContext *context = unwrap(c_ctx);
  mlir::Operation *top = unwrap(c_op);

  if (!top) {
    caml_failwith("Invalid MLIR operation passed to C++ backend");
  }
  auto ocaml_module = mlir::dyn_cast<ocaml::ModuleOp>(top);
  if (!ocaml_module) {
    caml_failwith("Expected top-level ocaml.module operation");
  }

  // 1. Write the initial/input MLIR module representation to <prefix>.mlir
  std::string mlir_file = std::string(output_file);
  if (mlir_file.size() >= 2 && mlir_file.substr(mlir_file.size() - 2) == ".o") {
    mlir_file = mlir_file.substr(0, mlir_file.size() - 2) + ".mlir";
  } else {
    mlir_file = mlir_file + ".mlir";
  }
  std::error_code ec_mlir;
  llvm::raw_fd_ostream mlir_dest(mlir_file, ec_mlir, llvm::sys::fs::OF_None);
  if (!ec_mlir) {
    // Print with debug info so source locations attached during MLIR
    mlir::OpPrintingFlags flags;
    flags.enableDebugInfo(/*enable=*/true, /*prettyForm=*/false);
    top->print(mlir_dest, flags);
    mlir_dest.flush();
  }

  std::string source_filename;
  top->walk([&](mlir::Operation *op) {
    if (auto floc = mlir::dyn_cast<mlir::FileLineColLoc>(op->getLoc())) {
      source_filename = floc.getFilename().str();
      return mlir::WalkResult::interrupt();
    }
    return mlir::WalkResult::advance();
  });

  mlir::ModuleOp module = mlir::ModuleOp::create(ocaml_module.getLoc());
  module.getBody()->push_back(ocaml_module.getOperation());

  mlir::PassManager pm(context);
  pm.addPass(ocaml::createConvertOCamlToBuiltin());
  pm.addPass(mlir::createArithToLLVMConversionPass());
  pm.addPass(mlir::createConvertFuncToLLVMPass());
  pm.addPass(mlir::createReconcileUnrealizedCastsPass());

  if (mlir::failed(pm.run(module))) {
    caml_failwith("MLIR C++ lowering passes failed");
  }

  llvm::LLVMContext llvm_ctx;
  std::unique_ptr<llvm::Module> llvm_mod =
      mlir::translateModuleToLLVMIR(module, llvm_ctx);
  if (!llvm_mod) {
    caml_failwith("Failed to translate MLIR to LLVM IR");
  }

  if (auto *f = llvm_mod->getFunction("caml_c_call")) {
    f->setCallingConv(static_cast<llvm::CallingConv::ID>(OCaml_C_Call_CC));
    for (auto *user : f->users()) {
      if (auto *call = llvm::dyn_cast<llvm::CallBase>(user)) {
        call->setCallingConv(
            static_cast<llvm::CallingConv::ID>(OCaml_C_Call_CC));
      }
    }
  }

  if (!source_filename.empty()) {
    llvm_mod->setModuleIdentifier(source_filename);
    llvm_mod->setSourceFileName(source_filename);
  }

  std::string tripleStr = llvm::sys::getDefaultTargetTriple();
  llvm::Triple triple(tripleStr);

  llvm_mod->setTargetTriple(triple);

  std::string error;
  const llvm::Target *target =
      llvm::TargetRegistry::lookupTarget("", triple, error);

  if (!target) {
    caml_failwith(error.c_str());
  }

  llvm::TargetOptions opt;
  llvm::TargetMachine *target_machine = target->createTargetMachine(
      llvm::Triple(triple), "generic", "", opt, std::nullopt);
  if (!target_machine) {
    caml_failwith("Failed to create LLVM TargetMachine");
  }

  llvm_mod->setDataLayout(target_machine->createDataLayout());

  // 2. Write the lowered standard MLIR to <prefix>_std.mlir
  std::string std_mlir_file = std::string(output_file);
  if (std_mlir_file.size() >= 2 &&
      std_mlir_file.substr(std_mlir_file.size() - 2) == ".o") {
    std_mlir_file =
        std_mlir_file.substr(0, std_mlir_file.size() - 2) + "_std.mlir";
  } else {
    std_mlir_file = std_mlir_file + "_std.mlir";
  }
  std::error_code ec_std_mlir;
  llvm::raw_fd_ostream std_mlir_dest(std_mlir_file, ec_std_mlir,
                                     llvm::sys::fs::OF_None);
  if (!ec_std_mlir) {
    module.print(std_mlir_dest);
    std_mlir_dest.flush();
  }

  // 3. Write the generated LLVM IR representation to <prefix>.ll
  std::string llvm_file = std::string(output_file);
  if (llvm_file.size() >= 2 && llvm_file.substr(llvm_file.size() - 2) == ".o") {
    llvm_file = llvm_file.substr(0, llvm_file.size() - 2) + ".ll";
  } else {
    llvm_file = llvm_file + ".ll";
  }
  std::error_code ec_ll;
  llvm::raw_fd_ostream ll_dest(llvm_file, ec_ll, llvm::sys::fs::OF_None);
  if (!ec_ll) {
    llvm_mod->print(ll_dest, nullptr);
    ll_dest.flush();
  }

  std::error_code ec_obj;
  llvm::raw_fd_ostream dest(output_file, ec_obj, llvm::sys::fs::OF_None);
  if (ec_obj) {
    caml_failwith(("Could not open output file: " + ec_obj.message()).c_str());
  }

  llvm::legacy::PassManager pass;
  if (target_machine->addPassesToEmitFile(pass, dest, nullptr,
                                          llvm::CodeGenFileType::ObjectFile)) {
    caml_failwith("LLVM target machine cannot emit an object file");
  }

  pass.run(*llvm_mod);
  dest.flush();

  CAMLreturn(Val_unit);
}
}
