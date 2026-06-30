///|
fn const_i64(
  value : Int,
) -> @asm.JITFunction[() -> Int64] raise @asm.ASMContextError {
  let ctx = @asm.JITContext::new()
  ctx.mov(@asm.reg(@asm.rax), @asm.imm32(value))
  ctx.ret()
  ctx.finalize_fn_i64()
}

///|
test "jit_function_call_runs_finalized_code" {
  let fn0 = const_i64(77)
  assert_eq(fn0.call(), 77)
}

///|
test "jit_function_func_ref_is_callable" {
  let fn0 = const_i64(91)
  let f : FuncRef[() -> Int64] = fn0.func_ref()
  assert_eq(f(), 91)
}

///|
test "jit_context_zero_length_allocation_raises_context_error" {
  guard @test.expect_error(() => @asm.JITContext::new(mem_size=0UL))
    is ExecutableMemoryAllocationFailed(0UL, _) else {
    fail("expected ExecutableMemoryAllocationFailed")
  }
}

///|
test "jit_context_rejects_code_larger_than_mapping" {
  let ctx = @asm.JITContext::new(mem_size=1UL)
  ctx.nop()
  ctx.ret()
  guard @test.expect_error(() => ignore(ctx.finalize_fn_i64()))
    is GeneratedCodeExceedsMemory(2UL, 1UL) else {
    fail("expected GeneratedCodeExceedsMemory")
  }
}

///|
test "jit_context_rejects_second_finalize" {
  let ctx = @asm.JITContext::new()
  ctx.mov(@asm.reg(@asm.rax), @asm.imm32(1))
  ctx.ret()
  ignore(ctx.finalize_fn_i64())
  guard @test.expect_error(() => ignore(ctx.finalize_fn_i64()))
    is JITContextAlreadyFinalized else {
    fail("expected JITContextAlreadyFinalized")
  }
}
