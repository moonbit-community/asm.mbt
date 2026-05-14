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
  // Size of the executable memory region.
  mem_size : UInt64
  // Current byte offset from `mem_ptr`.
  mut mem_offset : Int
}

///|
/// Errors raised when an instruction helper cannot encode the requested form.
pub(all) suberror ASMContextError {
  // Instruction-specific fallbacks for forms that have no supported encoding.
  UnsupportedAddOperands(Operand, Operand)
  UnsupportedSubOperands(Operand, Operand)
  UnsupportedXorOperands(Operand, Operand)
  UnsupportedMulOperand(Operand)
  UnsupportedIncOperand(Operand)
  UnsupportedDecOperand(Operand)
  LoopRel8OutOfRange(Int)
  UnsupportedIMulOperands(Operand, Operand)
  UnsupportedMovOperands(Operand, Operand)
  UnsupportedPushOperand(Operand)
  UnsupportedPopOperand(Operand)
  // Executable-memory lifecycle errors.
  ExecutableMemoryAllocationFailed(UInt64, Int)
  GeneratedCodeExceedsMemory(UInt64, UInt64)
  // Generic validation errors shared by the encoding layer.
  UnsupportedOperandWidth(Operand)
  OperandWidthMismatch(Width, Width)
  ImmediateOutOfRange(Immediate)
  InvalidMemoryScale(Int)
  InvalidMemoryBase(Register)
  InvalidMemoryIndex(Register)
  MemoryIndexCannotBeStackPointer(Register)
  High8RexConflict
} derive(Debug)

