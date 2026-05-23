; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

@camlEmpty__gc_roots = global i64 0
@camlEmpty__data_begin = global i64 0
@camlEmpty__data_end = global i64 0
@camlEmpty__code_begin = global i64 0
@camlEmpty__code_end = global i64 0
@camlEmpty__frametable = global i64 0

define void @camlEmpty__entry() {
  ret void
}

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
