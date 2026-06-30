# ASM.mbt

ASM.mbt is a small native-only x86-64 dynamic code emitter for MoonBit. A
`JITContext` owns a writable memory buffer while it appends machine-code bytes,
then finalizes the buffer into a callable `JITFunction[() -> Int64]`.

The project is intentionally minimal. It is useful for experiments, tests, and
learning how instruction encodings fit together; it is not a complete assembler.

## Quick Example

```mbt check
///|
test {
  let ctx = @asm.JITContext::new()

  ctx.mov(@asm.reg(@asm.rax), @asm.imm32(18))
  ctx.add(@asm.reg(@asm.rax), @asm.imm32(4))
  ctx.sub(@asm.reg(@asm.rax), @asm.imm32(2))
  ctx.imul(@asm.reg(@asm.rax), @asm.imm32(3))
  ctx.ret()

  let fn0 = ctx.finalize_fn_i64()
  assert_eq(fn0.call(), 60)
}
```

## Operand Construction

Register constants are `Register` values. Wrap them with `reg(...)` when
passing them to instruction helpers, and use explicit immediate or memory
helpers for the other operand kinds:

```mbt check
///|
test {
  let ctx = @asm.JITContext::new()

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
- `mul` and two-operand `imul` for integer register/memory or immediate forms
- `inc`, `dec`, `push`, and `pop` for legal integer register/memory forms
- `loop_rel8(Label)` for short RCX-counted loops
- `call(Target)`, `syscall`, `nop`, and `ret`

Unsupported operand combinations raise `ASMContextError` instead of aborting.

## Labels, Calls, and Tracing

Labels capture the current byte offset in a single `JITContext`. Convert a label
to a call target with `Label::target`. External call targets can be built with
`JITContext::extern_fn(name)`, which resolves a symbol in the current process and
stores the relative target used by x86-64 `CALL rel32`.

```mbt check
///|
test {
  let ctx = @asm.JITContext::new()

  let target = ctx.label()
  ctx.call(target.target())

  assert_eq(ctx.bytes().length(), 5)
}
```

`trace()` returns a copy of the successfully emitted opcode-form trace. The trace
uses the public `Instr` enum, whose constructors name the concrete opcode form
chosen by the encoder.

```mbt check
///|
test {
  let ctx = @asm.JITContext::new()

  ctx.nop()
  ctx.ret()

  let trace = ctx.trace()
  let expected : Array[@asm.Instr] = [NopOp90, RetNearOpC3]
  assert_true(trace == expected)

  trace.push(SyscallOp0F05)
  assert_true(ctx.trace() == expected)
}
```

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

## Errors and Validation

Most instruction helpers validate the requested form before appending bytes or
trace entries. `ASMContextError` variants cover unsupported instruction forms,
operand-width mismatches, out-of-range immediates, invalid memory addressing,
high-8 register conflicts with REX, short-loop displacement overflow, allocation
failure, `mprotect` failure, generated code that exceeds the executable
allocation, and repeated finalization.

`call` currently emits directly and does not raise an error for an out-of-range
`rel32` displacement. Keep in-buffer labels and external call targets close
enough for x86-64 relative calls until range validation is implemented.

## Native Notes

This package targets `native` only and uses a C stub for `mmap`, `dlopen`,
`dlsym`, and execution. The generated code must follow the host ABI well enough
to return through `ret`; when calling C functions, preserve stack alignment and
callee/caller-saved registers as required by the platform.

`JITContext::new` raises `ASMContextError` when executable memory allocation
fails. `finalize_fn_i64` raises before copying if the generated code exceeds the
mapping size, then switches the mapping from writable to executable memory.

On Linux, `linux_syscall_number("getpid")` and other names in the C stub's
syscall table expose the platform's `SYS_*` values, which can be loaded into
`rax` before emitting `syscall`.

`JITFunction::func_ref()` returns the finalized code as the typed `FuncRef`
stored by the `JITFunction`. For `JITFunction[() -> Int64]`,
`JITFunction::call()` is a convenience wrapper over that function reference.

## Known Limitations

- `imm32`, normal memory displacements, RIP-relative displacements, and
  `call rel32` are written as 4-byte fields. Very large `Int` values are not all
  checked before emission yet, so keep them within the intended 32-bit range.
- `JITContext::extern_fn` does not currently report `dlopen` or `dlsym` failure.
  A missing symbol can still produce a `Target`, so use known process symbols
  and avoid treating it as a general-purpose dynamic linker API.
- Finalized mappings are intentionally not manually freed in v1, so any returned
  `FuncRef` cannot dangle because of an explicit dispose call.
- The width-specific memory helpers use internal high-8 register sentinels for
  omitted `base` and `index` arguments. Do not pass `ah` as a memory base or
  `ch` as an index; use the generic `mem(size=..., base=..., index=...)` helper
  when you need explicit optional registers.
