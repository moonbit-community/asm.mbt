///|
/// Mutable builder for one x86-64 machine-code buffer.
///
/// An `ASMContext` appends encoded bytes to an internal buffer and tracks the
/// byte offset used by labels and relative jumps. The caller provides the
/// executable memory start address, usually from `alloc`.
struct ASMContext {
  // Logical instruction trace retained for debugging and future diagnostics.
  instrs : Array[Instr]
  // Encoded machine-code bytes waiting to be copied into executable memory.
  code : @buffer.Buffer
  // Start address of the executable memory region.
  mem_ptr : UInt64
  // Current byte offset from `mem_ptr`.
  mut mem_offset : Int
}

///|
/// Errors raised when an instruction helper cannot encode the requested form.
///
/// Each instruction method documents the operand forms it currently supports.
/// Unsupported forms raise a structured error instead of aborting the process.
pub(all) suberror ASMContextError {
  // `add` supports RAX + imm32 and register-to-register forms.
  UnsupportedAddOperands(Operand, Operand)
  // `sub` supports RAX - imm32 and register-to-register forms.
  UnsupportedSubOperands(Operand, Operand)
  // `xor` supports register-to-register and register-with-imm32 forms.
  UnsupportedXorOperands(Operand, Operand)
  // `mul` currently supports register operands only.
  UnsupportedMulOperand(Operand)
  // `inc` currently supports register operands only.
  UnsupportedIncOperand(Operand)
  // `dec` currently supports register operands only.
  UnsupportedDecOperand(Operand)
  // LOOP uses a signed 8-bit displacement, so distant labels are rejected.
  LoopRel8OutOfRange(Int)
  // `imul` supports register-with-imm32 and register-to-register forms.
  UnsupportedIMulOperands(Operand, Operand)
  // `mov` supports register-to-register and register-from-imm32 forms.
  UnsupportedMovOperands(Operand, Operand)
  // `push` currently supports register operands only.
  UnsupportedPushOperand(Operand)
  // `pop` currently supports register operands only.
  UnsupportedPopOperand(Operand)
} derive(Debug)

///|
/// Create a new code-generation context for an executable memory region.
pub fn ASMContext::new(start~ : UInt64) -> ASMContext {
  ASMContext::{
    instrs: [],
    code: @buffer.new(size_hint=25),
    mem_ptr: start,
    mem_offset: 0,
  }
}

///|
/// Capture the current byte offset as a label.
///
/// Use this before emitting a backward branch or as a local call target.
pub fn ASMContext::label(self : ASMContext) -> Label {
  Label::{ offset: self.mem_offset }
}

///|
/// Resolve a symbol in the current process for use with `call`.
///
/// The returned target stores an offset relative to this context's code buffer,
/// matching x86-64 CALL rel32 encoding.
pub fn ASMContext::extern_fn(self : ASMContext, name : String) -> Target {
  let handle = dlopen()
  let fn_pointer = dlsym(handle, name)
  let rel = if fn_pointer > self.mem_ptr {
    (fn_pointer - self.mem_ptr).to_int()
  } else {
    -(self.mem_ptr - fn_pointer).to_int()
  }
  Extern(rel)
}

///|
/// Append a single byte and advance the current code offset.
fn ASMContext::emit_byte(self : ASMContext, i : Byte) -> Unit {
  self.code.write_byte(i)
  self.mem_offset += 1
}

///|
/// Append a little-endian 32-bit immediate and advance the code offset.
fn ASMContext::emit_imm32(self : ASMContext, i : Int) -> Unit {
  self.code.write_int_le(i)
  self.mem_offset += 4
}

///|
/// Copy the generated code into executable memory and call it as `fn() -> Int64`.
///
/// The generated function is expected to follow the platform ABI enough to
/// return its result in RAX and preserve any registers required by its caller.
pub fn ASMContext::exec(self : ASMContext) -> Int64 {
  let machcode = self.code.contents()
  __exec(self.mem_ptr, machcode, machcode.length().to_uint64())
}

///|
/// Emit a one-byte NOP instruction.
pub fn ASMContext::nop(self : ASMContext) -> Unit {
  self.instrs.push(Nop)
  self.emit_byte(0x90)
}