///|
/// Create a new code-generation context for an executable memory region.
///
/// When `mem_size` is omitted, contexts created from `alloc` use the recorded
/// allocation size. Raw pointers that were not returned by `alloc` fall back to
/// the default allocation size.
pub fn ASMContext::new(start~ : UInt64, mem_size? : UInt64 = 0UL) -> ASMContext {
  let mem_size = if mem_size == 0UL {
    match executable_allocation_size(start) {
      Some(size) => size
      None => default_exec_memory_size
    }
  } else {
    mem_size
  }
  ASMContext::{
    instrs: [],
    code: @buffer.new(size_hint=25),
    mem_ptr: start,
    mem_size,
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
/// Return a copy of the generated machine-code bytes.
pub fn ASMContext::bytes(self : ASMContext) -> Bytes {
  self.code.contents()
}

///|
/// Copy the generated code into executable memory and call it as `fn() -> Int64`.
///
/// The generated function is expected to follow the platform ABI enough to
/// return its result in RAX and preserve any registers required by its caller.
pub fn ASMContext::exec(self : ASMContext) -> Int64 raise ASMContextError {
  let machcode = self.code.contents()
  let code_size = machcode.length().to_uint64()
  if code_size > self.mem_size {
    raise GeneratedCodeExceedsMemory(code_size, self.mem_size)
  }
  __exec(self.mem_ptr, machcode, code_size)
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
fn rm_from_operand(operand : Operand) -> RmOperand raise ASMContextError {
  match operand {
    Reg(register) => reg_as_rm(register)
    Mem(memory) => mem_as_rm(memory)
    _ => raise UnsupportedOperandWidth(operand)
  }
}

///|
/// Emit an arithmetic/logical immediate form through opcode groups 80/81/83.
///
/// Width-specific matching is explicit here because x86-64 has no generic
/// "immediate with operand width" rule: 64-bit operations usually consume
/// sign-extended imm32, while byte operations use opcode 80.
fn ASMContext::emit_binary_imm(
  self : ASMContext,
  width : Width,
  extension : Byte,
  rm : RmOperand,
  immediate : Immediate,
) -> Unit raise ASMContextError {
  immediate.validate()
  match (width, immediate) {
    (W8, Imm8(_)) => {
      self.emit_group_rm(W8, 0x80, extension, rm, false)
      self.emit_immediate(immediate)
    }
    (W16, Imm8(value)) => {
      if !fits_i8(value) {
        raise ImmediateOutOfRange(immediate)
      }
      self.emit_group_rm(W16, 0x83, extension, rm, false)
      self.emit_i8(value)
    }
    (W16, Imm16(_)) => {
      self.emit_group_rm(W16, 0x81, extension, rm, false)
      self.emit_immediate(immediate)
    }
    (W32, Imm8(value)) => {
      if !fits_i8(value) {
        raise ImmediateOutOfRange(immediate)
      }
      self.emit_group_rm(W32, 0x83, extension, rm, false)
      self.emit_i8(value)
    }
    (W32, Imm32(_)) => {
      self.emit_group_rm(W32, 0x81, extension, rm, false)
      self.emit_immediate(immediate)
    }
    (W64, Imm8(value)) => {
      if !fits_i8(value) {
        raise ImmediateOutOfRange(immediate)
      }
      self.emit_group_rm(W64, 0x83, extension, rm, true)
      self.emit_i8(value)
    }
    (W64, Imm32(_)) => {
      self.emit_group_rm(W64, 0x81, extension, rm, true)
      self.emit_immediate(immediate)
    }
    _ => raise OperandWidthMismatch(width, immediate.width())
  }
}

///|
/// Shared implementation for ADD/SUB/XOR register, memory, and immediate
/// forms.
fn ASMContext::emit_binary(
  self : ASMContext,
  lhs : Operand,
  rhs : Operand,
  opcode_rm_reg8 : Byte,
  opcode_rm_reg : Byte,
  opcode_reg_rm8 : Byte,
  opcode_reg_rm : Byte,
  imm_extension : Byte,
) -> Unit raise ASMContextError {
  match (lhs, rhs) {
    (Reg(dst), Reg(src)) => {
      let width = require_same_width(lhs, rhs)
      self.emit_reg_rm(
        width,
        if width == W8 {
          opcode_rm_reg8
        } else {
          opcode_rm_reg
        },
        src,
        reg_as_rm(dst),
        width == W64,
      )
    }
    (Mem(dst), Reg(src)) => {
      let width = require_same_width(lhs, rhs)
      self.emit_reg_rm(
        width,
        if width == W8 {
          opcode_rm_reg8
        } else {
          opcode_rm_reg
        },
        src,
        mem_as_rm(dst),
        width == W64,
      )
    }
    (Reg(dst), Mem(src)) => {
      let width = require_same_width(lhs, rhs)
      self.emit_reg_rm(
        width,
        if width == W8 {
          opcode_reg_rm8
        } else {
          opcode_reg_rm
        },
        dst,
        mem_as_rm(src),
        width == W64,
      )
    }
    (Reg(_) | Mem(_), Imm(immediate)) => {
      let width = width_or_error(lhs)
      self.emit_binary_imm(
        width,
        imm_extension,
        rm_from_operand(lhs),
        immediate,
      )
    }
    _ => raise UnsupportedOperandWidth(lhs)
  }
}

///|
/// Emit ADD.
///
/// Supported forms include `reg/mem += reg`, `reg += mem`, and `reg/mem += imm`
/// when operand widths and immediate encoding widths are legal.
pub fn ASMContext::add(
  self : ASMContext,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Add(lhs, rhs))
  match (lhs, rhs) {
    (Reg(_) | Mem(_), Reg(_) | Imm(_)) | (Reg(_), Mem(_)) =>
      self.emit_binary(lhs, rhs, 0x00, 0x01, 0x02, 0x03, 0)
    _ => raise UnsupportedAddOperands(lhs, rhs)
  }
}

///|
/// Emit SUB.
///
/// Supported forms mirror `add`, with the left operand as the destination.
pub fn ASMContext::sub(
  self : ASMContext,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Sub(lhs, rhs))
  match (lhs, rhs) {
    (Reg(_) | Mem(_), Reg(_) | Imm(_)) | (Reg(_), Mem(_)) =>
      self.emit_binary(lhs, rhs, 0x28, 0x29, 0x2A, 0x2B, 5)
    _ => raise UnsupportedSubOperands(lhs, rhs)
  }
}

///|
/// Emit XOR.
///
/// Supported forms mirror `add`, with the left operand as the destination.
pub fn ASMContext::xor(
  self : ASMContext,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Xor(lhs, rhs))
  match (lhs, rhs) {
    (Reg(_) | Mem(_), Reg(_) | Imm(_)) | (Reg(_), Mem(_)) =>
      self.emit_binary(lhs, rhs, 0x30, 0x31, 0x32, 0x33, 6)
    _ => raise UnsupportedXorOperands(lhs, rhs)
  }
}

///|
/// Emit unsigned MUL, which multiplies AL/AX/EAX/RAX by the operand.
///
/// The implicit accumulator and result registers are defined by the operand
/// width, following the x86 integer `MUL r/m` instruction.
pub fn ASMContext::mul(
  self : ASMContext,
  operand : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Mul(operand))
  match operand {
    Reg(_) | Mem(_) => {
      let width = width_or_error(operand)
      self.emit_group_rm(
        width,
        if width == W8 {
          0xF6
        } else {
          0xF7
        },
        4,
        rm_from_operand(operand),
        width == W64,
      )
    }
    _ => raise UnsupportedMulOperand(operand)
  }
}

