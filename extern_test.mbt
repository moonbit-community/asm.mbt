///|
test "extern_call_libc_abs" {
  let ctx = @asm.JITContext::new()
  let libc_abs = ctx.extern_fn("abs")
  // Call libc abs(-42), then add 8 to prove the return value is in RAX.
  // The push/pop pair keeps the stack aligned for the nested C ABI call.
  ctx.push(@asm.reg(@asm.rdx))
  ctx.mov(@asm.reg(@asm.rdi), @asm.imm32(-42))
  ctx.call(libc_abs)
  ctx.pop(@asm.reg(@asm.rdx))
  ctx.add(@asm.reg(@asm.rax), @asm.imm32(8))
  ctx.ret()
  assert_eq(ctx.finalize_fn_i64().call(), 50)
}

///|
test "missing_extern_symbol_raises_context_error" {
  let ctx = @asm.JITContext::new()
  let name = "__asm_mbt_missing_symbol_for_test__"
  guard @test.expect_error(() => ignore(ctx.extern_fn(name)))
    is ExternalSymbolResolutionFailed("__asm_mbt_missing_symbol_for_test__") else {
    fail("expected ExternalSymbolResolutionFailed")
  }
}
