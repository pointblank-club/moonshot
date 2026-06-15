# Glossary

This page defines terms used throughout the Moonshot documentation.

## A

**arith dialect**
MLIR dialect for arithmetic operations (`arith.addi`, `arith.muli`, `arith.cmpi`, etc.). The MLIR backend lowers integer and float operations to this dialect.

## B

**backend**
The part of the compiler that turns intermediate code into machine code. Moonshot has three backends: classic (Mach linear), CFG, and MLIR.

**bootstrap**
The process of building a compiler using itself. The MLIR backend has a bootstrap circularity because the build needs `unix`/`threads` from the opam switch, but the switch needs an OxCaml compiler.

## C

**CFG (Control-Flow Graph)**
A representation of a program where instructions are grouped into basic blocks, and blocks have edges to their successors. The CFG backend is the default in OxCaml.

**Cmm**
A low-level C-like intermediate representation used by the classic and CFG backends.

**ctypes**
An OCaml library for calling C functions. The MLIR bindings use ctypes to wrap MLIR's C API.

**custom dialect**
An MLIR dialect defined for a specific purpose. Moonshot defines the `ocaml` dialect to capture OCaml-specific constructs.

## D

**dialect**
In MLIR, a dialect is a namespace of operations, types, and attributes. Examples: `arith`, `func`, `llvm`, `ocaml`.

## E

**entry function**
In OCaml, the top-level code of a module is compiled into an entry function named `caml<ModuleName>__entry`. The MLIR backend generates this function.

**external function**
An OCaml function declared with `external` that maps to a C function. The MLIR backend supports these via `ocaml.extern` and `ocaml.extern_call`.

## F

**Flambda 2**
The whole-program optimizer in OxCaml. It operates in CPS (continuation-passing style) and performs aggressive optimizations like inlining, unboxing, and dead code elimination.

**frontend**
The part of the compiler that parses and type-checks source code. In Moonshot, the frontend is shared with upstream OCaml.

## G

**GC (Garbage Collector)**
The OCaml runtime's memory management system. The MLIR backend does not yet integrate the GC.

## I

**IR (Intermediate Representation)**
A data structure used internally by a compiler to represent a program. Moonshot uses several IRs: Parsetree, Typedtree, Lambda, Slambda, Flambda, Cmm, CFG, MLIR, LLVM IR.

## L

**Lambda**
A simplified, untyped lambda calculus IR. The traditional backend converts Typedtree to Lambda.

**LLVM IR**
The intermediate representation used by the LLVM compiler infrastructure. It is a typed, SSA-based assembly language.

**lowering**
The process of transforming a high-level IR into a lower-level IR. The MLIR backend lowers the `ocaml` dialect to `arith`, `func`, `scf`, and eventually `llvm`.

## M

**Mach**
The linear IR used by the classic OCaml backend. It has been replaced by the CFG backend in OxCaml.

**match compilation**
The process of converting OCaml `match` expressions into lower-level control flow (jumps, comparisons, etc.). The MLIR backend does not yet support this.

**Menhir**
The parser generator used by OCaml. It reads `.mly` files and produces OCaml parsers.

**MLIR**
Multi-Level Intermediate Representation. A compiler infrastructure from LLVM that supports multiple dialects and progressive lowering.

**MLIR backend**
The experimental backend in Moonshot that compiles OCaml through Typedtree → MLIR → LLVM IR.

## N

**nativeint**
An OCaml integer type that matches the native machine word size (32 or 64 bits).

## O

**ocaml dialect**
The custom MLIR dialect defined by Moonshot. It includes ops like `ocaml.int`, `ocaml.string`, `ocaml.binop`, `ocaml.extern`, and `ocaml.extern_call`.

**OPAM**
The OCaml package manager. Moonshot is installed and built via OPAM.

**OxCaml**
A performance-focused fork of OCaml maintained by Jane Street. It includes Flambda 2 and the CFG backend.

## P

**Parsetree**
The untyped abstract syntax tree produced by the OCaml parser.

**pattern matching**
OCaml's control structure for inspecting and deconstructing data. The MLIR backend does not yet support general pattern matching.

**ppx_expect**
An OCaml testing framework that captures stdout and compares it against expected output. The MLIR backend tests use this.

## S

**scf dialect**
MLIR's structured control flow dialect. It contains `scf.if` and `scf.for`, which the MLIR backend uses for conditionals and loops.

**Slambda**
Lambda with layout information (value representation). Used by Flambda 2.

**SSA (Static Single Assignment)**
A property of IRs where each variable is assigned exactly once. MLIR and LLVM IR are SSA-based.

**stub**
A small C function that bridges OCaml and C. The MLIR bindings use ctypes stubs to call MLIR's C API.

## T

**TableGen**
A tool from LLVM that generates C++ code from declarative descriptions. MLIR uses TableGen for dialect and pass definitions.

**tagged integer**
OCaml's representation for immediate integers: the value is shifted left by 1 and the low bit is set to 1. So `42` is represented as `85` at the runtime level.

**Typedtree**
The fully typed abstract syntax tree produced by the OCaml type checker. This is the entry point for the MLIR backend.

## U

**unboxing**
An optimization that removes the heap allocation of a value by passing its fields directly. Flambda 2 performs unboxing aggressively.

**unrealized_conversion_cast**
An MLIR op that represents a type conversion that has not yet been lowered. Removed by the `--reconcile-unrealized-casts` pass.

## V

**value representation**
How OCaml values are laid out in memory. Integers are tagged, strings have headers, variants have tags, etc.

## Next steps

- [Flags](flags.md) — compiler flags reference
- [Architecture overview](../architecture/overview.md) — how the compiler is organized
- [IRs](../architecture/irs.md) — what each intermediate representation looks like
