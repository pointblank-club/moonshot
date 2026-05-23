include "mlir/IR/OpBase.td"
include "mlir/IR/SymbolInterfaces.td"

def OCaml_Dialect : Dialect {
  let name = "ocaml";
  let summary = "The OCaml Dialect";
  let description = [{
    The OCaml dialect represents OCaml-specific constructs during compilation.
  }];
  let cppNamespace = "::ocaml";
}

class OCaml_Op<string mnemonic, list<Trait> traits = []> :
    Op<OCaml_Dialect, mnemonic, traits>;

def ModuleOp : OCaml_Op<"module", [
    IsolatedFromAbove,
    NoRegionArguments,
    Symbol,
    SymbolTable,
    NoTerminator
]> {
  let summary = "The top-level OCaml module operation";
  let arguments = (ins OptionalAttr<SymbolNameAttr>:$sym_name);
  let regions = (region AnyRegion:$body);
  let assemblyFormat = "($sym_name^)? attr-dict-with-keyword $body";
}

def EntryOp : OCaml_Op<"entry", [
    NoRegionArguments,
    NoTerminator
]> {
  let summary = "The OCaml entry point operation";
  let regions = (region AnyRegion:$body);
  let assemblyFormat = "attr-dict-with-keyword $body";
}
