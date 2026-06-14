#include <stdio.h>
#include <stdlib.h>
#include <caml/mlvalues.h>

CAMLprim value print_int(value v) {
  printf("%ld\n", (long)Int_val(v));
  return Val_unit;
}

CAMLprim value print_str(value s) {
  printf("%s\n", String_val(s));
  return Val_unit;
}

CAMLprim value print_float(value v) {
  printf("%g\n", Double_val(v));
  return Val_unit;
}

/* Minimal stand-in for the runtime's caml_copy_double: the backend reboxes
   float results through it, and the run harness does not link the runtime. */
value caml_copy_double(double d) {
  char *block = malloc(16);
  *((uintnat *)block) = ((uintnat)1 << 10) | 0x300 | 253;
  double *data = (double *)(block + 8);
  *data = d;
  return (value)data;
}