///|
/// Emit INC.
///
/// Supports byte, word, dword, and qword register/memory operands.
pub fn ASMContext::inc(
  self : ASMContext,
  operand : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Inc(operand))
  match operand {
    Reg(_) | Mem(_) => {
      let width = width_or_error(operand)
      self.emit_group_rm(
        width,
        if width == W8 {
          0xFE
        } else {
          0xFF
        },
        0,
        rm_from_operand(operand),
        width == W64,
      )
    }
    _ => raise UnsupportedIncOperand(operand)
  }
}

///|
/// Emit DEC.
///
/// Supports byte, word, dword, and qword register/memory operands.
pub fn ASMContext::dec(
  self : ASMContext,
  operand : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Dec(operand))
  match operand {
    Reg(_) | Mem(_) => {
      let width = width_or_error(operand)
      self.emit_group_rm(
        width,
        if width == W8 {
          0xFE
        } else {
          0xFF
        },
        1,
        rm_from_operand(operand),
        width == W64,
      )
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
  let src = self.mem_offset
  let rel = label.offset - (src + 2)
  if !fits_i8(rel) {
    raise LoopRel8OutOfRange(rel)
  }
  self.emit_byte(0xE2)
  self.emit_i8(rel)
}

///|
fn ensure_not_byte_width(
  width : Width,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  if width == W8 {
    raise UnsupportedIMulOperands(lhs, rhs)
  }
}

///|
fn ASMContext::emit_imul_imm(
  self : ASMContext,
  dst : Register,
  immediate : Immediate,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  let width = dst.width()
  ensure_not_byte_width(width, lhs, rhs)
  immediate.validate()
  match (width, immediate) {
    (W16 | W32 | W64, Imm8(value)) => {
      if !fits_i8(value) {
        raise ImmediateOutOfRange(immediate)
      }
      self.emit_reg_rm(width, 0x6B, dst, reg_as_rm(dst), width == W64)
      self.emit_i8(value)
    }
    (W16, Imm16(_)) => {
      self.emit_reg_rm(W16, 0x69, dst, reg_as_rm(dst), false)
      self.emit_immediate(immediate)
    }
    (W32, Imm32(_)) => {
      self.emit_reg_rm(W32, 0x69, dst, reg_as_rm(dst), false)
      self.emit_immediate(immediate)
    }
    (W64, Imm32(_)) => {
      self.emit_reg_rm(W64, 0x69, dst, reg_as_rm(dst), true)
      self.emit_immediate(immediate)
    }
    _ => raise OperandWidthMismatch(width, immediate.width())
  }
}

///|
/// Emit signed IMUL.
///
/// Supported forms are two-operand `imul(reg, reg/mem)` and
/// `imul(reg, imm)`. The register/register form uses the standard `0F AF /r`
/// encoding.
pub fn ASMContext::imul(
  self : ASMContext,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(IMul(lhs, rhs))
  match (lhs, rhs) {
    (Reg(dst), Reg(_) | Mem(_)) => {
      let width = require_same_width(lhs, rhs)
      ensure_not_byte_width(width, lhs, rhs)
      self.emit_reg_rm_2(
        width,
        0x0F,
        0xAF,
        dst,
        rm_from_operand(rhs),
        width == W64,
      )
    }
    (Reg(dst), Imm(immediate)) => self.emit_imul_imm(dst, immediate, lhs, rhs)
    _ => raise UnsupportedIMulOperands(lhs, rhs)
  }
}

///|
fn ASMContext::emit_mov_reg_imm(
  self : ASMContext,
  dst : Register,
  immediate : Immediate,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  let width = dst.width()
  immediate.validate()
  match (width, immediate) {
    (W8, Imm8(_)) => {
      self.emit_opcode_register(W8, 0xB0, dst, false)
      self.emit_immediate(immediate)
    }
    (W16, Imm16(_)) => {
      self.emit_opcode_register(W16, 0xB8, dst, false)
      self.emit_immediate(immediate)
    }
    (W32, Imm32(_)) => {
      self.emit_opcode_register(W32, 0xB8, dst, false)
      self.emit_immediate(immediate)
    }
    (W64, Imm32(_)) => {
      self.emit_group_rm(W64, 0xC7, 0, reg_as_rm(dst), true)
      self.emit_immediate(immediate)
    }
    (W64, Imm64(_)) => {
      self.emit_opcode_register(W64, 0xB8, dst, true)
      self.emit_immediate(immediate)
    }
    _ => raise UnsupportedMovOperands(lhs, rhs)
  }
}

///|
fn ASMContext::emit_mov_mem_imm(
  self : ASMContext,
  dst : Memory,
  immediate : Immediate,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  immediate.validate()
  match (dst.size, immediate) {
    (W8, Imm8(_)) => {
      self.emit_group_rm(W8, 0xC6, 0, mem_as_rm(dst), false)
      self.emit_immediate(immediate)
    }
    (W16, Imm16(_)) => {
      self.emit_group_rm(W16, 0xC7, 0, mem_as_rm(dst), false)
      self.emit_immediate(immediate)
    }
    (W32, Imm32(_)) => {
      self.emit_group_rm(W32, 0xC7, 0, mem_as_rm(dst), false)
      self.emit_immediate(immediate)
    }
    (W64, Imm32(_)) => {
      self.emit_group_rm(W64, 0xC7, 0, mem_as_rm(dst), true)
      self.emit_immediate(immediate)
    }
    _ => raise UnsupportedMovOperands(lhs, rhs)
  }
}

///|
/// Emit MOV.
///
/// Supports register/register, register/memory, memory/register,
/// register/immediate, and memory/immediate integer forms. Memory operands must
/// carry an explicit width.
pub fn ASMContext::mov(
  self : ASMContext,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Mov(lhs, rhs))
  match (lhs, rhs) {
    (Reg(dst), Reg(src)) => {
      let width = require_same_width(lhs, rhs)
      self.emit_reg_rm(
        width,
        if width == W8 {
          0x88
        } else {
          0x89
        },
        src,
        reg_as_rm(dst),
        width == W64,
      )
    }
    (Reg(dst), Mem(src)) => {
      let width = require_same_width(lhs, rhs)
      self.emit_reg_rm(
        width,
        if width == W8 {
          0x8A
        } else {
          0x8B
        },
        dst,
        mem_as_rm(src),
        width == W64,
      )
    }
    (Mem(dst), Reg(src)) => {
      let width = require_same_width(lhs, rhs)
      self.emit_reg_rm(
        width,
        if width == W8 {
          0x88
        } else {
          0x89
        },
        src,
        mem_as_rm(dst),
        width == W64,
      )
    }
    (Reg(dst), Imm(immediate)) =>
      self.emit_mov_reg_imm(dst, immediate, lhs, rhs)
    (Mem(dst), Imm(immediate)) =>
      self.emit_mov_mem_imm(dst, immediate, lhs, rhs)
    _ => raise UnsupportedMovOperands(lhs, rhs)
  }
}

