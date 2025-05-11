///|
test "extern_call_libc_abs" {
  let start = @asm.alloc()
  let ctx = @asm.ASMContext::new(start~)
  let libc_abs = ctx.extern_fn("abs")
  // Call libc abs(-42), then add 8 to prove the return value is in RAX.
  // The push/pop pair keeps the stack aligned for the nested C ABI call.
  ctx.push(@asm.rdx)
  ctx.mov(@asm.rdi, Imm32(-42))
  ctx.call(libc_abs)
  ctx.pop(@asm.rdx)
  ctx.add(@asm.rax, Imm32(8))
  ctx.ret()
  assert_eq(ctx.exec(), 50)
}
