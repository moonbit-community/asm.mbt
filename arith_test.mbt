///|
test "arithmetic_immediates" {
  let start = @asm.alloc()
  let ctx = @asm.ASMContext::new(start~)
  // Emit code for ((18 + 4 - 2) * 3), leaving the result in RAX.
  ctx.mov(@asm.rax, Imm32(18))
  ctx.add(@asm.rax, Imm32(4))
  ctx.sub(@asm.rax, Imm32(2))
  ctx.imul(@asm.rax, Imm32(3))
  ctx.ret()
  assert_eq(ctx.exec(), 60)
}

///|
test "unsupported_operand_raises_context_error" {
  let start = @asm.alloc()
  let ctx = @asm.ASMContext::new(start~)
  let result : Result[Unit, @asm.ASMContextError] = try? ctx.add(
    Imm32(1),
    @asm.rax,
  )
  guard result is Err(UnsupportedAddOperands(Imm32(1), _)) else {
    fail("expected UnsupportedAddOperands")
  }
}

///|
test "bit_ops_and_stack" {
  let start = @asm.alloc()
  let ctx = @asm.ASMContext::new(start~)
  // Exercise xor, inc, dec, push, and pop by computing (0xF0 xor 0xFF) + 1.
  ctx.mov(@asm.rax, Imm32(0xF0))
  ctx.xor(@asm.rax, Imm32(0xFF))
  ctx.inc(@asm.rax)
  ctx.dec(@asm.rax)
  ctx.xor(@asm.rdx, @asm.rdx)
  ctx.inc(@asm.rdx)
  ctx.push(@asm.rax)
  ctx.pop(@asm.rbx)
  ctx.add(@asm.rbx, @asm.rdx)
  ctx.mov(@asm.rax, @asm.rbx)
  ctx.ret()
  assert_eq(ctx.exec(), 16)
}

///|
test "loop_rel8_jumps_to_instruction_start" {
  let start = @asm.alloc()
  let ctx = @asm.ASMContext::new(start~)
  ctx.mov(@asm.rcx, Imm32(2))
  ctx.mov(@asm.rax, Imm32(-100))
  // Loop twice over a 64-bit add and check the signed 64-bit result.
  let loop_start = ctx.label()
  ctx.add(@asm.rax, Imm32(1))
  ctx.loop_rel8(loop_start)
  ctx.ret()
  assert_eq(ctx.exec(), -98)
}

///|
fn factorial(ctx : @asm.ASMContext, n : Int) -> Unit raise @asm.ASMContextError {
  // Emit a loop that multiplies RAX by RCX while LOOP decrements RCX.
  ctx.mov(@asm.rcx, Imm32(n))
  ctx.mov(@asm.rax, Imm32(1))
  let l1 = ctx.label()
  ctx.mul(@asm.rcx)
  ctx.loop_rel8(l1)
  ctx.ret()
}

///|
test "factorial_loop" {
  let start = @asm.alloc()
  let ctx = @asm.ASMContext::new(start~)
  // Generate and run machine code for 5!, which should return 120 in RAX.
  factorial(ctx, 5)
  assert_eq(ctx.exec(), 120)
}
