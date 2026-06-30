///|
test "jit_context_zero_length_allocation_raises_context_error" {
  guard @test.expect_error(() => @asm.JITContext::new(mem_size=0UL))
    is ExecutableMemoryAllocationFailed(0UL, _) else {
    fail("expected ExecutableMemoryAllocationFailed")
  }
}

///|
test "finalize_rejects_code_larger_than_mapping" {
  let ctx = @asm.JITContext::new(mem_size=1UL)
  ctx.nop()
  ctx.ret()
  guard @test.expect_error(() => ignore(ctx.finalize_fn_i64()))
    is GeneratedCodeExceedsMemory(2UL, 1UL) else {
    fail("expected GeneratedCodeExceedsMemory")
  }
}
