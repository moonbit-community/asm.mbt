///|
fn trace_context() -> @asm.ASMContext {
  @asm.ASMContext::new(start=0UL)
}

///|
fn expect_failed_emit_preserved(
  ctx : @asm.ASMContext,
  before_bytes : Bytes,
  before_trace : Array[@asm.Instr],
  emit : () -> Unit raise @asm.ASMContextError,
) -> @asm.ASMContextError raise {
  let error = @test.expect_error(emit)
  assert_eq(ctx.bytes(), before_bytes)
  assert_true(ctx.trace() == before_trace)
  error
}

///|
test "trace_records_opcode_forms" {
  let ctx = trace_context()
  ctx.mov(@asm.reg(@asm.rax), @asm.reg(@asm.rcx))
  ctx.mov(@asm.reg(@asm.rdx), @asm.mem64(base=@asm.rax))
  ctx.mov(@asm.reg(@asm.r8), @asm.imm64(42L))
  ctx.mov(@asm.reg(@asm.rax), @asm.imm32(7))
  ctx.add(@asm.reg(@asm.rax), @asm.imm8(1))
  ctx.imul(@asm.reg(@asm.rax), @asm.reg(@asm.rcx))
  ctx.imul(@asm.reg(@asm.rdx), @asm.imm8(3))
  let expected : Array[@asm.Instr] = [
    MovRmRegOp89(@asm.reg(@asm.rax), @asm.rcx),
    MovRegRmOp8B(@asm.rdx, @asm.mem64(base=@asm.rax)),
    MovRegImmOpB8(@asm.r8, Imm64(42L)),
    MovRmImmOpC7Ext0(@asm.reg(@asm.rax), Imm32(7)),
    AddRmImm8SignExtOp83Ext0(@asm.reg(@asm.rax), Imm8(1)),
    IMulRegRmOp0FAF(@asm.rax, @asm.reg(@asm.rcx)),
    IMulRegRmImm8Op6B(@asm.rdx, @asm.reg(@asm.rdx), Imm8(3)),
  ]
  assert_true(ctx.trace() == expected)
}

///|
test "trace_records_more_opcode_forms" {
  let ctx = trace_context()
  ctx.sub(@asm.reg(@asm.rax), @asm.reg(@asm.rcx))
  ctx.sub(@asm.reg(@asm.rdx), @asm.mem64(base=@asm.rax))
  ctx.sub(@asm.reg(@asm.rax), @asm.imm32(7))
  ctx.xor(@asm.mem8(base=@asm.rax), @asm.reg(@asm.cl))
  ctx.xor(@asm.reg(@asm.al), @asm.mem8(base=@asm.rax))
  ctx.xor(@asm.reg(@asm.rax), @asm.imm8(1))
  ctx.mul(@asm.reg(@asm.al))
  ctx.mul(@asm.mem64(base=@asm.rax))
  ctx.inc(@asm.reg(@asm.al))
  ctx.inc(@asm.mem64(base=@asm.rax))
  ctx.dec(@asm.reg(@asm.al))
  ctx.dec(@asm.mem64(base=@asm.rax))
  ctx.push(@asm.reg(@asm.rax))
  ctx.push(@asm.mem64(base=@asm.rax))
  ctx.push(@asm.imm8(1))
  ctx.push(@asm.imm32(2))
  ctx.pop(@asm.reg(@asm.rax))
  ctx.pop(@asm.mem64(base=@asm.rax))
  ctx.syscall()
  ctx.ret()
  let expected : Array[@asm.Instr] = [
    SubRmRegOp29(@asm.reg(@asm.rax), @asm.rcx),
    SubRegRmOp2B(@asm.rdx, @asm.mem64(base=@asm.rax)),
    SubRmImmOp81Ext5(@asm.reg(@asm.rax), Imm32(7)),
    XorRm8Reg8Op30(@asm.mem8(base=@asm.rax), @asm.cl),
    XorReg8Rm8Op32(@asm.al, @asm.mem8(base=@asm.rax)),
    XorRmImm8SignExtOp83Ext6(@asm.reg(@asm.rax), Imm8(1)),
    MulRm8OpF6Ext4(@asm.reg(@asm.al)),
    MulRmOpF7Ext4(@asm.mem64(base=@asm.rax)),
    IncRm8OpFEExt0(@asm.reg(@asm.al)),
    IncRmOpFFExt0(@asm.mem64(base=@asm.rax)),
    DecRm8OpFEExt1(@asm.reg(@asm.al)),
    DecRmOpFFExt1(@asm.mem64(base=@asm.rax)),
    PushRegOp50(@asm.rax),
    PushRmOpFFExt6(@asm.mem64(base=@asm.rax)),
    PushImm8Op6A(Imm8(1)),
    PushImmOp68(Imm32(2)),
    PopRegOp58(@asm.rax),
    PopRmOp8FExt0(@asm.mem64(base=@asm.rax)),
    SyscallOp0F05,
    RetNearOpC3,
  ]
  assert_true(ctx.trace() == expected)
}

