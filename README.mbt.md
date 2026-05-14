# ASM.mbt

ASM.mbt is a small native-only x86-64 dynamic code emitter for MoonBit. It allocates an
executable memory buffer, appends machine-code bytes through a compact API, and
calls the generated buffer as a function returning `Int64`.

The project is intentionally minimal. It is useful for experiments, tests, and
learning how instruction encodings fit together; it is not a complete assembler.

## Quick Example

```mbt check
///|
test {
  let start = @asm.alloc()
  let ctx = @asm.ASMContext::new(start~)

  ctx.mov(@asm.reg(@asm.rax), @asm.imm32(18))
  ctx.add(@asm.reg(@asm.rax), @asm.imm32(4))
  ctx.sub(@asm.reg(@asm.rax), @asm.imm32(2))
  ctx.imul(@asm.reg(@asm.rax), @asm.imm32(3))
  ctx.ret()

  assert_eq(ctx.exec(), 60)
}
```

## Operand Construction

Register constants are `Register` values. Wrap them with `reg(...)` when
passing them to instruction helpers, and use explicit immediate or memory
helpers for the other operand kinds:

```mbt check
///|
test {
  let start = @asm.alloc()
  let ctx = @asm.ASMContext::new(start~)

  ctx.mov(@asm.reg(@asm.r8), @asm.imm64(42L))
  ctx.mov(@asm.mem64(base=@asm.rsp, disp=8), @asm.reg(@asm.r8))
  ctx.mov(@asm.reg(@asm.rax), @asm.mem64(base=@asm.rsp, disp=8))
  ctx.ret()
}
```

Memory operands always carry a data width: `mem8`, `mem16`, `mem32`, `mem64`,
or the generic `mem(size=...)`. Addressing is the 64-bit ModR/M + SIB form:
optional base, optional index, scale `1/2/4/8`, signed displacement, optional
`FS`/`GS`, and dedicated RIP-relative helpers such as `rip64(disp)`.

## Supported Instructions

The public API currently emits these instructions:

- `mov` for register, memory, and immediate integer forms
- `add`, `sub`, and `xor` for register/memory with register or immediate forms
- `mul` and two-operand `imul` for integer register/memory forms
- `inc`, `dec`, `push`, and `pop` for legal integer register/memory forms
- `loop_rel8(Label)` for short RCX-counted loops
- `call(Target)`, `syscall`, `nop`, and `ret`

Unsupported operand combinations raise `ASMContextError` instead of aborting.

## Encoding Notes

- 16-bit operands emit the `0x66` operand-size override.
- 64-bit operands and extended registers emit REX prefixes as needed.
- `spl`, `bpl`, `sil`, and `dil` force a bare REX prefix; `ah`, `ch`, `dh`, and
  `bh` cannot be used in any instruction that needs REX.
- `rsp` and `r12` as a memory base always require SIB. `rbp` and `r13` without a
  displacement are encoded with `disp8 = 0`.
- `rsp` cannot be a SIB index. `r12` can be an index because REX.X distinguishes
  it from `rsp`.
- RIP-relative memory always uses a signed disp32 field.

## Native Notes

This package targets `native` only and uses a C stub for `mmap`, `dlopen`,
`dlsym`, and execution. The generated code must follow the host ABI well enough
to return through `ret`; when calling C functions, preserve stack alignment and
callee/caller-saved registers as required by the platform.

`alloc` raises `ASMContextError` when executable memory allocation fails.
`ASMContext::new` records the allocation size for buffers returned by `alloc`,
and `exec` raises before copying if the generated code exceeds that size.

On Linux, `linux_syscall_number("getpid")` and other names in the C stub's
syscall table expose the platform's `SYS_*` values, which can be loaded into
`rax` before emitting `syscall`.

The allocator currently requests RWX memory to keep the example simple. That is
convenient for experiments, but it is not the policy most production JITs use.
