///|
test "linux_syscall_getpid" {
  guard @asm.linux_syscall_number("getpid") is Some(getpid) else {
    fail("expected getpid syscall number on Linux")
  }
  let start = @asm.alloc()
  let ctx = @asm.ASMContext::new(start~)
  ctx.mov(@asm.reg(@asm.rax), @asm.imm32(getpid))
  ctx.syscall()
  ctx.ret()
  assert_true(ctx.exec() > Int64::from_int(0))
}

///|
test "unknown_linux_syscall_returns_none" {
  guard @asm.linux_syscall_number("__asm_mbt_not_a_syscall__") is None else {
    fail("expected unknown syscall to return None")
  }
}