///|
test "trace_records_control_flow_displacements" {
  let ctx = trace_context()
  ctx.nop()
  let call_target = ctx.label()
  ctx.call(call_target.target())
  let loop_target = ctx.label()
  ctx.nop()
  ctx.loop_rel8(loop_target)
  let expected : Array[@asm.Instr] = [
    NopOp90,
    CallRel32OpE8(call_target.target(), -5),
    NopOp90,
    LoopRcxRel8OpE2(loop_target, -3),
  ]
  assert_true(ctx.trace() == expected)
}

///|
test "trace_accessor_returns_copy" {
  let ctx = trace_context()
  ctx.nop()
  let trace = ctx.trace()
  trace.push(RetNearOpC3)
  let expected_context_trace : Array[@asm.Instr] = [NopOp90]
  let expected_mutated_copy : Array[@asm.Instr] = [NopOp90, RetNearOpC3]
  assert_true(ctx.trace() == expected_context_trace)
  assert_true(trace == expected_mutated_copy)
}

///|
test "unsupported_helper_failures_preserve_bytes_and_trace" {
  let sub_ctx = trace_context()
  sub_ctx.nop()
  let before_bytes = sub_ctx.bytes()
  let before_trace = sub_ctx.trace()
  let sub_error = expect_failed_emit_preserved(
    sub_ctx,
    before_bytes,
    before_trace,
    () => sub_ctx.sub(@asm.imm32(1), @asm.reg(@asm.rax)),
  )
  guard sub_error is UnsupportedSubOperands(_, _) else {
    fail("expected UnsupportedSubOperands")
  }

  let xor_ctx = trace_context()
  xor_ctx.nop()
  let before_bytes = xor_ctx.bytes()
  let before_trace = xor_ctx.trace()
  let xor_error = expect_failed_emit_preserved(
    xor_ctx,
    before_bytes,
    before_trace,
    () => xor_ctx.xor(@asm.imm32(1), @asm.reg(@asm.rax)),
  )
  guard xor_error is UnsupportedXorOperands(_, _) else {
    fail("expected UnsupportedXorOperands")
  }

  let mul_ctx = trace_context()
  mul_ctx.nop()
  let before_bytes = mul_ctx.bytes()
  let before_trace = mul_ctx.trace()
  let mul_error = expect_failed_emit_preserved(
    mul_ctx,
    before_bytes,
    before_trace,
    () => mul_ctx.mul(@asm.imm32(1)),
  )
  guard mul_error is UnsupportedMulOperand(_) else {
    fail("expected UnsupportedMulOperand")
  }

  let imul_ctx = trace_context()
  imul_ctx.nop()
  let before_bytes = imul_ctx.bytes()
  let before_trace = imul_ctx.trace()
  let imul_error = expect_failed_emit_preserved(
    imul_ctx,
    before_bytes,
    before_trace,
    () => imul_ctx.imul(@asm.mem64(base=@asm.rax), @asm.reg(@asm.rcx)),
  )
  guard imul_error is UnsupportedIMulOperands(_, _) else {
    fail("expected UnsupportedIMulOperands")
  }

  let mov_ctx = trace_context()
  mov_ctx.nop()
  let before_bytes = mov_ctx.bytes()
  let before_trace = mov_ctx.trace()
  let mov_error = expect_failed_emit_preserved(
    mov_ctx,
    before_bytes,
    before_trace,
    () => mov_ctx.mov(@asm.imm32(1), @asm.reg(@asm.rax)),
  )
  guard mov_error is UnsupportedMovOperands(_, _) else {
    fail("expected UnsupportedMovOperands")
  }

  let push_ctx = trace_context()
  push_ctx.nop()
  let before_bytes = push_ctx.bytes()
  let before_trace = push_ctx.trace()
  let push_error = expect_failed_emit_preserved(
    push_ctx,
    before_bytes,
    before_trace,
    () => push_ctx.push(@asm.reg(@asm.eax)),
  )
  guard push_error is UnsupportedPushOperand(_) else {
    fail("expected UnsupportedPushOperand")
  }

  let pop_ctx = trace_context()
  pop_ctx.nop()
  let before_bytes = pop_ctx.bytes()
  let before_trace = pop_ctx.trace()
  let pop_error = expect_failed_emit_preserved(
    pop_ctx,
    before_bytes,
    before_trace,
    () => pop_ctx.pop(@asm.reg(@asm.eax)),
  )
  guard pop_error is UnsupportedPopOperand(_) else {
    fail("expected UnsupportedPopOperand")
  }
}