///|
/// Emit a RET instruction.
pub fn ASMContext::ret(self : ASMContext) -> Unit {
  self.instrs.push(Ret)
  self.emit_byte(0xC3)
}

///|
/// Emit ADD.
///
/// Supported forms are `add(rax, Imm32(_))` and `add(Reg(_), Reg(_))`.
pub fn ASMContext::add(
  self : ASMContext,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Add(lhs, rhs))
  match (lhs, rhs) {
    (Reg(RAX), Imm32(r)) => {
      // REX.W selects the 64-bit accumulator form: 48 05 id.
      self.emit_byte(0x48)
      self.emit_byte(0x05)
      self.emit_imm32(r)
    }
    (Reg(l), Reg(r)) => {
      // ModR/M uses mod=11 for register-direct operands.
      self.emit_byte(0x48)
      self.emit_byte(0x01)
      self.emit_byte((0xC0 : Byte) | (r.index() << 3) | l.index())
    }
    _ => raise UnsupportedAddOperands(lhs, rhs)
  }
}

///|
/// Emit SUB.
///
/// Supported forms are `sub(rax, Imm32(_))` and `sub(Reg(_), Reg(_))`.
pub fn ASMContext::sub(
  self : ASMContext,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Sub(lhs, rhs))
  match (lhs, rhs) {
    (Reg(RAX), Imm32(rhs)) => {
      // REX.W accumulator form: 48 2D id.
      self.emit_byte(0x48)
      self.emit_byte(0x2D)
      self.emit_imm32(rhs)
    }
    (Reg(l), Reg(r)) => {
      // Register source is encoded in the ModR/M reg field.
      self.emit_byte(0x48)
      self.emit_byte(0x29)
      self.emit_byte((0xC0 : Byte) | (r.index() << 3) | l.index())
    }
    _ => raise UnsupportedSubOperands(lhs, rhs)
  }
}

///|
/// Emit XOR.
///
/// Supported forms are `xor(Reg(_), Reg(_))` and `xor(Reg(_), Imm32(_))`.
pub fn ASMContext::xor(
  self : ASMContext,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Xor(lhs, rhs))
  match (lhs, rhs) {
    (Reg(dst), Reg(src)) => {
      // 31 /r: XOR r/m64, r64.
      self.emit_byte(0x48)
      self.emit_byte(0x31)
      self.emit_byte((0xC0 : Byte) | (src.index() << 3) | dst.index())
    }
    (Reg(dst), Imm32(src)) => {
      // 81 /6 id: XOR r/m64, imm32.
      self.emit_byte(0x48)
      self.emit_byte(0x81)
      self.emit_byte((0xF0 : Byte) | dst.index())
      self.emit_imm32(src)
    }
    _ => raise UnsupportedXorOperands(lhs, rhs)
  }
}

///|
/// Emit unsigned MUL.
///
/// Supported form is `mul(Reg(_))`, which multiplies RAX by the operand.
pub fn ASMContext::mul(
  self : ASMContext,
  operand : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Mul(operand))
  match operand {
    Reg(l) => {
      self.emit_byte(0x48)
      self.emit_byte(0xF7)
      self.emit_byte((0xE0 : Byte) | l.index())
    }
    _ => raise UnsupportedMulOperand(operand)
  }
}

///|
/// Emit INC.
///
/// Supported form is `inc(Reg(_))`.
pub fn ASMContext::inc(
  self : ASMContext,
  operand : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Inc(operand))
  match operand {
    Reg(reg) => {
      self.emit_byte(0x48)
      self.emit_byte(0xFF)
      self.emit_byte((0xC0 : Byte) | reg.index())
    }
    _ => raise UnsupportedIncOperand(operand)
  }
}

///|
/// Emit DEC.
///
/// Supported form is `dec(Reg(_))`.
pub fn ASMContext::dec(
  self : ASMContext,
  operand : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Dec(operand))
  match operand {
    Reg(reg) => {
      self.emit_byte(0x48)
      self.emit_byte(0xFF)
      self.emit_byte((0xC8 : Byte) | reg.index())
    }
    _ => raise UnsupportedDecOperand(operand)
  }
}

