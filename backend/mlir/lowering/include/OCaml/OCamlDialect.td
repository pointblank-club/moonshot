#ifndef OCAML_DIALECT
#define OCAML_DIALECT

include "mlir/IR/OpBase.td"

def OCaml_Dialect : Dialect {
  let name = "ocaml";
  let summary = "The OCaml Dialect";
  let description = [{
    The OCaml dialect represents OCaml-specific constructs during compilation.
  }];
  let cppNamespace = "::ocaml";
  let useDefaultTypePrinterParser = 1;
}

#endif // OCAML_DIALECT
