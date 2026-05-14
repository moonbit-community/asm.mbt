///|
test "alloc_zero_length_raises_context_error" {
  let result : Result[UInt64, @asm.ASMContextError] = try? @asm.alloc(
    mem_size=0UL,
  )
  guard result is Err(ExecutableMemoryAllocationFailed(0UL, _)) else {
    fail("expected ExecutableMemoryAllocationFailed")
  }
}

///|
test "exec_rejects_code_larger_than_mapping" {
  let start = @asm.alloc(mem_size=1UL)
  let ctx = @asm.ASMContext::new(start~)
  ctx.nop()
  ctx.ret()
  let result : Result[Int64, @asm.ASMContextError] = try? ctx.exec()
  guard result is Err(GeneratedCodeExceedsMemory(2UL, 1UL)) else {
    fail("expected GeneratedCodeExceedsMemory")
  }
}
