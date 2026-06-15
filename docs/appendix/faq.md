# Frequently Asked Questions

## General

### What is Moonshot?

Moonshot is an experimental compiler backend for OCaml that uses MLIR and LLVM to compile OCaml source code through a modern, retargetable pipeline. It sits on top of OxCaml, a performance-focused fork of OCaml.

### Who is working on it?

Moonshot is developed by compiler researchers and engineers working on high-performance compilers for functional programming languages. The main contributors focus on the MLIR backend, the MLIR OCaml bindings, and the binding generator.

### Is it ready for production?

No. The MLIR backend is experimental and supports only a small subset of OCaml. The CFG backend (default in OxCaml) is production-ready.

## Building

### How long does the build take?

A full build from scratch with the MLIR backend takes 2–3 hours. Incremental builds with `make -s boot-compiler` take a few minutes.

### Can I build on macOS?

Yes, but the MLIR backend requires LLVM 22. You may need to build LLVM from source or use Homebrew if it provides version 22.

### Can I build on Windows?

Not currently. The build scripts and paths assume a Unix-like environment.

### Why is the build so complicated?

The MLIR backend introduces a bootstrap circularity. The compiler needs `unix` and `threads` from the opam switch, but the switch needs an OxCaml compiler. The build script breaks this loop in multiple phases.

### Can I just build the compiler without the MLIR backend?

Yes. Follow the [quick install](../getting-started/installation.md) instructions. The MLIR backend is only needed if you want to experiment with it.

## MLIR backend

### What subset of OCaml works?

Currently: integer constants, string constants, integer arithmetic, float arithmetic, comparisons, boolean logic, let bindings, if-then-else, and external function calls.

### What does not work?

Pattern matching, lists, arrays, records, variants, tuples, closures, the GC, exceptions, and the standard library. See the [feature roadmap](../language/roadmap.md).

### How do I see the MLIR output?

```bash
ocamlopt -mlir-backend -c foo.ml
```

This prints the custom `ocaml` dialect. To see the standard MLIR and LLVM IR, follow the steps in the [quickstart](../getting-started/quickstart.md).

### Why a custom MLIR dialect?

OCaml has language-specific concepts (tagged integers, immutable strings, closures) that do not map cleanly to standard MLIR dialects. The custom dialect captures these at a high level.

### How does the MLIR backend compare to the LLVM backend?

OxCaml already has an experimental LLVM backend that translates CFG IR to LLVM IR. The MLIR backend is a separate path that goes directly from Typedtree to MLIR, bypassing Lambda, Cmm, and CFG entirely.

### Can I use MLIR optimization passes?

Not yet. Future work will add MLIR passes like CSE, inlining, and loop optimization.

### Can I target GPU?

Not yet. The MLIR infrastructure supports GPU dialects, but this is future work.

## Testing

### How do I run the MLIR backend tests?

```bash
make -s runtest-mlirize
```

### How do I update expected test output?

```bash
make -s runtest-mlirize PROMOTE=1
```

### Why did a test start failing after my change?

If you modified the frontend emission or the lowering pass, the MLIR output will change. If the change is correct, promote the expected output. If it is not, debug the change.

## Contributing

### How do I add a new MLIR operation?

See the [contributing guide](../developer/contributing.md#adding-a-new-mlir-operation).

### How do I regenerate the MLIR bindings?

See the [bindings guide](../mlir-backend/bindings.md#regenerating-the-auto-generated-layer).

### What coding style should I follow?

- Keep lines under 80 characters
- Use pattern matching
- Do not add `assert false`
- Run `make -s fmt` before committing

### How do I report a bug?

Open an issue on the [moonshot GitHub repo](https://github.com/pointblank-club/moonshot) with:

- The exact command you ran
- The full error output
- Your platform (OS, architecture, LLVM version)
- The commit hash of the code you are building

## Next steps

- [Getting started](../getting-started/) — install and build
- [Developer guide](../developer/) — how to contribute
- [MLIR backend](../mlir-backend/) — how the backend works
