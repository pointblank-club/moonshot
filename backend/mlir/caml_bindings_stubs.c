#include <caml/memory.h>
#include <caml/mlvalues.h>

extern value mlirContextRegisterOCamlDialect(value v_ctx_ptr);
extern value OcamlLoweringInit(value v_ctx_ptr, value v_op_ptr,
                               value v_output_file);

CAMLprim value caml_mlirContextRegisterOCamlDialect(value v_ctx_ptr) {
  CAMLparam1(v_ctx_ptr);
  CAMLreturn(mlirContextRegisterOCamlDialect(v_ctx_ptr));
}

CAMLprim value caml_OcamlLoweringInit(value v_ctx_ptr, value v_op_ptr,
                                      value v_output_file) {
  CAMLparam3(v_ctx_ptr, v_op_ptr, v_output_file);
  CAMLreturn(OcamlLoweringInit(v_ctx_ptr, v_op_ptr, v_output_file));
}
