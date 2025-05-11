# ASM.mbt

ASM.mbt is a small native-only x86-64 code emitter for MoonBit. It allocates an
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

  ctx.mov(@asm.rax, Imm32(18))
  ctx.add(@asm.rax, Imm32(4))
  ctx.sub(@asm.rax, Imm32(2))
  ctx.imul(@asm.rax, Imm32(3))
  ctx.ret()

  assert_eq(ctx.exec(), 60)
}
```

## Main Concepts

- `alloc` reserves writable/executable native memory for generated code.
- `ASMContext` owns the byte buffer and tracks the current offset.
- `Operand` currently supports 32-bit immediates and the legacy registers
  `rax`, `rbx`, `rcx`, `rdx`, `rsp`, `rbp`, `rsi`, and `rdi`.
- `Label` records a byte offset inside one context and can be used for local
  branches or calls.
- `Target` represents either a local label or an external symbol resolved from
  the current process.

## Supported Instructions

The public API currently emits these instructions:

- `mov(Reg, Reg)` and `mov(Reg, Imm32)`
- `add(rax, Imm32)` and `add(Reg, Reg)`
- `sub(rax, Imm32)` and `sub(Reg, Reg)`
- `xor(Reg, Reg)` and `xor(Reg, Imm32)`
- `mul(Reg)` and `imul(Reg, Imm32)` / `imul(Reg, Reg)`
- `inc(Reg)`, `dec(Reg)`, `push(Reg)`, and `pop(Reg)`
- `loop_rel8(Label)` for short RCX-counted loops
- `call(Target)`, `syscall`, `nop`, and `ret`

Unsupported operand combinations raise `ASMContextError` instead of aborting.

## Native Notes

This package targets `native` only and uses a C stub for `mmap`, `dlopen`,
`dlsym`, and execution. The generated code must follow the host ABI well enough
to return through `ret`; when calling C functions, preserve stack alignment and
callee/caller-saved registers as required by the platform.

On Linux, `linux_syscall_number("getpid")` and other names in the C stub's
syscall table expose the platform's `SYS_*` values, which can be loaded into
`rax` before emitting `syscall`.

The allocator currently requests RWX memory to keep the example simple. That is
convenient for experiments, but it is not the policy most production JITs use.