///|
/// Emit LOOP with a signed 8-bit relative displacement.
///
/// The branch target must be within -128..127 bytes from the next instruction.
/// `RCX` is decremented by the CPU and the branch is taken while it is nonzero.
pub fn ASMContext::loop_rel8(
  self : ASMContext,
  label : Label,
) -> Unit raise ASMContextError {
  self.instrs.push(LoopRel8(label))
  self.emit_byte(0xE2)
  let src = self.mem_offset
  // The displacement is relative to the address after the rel8 byte.
  let rel = label.offset - (src + 1)
  if rel < -128 || rel > 127 {
    raise LoopRel8OutOfRange(rel)
  }
  self.emit_byte(rel.to_byte())
}

///|
/// Emit signed IMUL.
///
/// Supported forms are `imul(Reg(_), Imm32(_))` and `imul(Reg(_), Reg(_))`.
pub fn ASMContext::imul(
  self : ASMContext,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(IMul(lhs, rhs))
  match (lhs, rhs) {
    (Reg(l), Imm32(r)) => {
      self.emit_byte(0x48)
      self.emit_byte(0x69)
      self.emit_byte((0xC0 : Byte) | l.index())
      self.emit_imm32(r)
    }
    (Reg(l), Reg(r)) => {
      self.emit_byte(0x48)
      self.emit_byte(0x69)
      self.emit_byte(0xAF)
      self.emit_byte((0xC0 : Byte) | (r.index() << 3) | l.index())
    }
    _ => raise UnsupportedIMulOperands(lhs, rhs)
  }
}

///|
/// Emit MOV.
///
/// Supported forms are `mov(Reg(_), Reg(_))` and `mov(Reg(_), Imm32(_))`.
pub fn ASMContext::mov(
  self : ASMContext,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Mov(lhs, rhs))
  match (lhs, rhs) {
    (Reg(dst), Reg(src)) => {
      // 89 /r: MOV r/m64, r64.
      self.emit_byte(0x48)
      self.emit_byte(0x89)
      self.emit_byte((0xC0 : Byte) | (src.index() << 3) | dst.index())
    }
    (Reg(dst), Imm32(src)) => {
      // C7 /0 id: MOV r/m64, imm32.
      self.emit_byte(0x48)
      self.emit_byte(0xC7)
      self.emit_byte((0xC0 : Byte) | (dst.index() & 0x07))
      self.emit_imm32(src)
    }
    _ => raise UnsupportedMovOperands(lhs, rhs)
  }
}

///|
/// Emit PUSH.
///
/// Supported form is `push(Reg(_))`.
pub fn ASMContext::push(
  self : ASMContext,
  operand : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Push(operand))
  match operand {
    Reg(reg) => self.emit_byte((0x50 : Byte) + reg.index())
    _ => raise UnsupportedPushOperand(operand)
  }
}

///|
/// Emit POP.
///
/// Supported form is `pop(Reg(_))`.
pub fn ASMContext::pop(
  self : ASMContext,
  operand : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Pop(operand))
  match operand {
    Reg(reg) => self.emit_byte((0x58 : Byte) + reg.index())
    _ => raise UnsupportedPopOperand(operand)
  }
}

///|
/// Emit CALL rel32 to either an in-buffer label or an external symbol.
pub fn ASMContext::call(self : ASMContext, target : Target) -> Unit {
  self.instrs.push(Call(target))
  let dst = match target {
    Label(label) => label.offset
    Extern(dst) => dst
  }
  self.emit_byte(0xE8)
  let src = self.mem_offset
  // x86 CALL rel32 is relative to the first byte after the displacement.
  self.emit_imm32(dst - (src + 4))
}

///|
/// Emit SYSCALL.
///
/// The caller is responsible for loading the platform-specific syscall number
/// and arguments into the required registers.
pub fn ASMContext::syscall(self : ASMContext) -> Unit {
  self.instrs.push(Syscall)
  self.emit_byte(0x0F)
  self.emit_byte(0x05)
}
