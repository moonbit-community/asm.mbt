///|
test "arithmetic_immediates" {
  let ctx = @asm.JITContext::new()
  // Emit code for ((18 + 4 - 2) * 3), leaving the result in RAX.
  ctx.mov(@asm.reg(@asm.rax), @asm.imm32(18))
  ctx.add(@asm.reg(@asm.rax), @asm.imm32(4))
  ctx.sub(@asm.reg(@asm.rax), @asm.imm32(2))
  ctx.imul(@asm.reg(@asm.rax), @asm.imm32(3))
  ctx.ret()
  assert_eq(ctx.finalize_fn_i64().call(), 60)
}

///|
test "unsupported_operand_raises_context_error" {
  let ctx = @asm.JITContext::new()
  guard @test.expect_error(() => ctx.add(@asm.imm32(1), @asm.reg(@asm.rax)))
    is UnsupportedAddOperands(Imm(Imm32(1)), _) else {
    fail("expected UnsupportedAddOperands")
  }
}

///|
test "bit_ops_and_stack" {
  let ctx = @asm.JITContext::new()
  // Exercise xor, inc, dec, push, and pop by computing (0xF0 xor 0xFF) + 1.
  ctx.mov(@asm.reg(@asm.rax), @asm.imm32(0xF0))
  ctx.xor(@asm.reg(@asm.rax), @asm.imm32(0xFF))
  ctx.inc(@asm.reg(@asm.rax))
  ctx.dec(@asm.reg(@asm.rax))
  ctx.xor(@asm.reg(@asm.rdx), @asm.reg(@asm.rdx))
  ctx.inc(@asm.reg(@asm.rdx))
  ctx.push(@asm.reg(@asm.rax))
  ctx.pop(@asm.reg(@asm.rcx))
  ctx.add(@asm.reg(@asm.rcx), @asm.reg(@asm.rdx))
  ctx.mov(@asm.reg(@asm.rax), @asm.reg(@asm.rcx))
  ctx.ret()
  assert_eq(ctx.finalize_fn_i64().call(), 16)
}

///|
test "loop_rel8_jumps_to_instruction_start" {
  let ctx = @asm.JITContext::new()
  ctx.mov(@asm.reg(@asm.rcx), @asm.imm32(2))
  ctx.mov(@asm.reg(@asm.rax), @asm.imm32(-100))
  // Loop twice over a 64-bit add and check the signed 64-bit result.
  let loop_start = ctx.label()
  ctx.add(@asm.reg(@asm.rax), @asm.imm32(1))
  ctx.loop_rel8(loop_start)
  ctx.ret()
  assert_eq(ctx.finalize_fn_i64().call(), -98)
}

///|
fn factorial(ctx : @asm.JITContext, n : Int) -> Unit raise @asm.ASMContextError {
  // Emit a loop that multiplies RAX by RCX while LOOP decrements RCX.
  ctx.mov(@asm.reg(@asm.rcx), @asm.imm32(n.to_int64()))
  ctx.mov(@asm.reg(@asm.rax), @asm.imm32(1))
  let l1 = ctx.label()
  ctx.mul(@asm.reg(@asm.rcx))
  ctx.loop_rel8(l1)
  ctx.ret()
}

///|
test "factorial_loop" {
  let ctx = @asm.JITContext::new()
  // Generate and run machine code for 5!, which should return 120 in RAX.
  factorial(ctx, 5)
  assert_eq(ctx.finalize_fn_i64().call(), 120)
}
