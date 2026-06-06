#include <stdio.h>
#include <caml/mlvalues.h>

CAMLprim value print_int(value v) {
  printf("%ld\n", (long)Int_val(v));
  return Val_unit;
}

CAMLprim value print_str(value s) {
  printf("%s\n", String_val(s));
  return Val_unit;
}