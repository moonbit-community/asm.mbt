///|
test "alloc_zero_length_raises_context_error" {
  guard @test.expect_error(() => @asm.alloc(mem_size=0UL))
    is ExecutableMemoryAllocationFailed(0UL, _) else {
    fail("expected ExecutableMemoryAllocationFailed")
  }
}

///|
test "exec_rejects_code_larger_than_mapping" {
  let start = @asm.alloc(mem_size=1UL)
  let ctx = @asm.ASMContext::new(start~)
  ctx.nop()
  ctx.ret()
  guard @test.expect_error(() => ctx.exec())
    is GeneratedCodeExceedsMemory(2UL, 1UL) else {
    fail("expected GeneratedCodeExceedsMemory")
  }
}
