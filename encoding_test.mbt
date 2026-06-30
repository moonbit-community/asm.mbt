///|
fn assert_emitted(ctx : @asm.JITContext, expected : Array[Byte]) -> Unit raise {
  assert_eq(ctx.bytes(), Bytes::from_array(expected))
}

///|
fn byte_context() -> @asm.JITContext raise @asm.ASMContextError {
  @asm.JITContext::new()
}

///|
test "rex_extended_registers_and_imm64_execute" {
  let ctx = @asm.JITContext::new()
  ctx.mov(@asm.reg(@asm.r8), @asm.imm64(42L))
  ctx.mov(@asm.reg(@asm.rax), @asm.reg(@asm.r8))
  ctx.ret()
  assert_eq(ctx.finalize_fn_i64().call(), 42)
}

///|
test "stack_memory_roundtrip_executes" {
  let ctx = @asm.JITContext::new()
  ctx.mov(@asm.reg(@asm.rax), @asm.imm32(123))
  ctx.push(@asm.reg(@asm.rax))
  ctx.mov(@asm.reg(@asm.rdx), @asm.mem64(base=@asm.rsp))
  ctx.pop(@asm.reg(@asm.rcx))
  ctx.mov(@asm.reg(@asm.rax), @asm.reg(@asm.rdx))
  ctx.ret()
  assert_eq(ctx.finalize_fn_i64().call(), 123)
}

///|
test "mov_register_width_bytes" {
  let ctx16 = byte_context()
  ctx16.mov(@asm.reg(@asm.ax), @asm.reg(@asm.cx))
  assert_emitted(ctx16, [0x66, 0x89, 0xC8])

  let ctx32 = byte_context()
  ctx32.mov(@asm.reg(@asm.eax), @asm.reg(@asm.ecx))
  assert_emitted(ctx32, [0x89, 0xC8])

  let ctx64 = byte_context()
  ctx64.mov(@asm.reg(@asm.rax), @asm.reg(@asm.rcx))
  assert_emitted(ctx64, [0x48, 0x89, 0xC8])
}

///|
test "byte_register_rex_and_high8_bytes" {
  let high8 = byte_context()
  high8.mov(@asm.reg(@asm.ah), @asm.reg(@asm.bl))
  assert_emitted(high8, [0x88, 0xDC])

  let low8_rex = byte_context()
  low8_rex.mov(@asm.reg(@asm.spl), @asm.reg(@asm.al))
  assert_emitted(low8_rex, [0x40, 0x88, 0xC4])
}

///|
test "memory_addressing_special_case_bytes" {
  let rbp = byte_context()
  rbp.mov(@asm.reg(@asm.rax), @asm.mem64(base=@asm.rbp))
  assert_emitted(rbp, [0x48, 0x8B, 0x45, 0x00])

  let r13 = byte_context()
  r13.mov(@asm.reg(@asm.rax), @asm.mem64(base=@asm.r13))
  assert_emitted(r13, [0x49, 0x8B, 0x45, 0x00])

  let rsp = byte_context()
  rsp.mov(@asm.reg(@asm.rax), @asm.mem64(base=@asm.rsp))
  assert_emitted(rsp, [0x48, 0x8B, 0x04, 0x24])

  let r12 = byte_context()
  r12.mov(@asm.reg(@asm.rax), @asm.mem64(base=@asm.r12))
  assert_emitted(r12, [0x49, 0x8B, 0x04, 0x24])
}

///|
test "sib_index_r12_and_rip_relative_bytes" {
  let sib = byte_context()
  sib.mov(
    @asm.reg(@asm.rax),
    @asm.mem64(base=@asm.rax, index=@asm.r12, scale=4, disp=8),
  )
  assert_emitted(sib, [0x4A, 0x8B, 0x44, 0xA0, 0x08])

  let rip = byte_context()
  rip.mov(@asm.reg(@asm.rax), @asm.rip64(0x12345678))
  assert_emitted(rip, [0x48, 0x8B, 0x05, 0x78, 0x56, 0x34, 0x12])
}

///|
test "imul_reg_reg_uses_standard_two_operand_opcode" {
  let ctx = byte_context()
  ctx.imul(@asm.reg(@asm.rax), @asm.reg(@asm.rcx))
  assert_emitted(ctx, [0x48, 0x0F, 0xAF, 0xC1])
}

///|
test "invalid_high8_rex_conflict" {
  let ctx = byte_context()
  guard @test.expect_error(() => ctx.mov(@asm.reg(@asm.ah), @asm.reg(@asm.r8b)))
    is High8RexConflict else {
    fail("expected High8RexConflict")
  }
}

///|
test "invalid_rsp_index" {
  let ctx = byte_context()
  guard @test.expect_error(() => {
      ctx.mov(@asm.reg(@asm.rax), @asm.mem64(index=@asm.rsp))
    })
    is MemoryIndexCannotBeStackPointer(_) else {
    fail("expected MemoryIndexCannotBeStackPointer")
  }
}

///|
test "invalid_immediate_range" {
  let ctx = byte_context()
  guard @test.expect_error(() => ctx.mov(@asm.reg(@asm.al), @asm.imm8(300)))
    is ImmediateOutOfRange(Imm8(300)) else {
    fail("expected ImmediateOutOfRange")
  }
}

///|
test "invalid_memory_width_mismatch" {
  let ctx = byte_context()
  guard @test.expect_error(() => {
      ctx.mov(@asm.reg(@asm.rax), @asm.mem32(base=@asm.rax))
    })
    is OperandWidthMismatch(W64, W32) else {
    fail("expected OperandWidthMismatch")
  }
}
