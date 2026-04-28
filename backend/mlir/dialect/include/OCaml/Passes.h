#ifndef OCAML_PASSES_H
#define OCAML_PASSES_H

#include "mlir/Pass/Pass.h"

namespace ocaml {

#define GEN_PASS_DECL
#include "OCaml/Passes.h.inc"

#define GEN_PASS_REGISTRATION
#include "OCaml/Passes.h.inc"

} // namespace ocaml

#endif // OCAML_PASSES_H
