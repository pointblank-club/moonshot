# Flambda 2 Encyclopedia

This is a reproduction of the upstream Flambda 2 optimization reference for Moonshot contributors. The original lives in `middle_end/flambda2/docs/encyclopaedia.md`.

## CPS conversion

The flambda2 optimizer does not operate directly on the surface OCaml syntax but on an intermediate representation using continuations and continuation-passing style (CPS). The first "optimization" performed by the flambda2 optimizer is to convert code into CPS, and all other optimizations can only be fully understood in the context of CPS.

The CPS conversion makes control flow explicit by replacing all control flow joins with continuations, and all disjunctions with a `match`. Continuations are annotated with the `[@local]` attribute.

## Canonicalization

Canonicalization is a pervasive optimization that identifies all the names of a given expression, and replaces all their usages with the first such name that was defined (or a constant, if applicable).

This is the most basic of the optimizations performed by flambda2, and is generally critical to cleaning up the code after other optimizations.

## Unboxing

Unboxing is an optimization that triggers when a continuation has a parameter with a fixed shape (e.g. a tuple, or a boxed float), and at least one of the calls to that continuation is an allocation (of the corresponding shape).

In this situation, Unboxing adds new arguments to the continuation for each of the fields of the allocation, potentially introducing projections at the other call sites. In conjunction with Canonicalization and Dead Code Elimination, this often allows eliminating the allocation.

## Variant Unboxing

Variant unboxing is an optimization that triggers when an optimization has a parameter with multiple possible representations (e.g. an option), at least one of the calls to that continuation is a constructor, and the shape of the argument is known at all the call sites.

In this situation, Variant Unboxing adds a new argument to the continuation to represent the _tag_ of the parameter, and new arguments for each of the fields of the constructor.

## Match optimizations

### Match Elimination

Match Elimination is an optimization that triggers when the scrutinee of a match is a constructor (or literal), and replaces the entire match with the corresponding branch.

### Match Simplification

Match Simplification is an optimization that triggers when some branches of a match are unreachable, and removes the unreachable branches. If there is only one branch remaining, the entire match is removed and replaced with that branch.

### Match Forwarding

Match Forwarding is an optimization that triggers when the scrutinee of a match is a variable, and all the branches of the match are applications of the same continuation.

## Inlining

Flambda 2 performs both intra-function and inter-function inlining. It uses a cost model that takes into account the size of the function, the number of call sites, and the expected benefit of inlining.

## Dead Code Elimination

Dead Code Elimination removes unused bindings, unused branches, and unreachable code. It is tightly coupled with Canonicalization and Unboxing.

## Loop optimizations

Flambda 2 does not currently perform advanced loop optimizations (unrolling, invariant code motion, etc.). These are potential future work.

## Next steps

- [Architecture overview](../architecture/overview.md) — how Flambda 2 fits into the compiler
- [Backends](../architecture/backends.md) — comparing the backends
- [Upstream docs](https://github.com/oxcaml/oxcaml/tree/main/middle_end/flambda2/docs) — the original Flambda 2 documentation