///|
fn ASMContext::emit_push_imm(
  self : ASMContext,
  immediate : Immediate,
) -> Unit raise ASMContextError {
  immediate.validate()
  match immediate {
    Imm8(value) => {
      if !fits_i8(value) {
        raise ImmediateOutOfRange(immediate)
      }
      self.emit_byte(0x6A)
      self.emit_immediate(immediate)
    }
    Imm16(_) => {
      self.emit_byte(0x66)
      self.emit_byte(0x68)
      self.emit_immediate(immediate)
    }
    Imm32(_) => {
      self.emit_byte(0x68)
      self.emit_immediate(immediate)
    }
    Imm64(_) => raise UnsupportedOperandWidth(Imm(immediate))
  }
}

///|
/// Emit PUSH.
///
/// Supports 16-bit and 64-bit register/memory operands, plus encodable
/// immediate forms.
pub fn ASMContext::push(
  self : ASMContext,
  operand : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Push(operand))
  match operand {
    Reg(register) =>
      match register.width() {
        W16 => self.emit_opcode_register(W16, 0x50, register, false)
        W64 => self.emit_opcode_register(W64, 0x50, register, false)
        _ => raise UnsupportedPushOperand(operand)
      }
    Mem(memory) =>
      match memory.size {
        W16 => self.emit_group_rm(W16, 0xFF, 6, mem_as_rm(memory), false)
        W64 => self.emit_group_rm(W64, 0xFF, 6, mem_as_rm(memory), false)
        _ => raise UnsupportedPushOperand(operand)
      }
    Imm(immediate) => self.emit_push_imm(immediate)
    _ => raise UnsupportedPushOperand(operand)
  }
}

///|
/// Emit POP.
///
/// Supports 16-bit and 64-bit register/memory operands.
pub fn ASMContext::pop(
  self : ASMContext,
  operand : Operand,
) -> Unit raise ASMContextError {
  self.instrs.push(Pop(operand))
  match operand {
    Reg(register) =>
      match register.width() {
        W16 => self.emit_opcode_register(W16, 0x58, register, false)
        W64 => self.emit_opcode_register(W64, 0x58, register, false)
        _ => raise UnsupportedPopOperand(operand)
      }
    Mem(memory) =>
      match memory.size {
        W16 => self.emit_group_rm(W16, 0x8F, 0, mem_as_rm(memory), false)
        W64 => self.emit_group_rm(W64, 0x8F, 0, mem_as_rm(memory), false)
        _ => raise UnsupportedPopOperand(operand)
      }
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
  self.emit_i32(dst - (src + 4))
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