///|
test "validation_failures_preserve_bytes_and_trace" {
  let width_ctx = trace_context()
  width_ctx.nop()
  let before_bytes = width_ctx.bytes()
  let before_trace = width_ctx.trace()
  let width_error = expect_failed_emit_preserved(
    width_ctx,
    before_bytes,
    before_trace,
    () => width_ctx.add(@asm.reg(@asm.rax), @asm.reg(@asm.ecx)),
  )
  guard width_error is OperandWidthMismatch(W64, W32) else {
    fail("expected OperandWidthMismatch")
  }

  let scale_ctx = trace_context()
  scale_ctx.nop()
  let before_bytes = scale_ctx.bytes()
  let before_trace = scale_ctx.trace()
  let scale_error = expect_failed_emit_preserved(
    scale_ctx,
    before_bytes,
    before_trace,
    () => scale_ctx.mov(@asm.reg(@asm.rax), @asm.mem64(base=@asm.rax, scale=3)),
  )
  guard scale_error is InvalidMemoryScale(3) else {
    fail("expected InvalidMemoryScale")
  }

  let base_ctx = trace_context()
  base_ctx.nop()
  let before_bytes = base_ctx.bytes()
  let before_trace = base_ctx.trace()
  let base_error = expect_failed_emit_preserved(
    base_ctx,
    before_bytes,
    before_trace,
    () => base_ctx.mov(@asm.reg(@asm.rax), @asm.mem64(base=@asm.eax)),
  )
  guard base_error is InvalidMemoryBase(_) else {
    fail("expected InvalidMemoryBase")
  }

  let index_ctx = trace_context()
  index_ctx.nop()
  let before_bytes = index_ctx.bytes()
  let before_trace = index_ctx.trace()
  let index_error = expect_failed_emit_preserved(
    index_ctx,
    before_bytes,
    before_trace,
    () => index_ctx.mov(@asm.reg(@asm.rax), @asm.mem64(index=@asm.eax)),
  )
  guard index_error is InvalidMemoryIndex(_) else {
    fail("expected InvalidMemoryIndex")
  }

  let unsupported_width_ctx = trace_context()
  unsupported_width_ctx.nop()
  let before_bytes = unsupported_width_ctx.bytes()
  let before_trace = unsupported_width_ctx.trace()
  let unsupported_width_error = expect_failed_emit_preserved(
    unsupported_width_ctx,
    before_bytes,
    before_trace,
    () => unsupported_width_ctx.push(@asm.imm64(1L)),
  )
  guard unsupported_width_error is UnsupportedOperandWidth(Imm(Imm64(1L))) else {
    fail("expected UnsupportedOperandWidth")
  }
}

///|
test "failed_emits_preserve_bytes_and_trace" {
  let unsupported = trace_context()
  unsupported.nop()
  let before_bytes = unsupported.bytes()
  let before_trace = unsupported.trace()
  let unsupported_error = expect_failed_emit_preserved(
    unsupported,
    before_bytes,
    before_trace,
    () => unsupported.add(@asm.imm32(1), @asm.reg(@asm.rax)),
  )
  guard unsupported_error is UnsupportedAddOperands(_, _) else {
    fail("expected UnsupportedAddOperands")
  }

  let high8 = trace_context()
  high8.nop()
  let before_bytes = high8.bytes()
  let before_trace = high8.trace()
  let high8_error = expect_failed_emit_preserved(
    high8,
    before_bytes,
    before_trace,
    () => high8.mov(@asm.reg(@asm.ah), @asm.reg(@asm.r8b)),
  )
  guard high8_error is High8RexConflict else {
    fail("expected High8RexConflict")
  }

  let loop_ctx = trace_context()
  let loop_target = loop_ctx.label()
  for _ in 0..<130 {
    loop_ctx.nop()
  }
  let before_bytes = loop_ctx.bytes()
  let before_trace = loop_ctx.trace()
  let loop_error = expect_failed_emit_preserved(
    loop_ctx,
    before_bytes,
    before_trace,
    () => loop_ctx.loop_rel8(loop_target),
  )
  guard loop_error is LoopRel8OutOfRange(_) else {
    fail("expected LoopRel8OutOfRange")
  }

  let immediate = trace_context()
  immediate.nop()
  let before_bytes = immediate.bytes()
  let before_trace = immediate.trace()
  let immediate_error = expect_failed_emit_preserved(
    immediate,
    before_bytes,
    before_trace,
    () => immediate.mov(@asm.reg(@asm.al), @asm.imm8(300)),
  )
  guard immediate_error is ImmediateOutOfRange(Imm8(300)) else {
    fail("expected ImmediateOutOfRange")
  }

  let memory = trace_context()
  memory.nop()
  let before_bytes = memory.bytes()
  let before_trace = memory.trace()
  let memory_error = expect_failed_emit_preserved(
    memory,
    before_bytes,
    before_trace,
    () => memory.mov(@asm.reg(@asm.rax), @asm.mem64(index=@asm.rsp)),
  )
  guard memory_error is MemoryIndexCannotBeStackPointer(_) else {
    fail("expected MemoryIndexCannotBeStackPointer")
  }
}
