///|
/// Mutable builder for one x86-64 machine-code buffer.
///
/// A `JITContext` owns one writable code mapping while it builds machine code.
/// It appends encoded bytes to an internal buffer and tracks the byte offset
/// used by labels and relative jumps.
struct JITContext {
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
  // Whether this context has already produced a `JITFunction`.
  mut finalized : Bool
}

///|
/// Finalized machine-code function with a known callable signature.
struct JITFunction[T](FuncRef[T])

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
  ExecutableMemoryProtectionFailed(UInt64, UInt64, Int)
  JITContextAlreadyFinalized
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
/// Create a new code-generation context backed by one writable memory mapping.
pub fn JITContext::new(
  mem_size? : UInt64 = default_exec_memory_size,
) -> JITContext raise ASMContextError {
  let start = allocate_jit_memory(mem_size)
  {
    instrs: [],
    code: Buffer(size_hint=25),
    mem_ptr: start,
    mem_size,
    mem_offset: 0,
    finalized: false,
  }
}

///|
/// Capture the current byte offset as a label.
///
/// Use this before emitting a backward branch or as a local call target.
pub fn JITContext::label(self : JITContext) -> Label {
  { offset: self.mem_offset }
}

///|
/// Resolve a symbol in the current process for use with `call`.
///
/// The returned target stores an offset relative to this context's code buffer,
/// matching x86-64 CALL rel32 encoding.
pub fn JITContext::extern_fn(self : JITContext, name : String) -> Target {
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
fn JITContext::emit_byte(self : JITContext, i : Byte) -> Unit {
  self.code.write_byte(i)
  self.mem_offset += 1
}

///|
/// Return a copy of the generated machine-code bytes.
pub fn JITContext::bytes(self : JITContext) -> Bytes {
  self.code.contents()
}

///|
/// Return a copy of the successfully emitted instruction trace.
pub fn JITContext::trace(self : JITContext) -> Array[Instr] {
  self.instrs.copy()
}

///|
/// Copy the generated code into its mapping and make it executable.
///
/// The generated function is expected to follow the platform ABI enough to
/// return its result in RAX and preserve any registers required by its caller.
pub fn JITContext::finalize_fn_i64(
  self : JITContext,
) -> JITFunction[() -> Int64] raise ASMContextError {
  if self.finalized {
    raise JITContextAlreadyFinalized
  }
  let machcode = self.code.contents()
  let code_size = machcode.length().to_uint64()
  if code_size > self.mem_size {
    raise GeneratedCodeExceedsMemory(code_size, self.mem_size)
  }
  copy_code(self.mem_ptr, machcode, code_size)
  mprotect_rx(self.mem_ptr, self.mem_size)
  self.finalized = true
  JITFunction(code_func_ref_i64(self.mem_ptr))
}

///|
/// Return this finalized function as a callable MoonBit function reference.
pub fn[T] JITFunction::get_fn(self : JITFunction[T]) -> FuncRef[T] {
  let JITFunction(func) = self
  func
}

///|
/// Call this finalized function.
pub fn JITFunction::call(self : JITFunction[() -> Int64]) -> Int64 {
  let f : FuncRef[() -> Int64] = self.get_fn()
  f()
}

///|
/// Emit a one-byte NOP instruction.
pub fn JITContext::nop(self : JITContext) -> Unit {
  self.emit_byte(0x90)
  self.instrs.push(NopOp90)
}

///|
/// Emit a RET instruction.
pub fn JITContext::ret(self : JITContext) -> Unit {
  self.emit_byte(0xC3)
  self.instrs.push(RetNearOpC3)
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
priv enum BinaryInstrKind {
  AddInstr
  SubInstr
  XorInstr
}

///|
fn binary_rm_reg8_instr(
  kind : BinaryInstrKind,
  dst : Operand,
  src : Register,
) -> Instr {
  match kind {
    AddInstr => AddRm8Reg8Op00(dst, src)
    SubInstr => SubRm8Reg8Op28(dst, src)
    XorInstr => XorRm8Reg8Op30(dst, src)
  }
}

///|
fn binary_rm_reg_instr(
  kind : BinaryInstrKind,
  dst : Operand,
  src : Register,
) -> Instr {
  match kind {
    AddInstr => AddRmRegOp01(dst, src)
    SubInstr => SubRmRegOp29(dst, src)
    XorInstr => XorRmRegOp31(dst, src)
  }
}

///|
fn binary_reg_rm8_instr(
  kind : BinaryInstrKind,
  dst : Register,
  src : Operand,
) -> Instr {
  match kind {
    AddInstr => AddReg8Rm8Op02(dst, src)
    SubInstr => SubReg8Rm8Op2A(dst, src)
    XorInstr => XorReg8Rm8Op32(dst, src)
  }
}

///|
fn binary_reg_rm_instr(
  kind : BinaryInstrKind,
  dst : Register,
  src : Operand,
) -> Instr {
  match kind {
    AddInstr => AddRegRmOp03(dst, src)
    SubInstr => SubRegRmOp2B(dst, src)
    XorInstr => XorRegRmOp33(dst, src)
  }
}

///|
fn binary_rm_imm8_instr(
  kind : BinaryInstrKind,
  dst : Operand,
  immediate : Immediate,
) -> Instr {
  match kind {
    AddInstr => AddRm8Imm8Op80Ext0(dst, immediate)
    SubInstr => SubRm8Imm8Op80Ext5(dst, immediate)
    XorInstr => XorRm8Imm8Op80Ext6(dst, immediate)
  }
}

///|
fn binary_rm_imm_instr(
  kind : BinaryInstrKind,
  dst : Operand,
  immediate : Immediate,
) -> Instr {
  match kind {
    AddInstr => AddRmImmOp81Ext0(dst, immediate)
    SubInstr => SubRmImmOp81Ext5(dst, immediate)
    XorInstr => XorRmImmOp81Ext6(dst, immediate)
  }
}

///|
fn binary_rm_imm8_sign_ext_instr(
  kind : BinaryInstrKind,
  dst : Operand,
  immediate : Immediate,
) -> Instr {
  match kind {
    AddInstr => AddRmImm8SignExtOp83Ext0(dst, immediate)
    SubInstr => SubRmImm8SignExtOp83Ext5(dst, immediate)
    XorInstr => XorRmImm8SignExtOp83Ext6(dst, immediate)
  }
}

///|
/// Emit an arithmetic/logical immediate form through opcode groups 80/81/83.
///
/// Width-specific matching is explicit here because x86-64 has no generic
/// "immediate with operand width" rule: 64-bit operations usually consume
/// sign-extended imm32, while byte operations use opcode 80.
fn JITContext::emit_binary_imm(
  self : JITContext,
  width : Width,
  extension : Byte,
  dst : Operand,
  immediate : Immediate,
  kind : BinaryInstrKind,
) -> Instr raise ASMContextError {
  let rm = rm_from_operand(dst)
  immediate.validate()
  match (width, immediate) {
    (W8, Imm8(_)) => {
      self.emit_group_rm(W8, 0x80, extension, rm, false)
      self.emit_immediate(immediate)
      binary_rm_imm8_instr(kind, dst, immediate)
    }
    (W16, Imm8(value)) => {
      if !fits_i8(value) {
        raise ImmediateOutOfRange(immediate)
      }
      self.emit_group_rm(W16, 0x83, extension, rm, false)
      self.emit_i8(value)
      binary_rm_imm8_sign_ext_instr(kind, dst, immediate)
    }
    (W16, Imm16(_)) => {
      self.emit_group_rm(W16, 0x81, extension, rm, false)
      self.emit_immediate(immediate)
      binary_rm_imm_instr(kind, dst, immediate)
    }
    (W32, Imm8(value)) => {
      if !fits_i8(value) {
        raise ImmediateOutOfRange(immediate)
      }
      self.emit_group_rm(W32, 0x83, extension, rm, false)
      self.emit_i8(value)
      binary_rm_imm8_sign_ext_instr(kind, dst, immediate)
    }
    (W32, Imm32(_)) => {
      self.emit_group_rm(W32, 0x81, extension, rm, false)
      self.emit_immediate(immediate)
      binary_rm_imm_instr(kind, dst, immediate)
    }
    (W64, Imm8(value)) => {
      if !fits_i8(value) {
        raise ImmediateOutOfRange(immediate)
      }
      self.emit_group_rm(W64, 0x83, extension, rm, true)
      self.emit_i8(value)
      binary_rm_imm8_sign_ext_instr(kind, dst, immediate)
    }
    (W64, Imm32(_)) => {
      self.emit_group_rm(W64, 0x81, extension, rm, true)
      self.emit_immediate(immediate)
      binary_rm_imm_instr(kind, dst, immediate)
    }
    _ => raise OperandWidthMismatch(width, immediate.width())
  }
}

///|
/// Shared implementation for ADD/SUB/XOR register, memory, and immediate
/// forms.
fn JITContext::emit_binary(
  self : JITContext,
  lhs : Operand,
  rhs : Operand,
  opcode_rm_reg8 : Byte,
  opcode_rm_reg : Byte,
  opcode_reg_rm8 : Byte,
  opcode_reg_rm : Byte,
  imm_extension : Byte,
  kind : BinaryInstrKind,
) -> Instr raise ASMContextError {
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
      if width == W8 {
        binary_rm_reg8_instr(kind, lhs, src)
      } else {
        binary_rm_reg_instr(kind, lhs, src)
      }
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
      if width == W8 {
        binary_rm_reg8_instr(kind, lhs, src)
      } else {
        binary_rm_reg_instr(kind, lhs, src)
      }
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
      if width == W8 {
        binary_reg_rm8_instr(kind, dst, rhs)
      } else {
        binary_reg_rm_instr(kind, dst, rhs)
      }
    }
    (Reg(_) | Mem(_), Imm(immediate)) => {
      let width = width_or_error(lhs)
      self.emit_binary_imm(width, imm_extension, lhs, immediate, kind)
    }
    _ => raise UnsupportedOperandWidth(lhs)
  }
}

///|
/// Emit ADD.
///
/// Supported forms include `reg/mem += reg`, `reg += mem`, and `reg/mem += imm`
/// when operand widths and immediate encoding widths are legal.
pub fn JITContext::add(
  self : JITContext,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  let instr = match (lhs, rhs) {
    (Reg(_) | Mem(_), Reg(_) | Imm(_)) | (Reg(_), Mem(_)) =>
      self.emit_binary(lhs, rhs, 0x00, 0x01, 0x02, 0x03, 0, AddInstr)
    _ => raise UnsupportedAddOperands(lhs, rhs)
  }
  self.instrs.push(instr)
}

///|
/// Emit SUB.
///
/// Supported forms mirror `add`, with the left operand as the destination.
pub fn JITContext::sub(
  self : JITContext,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  let instr = match (lhs, rhs) {
    (Reg(_) | Mem(_), Reg(_) | Imm(_)) | (Reg(_), Mem(_)) =>
      self.emit_binary(lhs, rhs, 0x28, 0x29, 0x2A, 0x2B, 5, SubInstr)
    _ => raise UnsupportedSubOperands(lhs, rhs)
  }
  self.instrs.push(instr)
}

///|
/// Emit XOR.
///
/// Supported forms mirror `add`, with the left operand as the destination.
pub fn JITContext::xor(
  self : JITContext,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  let instr = match (lhs, rhs) {
    (Reg(_) | Mem(_), Reg(_) | Imm(_)) | (Reg(_), Mem(_)) =>
      self.emit_binary(lhs, rhs, 0x30, 0x31, 0x32, 0x33, 6, XorInstr)
    _ => raise UnsupportedXorOperands(lhs, rhs)
  }
  self.instrs.push(instr)
}

///|
/// Emit unsigned MUL, which multiplies AL/AX/EAX/RAX by the operand.
///
/// The implicit accumulator and result registers are defined by the operand
/// width, following the x86 integer `MUL r/m` instruction.
pub fn JITContext::mul(
  self : JITContext,
  operand : Operand,
) -> Unit raise ASMContextError {
  let instr = match operand {
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
      if width == W8 {
        MulRm8OpF6Ext4(operand)
      } else {
        MulRmOpF7Ext4(operand)
      }
    }
    _ => raise UnsupportedMulOperand(operand)
  }
  self.instrs.push(instr)
}

///|
/// Emit INC.
///
/// Supports byte, word, dword, and qword register/memory operands.
pub fn JITContext::inc(
  self : JITContext,
  operand : Operand,
) -> Unit raise ASMContextError {
  let instr = match operand {
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
      if width == W8 {
        IncRm8OpFEExt0(operand)
      } else {
        IncRmOpFFExt0(operand)
      }
    }
    _ => raise UnsupportedIncOperand(operand)
  }
  self.instrs.push(instr)
}

///|
/// Emit DEC.
///
/// Supports byte, word, dword, and qword register/memory operands.
pub fn JITContext::dec(
  self : JITContext,
  operand : Operand,
) -> Unit raise ASMContextError {
  let instr = match operand {
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
      if width == W8 {
        DecRm8OpFEExt1(operand)
      } else {
        DecRmOpFFExt1(operand)
      }
    }
    _ => raise UnsupportedDecOperand(operand)
  }
  self.instrs.push(instr)
}

///|
/// Emit LOOP with a signed 8-bit relative displacement.
///
/// The branch target must be within -128..127 bytes from the next instruction.
/// `RCX` is decremented by the CPU and the branch is taken while it is nonzero.
pub fn JITContext::loop_rel8(
  self : JITContext,
  label : Label,
) -> Unit raise ASMContextError {
  let src = self.mem_offset
  let rel = label.offset - (src + 2)
  if !fits_i8(rel) {
    raise LoopRel8OutOfRange(rel)
  }
  self.emit_byte(0xE2)
  self.emit_i8(rel)
  self.instrs.push(LoopRcxRel8OpE2(label, rel))
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
fn JITContext::emit_imul_imm(
  self : JITContext,
  dst : Register,
  immediate : Immediate,
  lhs : Operand,
  rhs : Operand,
) -> Instr raise ASMContextError {
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
      IMulRegRmImm8Op6B(dst, Reg(dst), immediate)
    }
    (W16, Imm16(_)) => {
      self.emit_reg_rm(W16, 0x69, dst, reg_as_rm(dst), false)
      self.emit_immediate(immediate)
      IMulRegRmImmOp69(dst, Reg(dst), immediate)
    }
    (W32, Imm32(_)) => {
      self.emit_reg_rm(W32, 0x69, dst, reg_as_rm(dst), false)
      self.emit_immediate(immediate)
      IMulRegRmImmOp69(dst, Reg(dst), immediate)
    }
    (W64, Imm32(_)) => {
      self.emit_reg_rm(W64, 0x69, dst, reg_as_rm(dst), true)
      self.emit_immediate(immediate)
      IMulRegRmImmOp69(dst, Reg(dst), immediate)
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
pub fn JITContext::imul(
  self : JITContext,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  let instr = match (lhs, rhs) {
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
      IMulRegRmOp0FAF(dst, rhs)
    }
    (Reg(dst), Imm(immediate)) => self.emit_imul_imm(dst, immediate, lhs, rhs)
    _ => raise UnsupportedIMulOperands(lhs, rhs)
  }
  self.instrs.push(instr)
}

///|
fn JITContext::emit_mov_reg_imm(
  self : JITContext,
  dst : Register,
  immediate : Immediate,
  lhs : Operand,
  rhs : Operand,
) -> Instr raise ASMContextError {
  let width = dst.width()
  immediate.validate()
  match (width, immediate) {
    (W8, Imm8(_)) => {
      self.emit_opcode_register(W8, 0xB0, dst, false)
      self.emit_immediate(immediate)
      MovReg8Imm8OpB0(dst, immediate)
    }
    (W16, Imm16(_)) => {
      self.emit_opcode_register(W16, 0xB8, dst, false)
      self.emit_immediate(immediate)
      MovRegImmOpB8(dst, immediate)
    }
    (W32, Imm32(_)) => {
      self.emit_opcode_register(W32, 0xB8, dst, false)
      self.emit_immediate(immediate)
      MovRegImmOpB8(dst, immediate)
    }
    (W64, Imm32(_)) => {
      self.emit_group_rm(W64, 0xC7, 0, reg_as_rm(dst), true)
      self.emit_immediate(immediate)
      MovRmImmOpC7Ext0(Reg(dst), immediate)
    }
    (W64, Imm64(_)) => {
      self.emit_opcode_register(W64, 0xB8, dst, true)
      self.emit_immediate(immediate)
      MovRegImmOpB8(dst, immediate)
    }
    _ => raise UnsupportedMovOperands(lhs, rhs)
  }
}

///|
fn JITContext::emit_mov_mem_imm(
  self : JITContext,
  dst : Memory,
  immediate : Immediate,
  lhs : Operand,
  rhs : Operand,
) -> Instr raise ASMContextError {
  immediate.validate()
  match (dst.size, immediate) {
    (W8, Imm8(_)) => {
      self.emit_group_rm(W8, 0xC6, 0, mem_as_rm(dst), false)
      self.emit_immediate(immediate)
      MovRm8Imm8OpC6Ext0(Mem(dst), immediate)
    }
    (W16, Imm16(_)) => {
      self.emit_group_rm(W16, 0xC7, 0, mem_as_rm(dst), false)
      self.emit_immediate(immediate)
      MovRmImmOpC7Ext0(Mem(dst), immediate)
    }
    (W32, Imm32(_)) => {
      self.emit_group_rm(W32, 0xC7, 0, mem_as_rm(dst), false)
      self.emit_immediate(immediate)
      MovRmImmOpC7Ext0(Mem(dst), immediate)
    }
    (W64, Imm32(_)) => {
      self.emit_group_rm(W64, 0xC7, 0, mem_as_rm(dst), true)
      self.emit_immediate(immediate)
      MovRmImmOpC7Ext0(Mem(dst), immediate)
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
pub fn JITContext::mov(
  self : JITContext,
  lhs : Operand,
  rhs : Operand,
) -> Unit raise ASMContextError {
  let instr = match (lhs, rhs) {
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
      if width == W8 {
        MovRm8Reg8Op88(lhs, src)
      } else {
        MovRmRegOp89(lhs, src)
      }
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
      if width == W8 {
        MovReg8Rm8Op8A(dst, rhs)
      } else {
        MovRegRmOp8B(dst, rhs)
      }
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
      if width == W8 {
        MovRm8Reg8Op88(lhs, src)
      } else {
        MovRmRegOp89(lhs, src)
      }
    }
    (Reg(dst), Imm(immediate)) =>
      self.emit_mov_reg_imm(dst, immediate, lhs, rhs)
    (Mem(dst), Imm(immediate)) =>
      self.emit_mov_mem_imm(dst, immediate, lhs, rhs)
    _ => raise UnsupportedMovOperands(lhs, rhs)
  }
  self.instrs.push(instr)
}

///|
fn JITContext::emit_push_imm(
  self : JITContext,
  immediate : Immediate,
) -> Instr raise ASMContextError {
  immediate.validate()
  match immediate {
    Imm8(value) => {
      if !fits_i8(value) {
        raise ImmediateOutOfRange(immediate)
      }
      self.emit_byte(0x6A)
      self.emit_immediate(immediate)
      PushImm8Op6A(immediate)
    }
    Imm16(_) => {
      self.emit_byte(0x66)
      self.emit_byte(0x68)
      self.emit_immediate(immediate)
      PushImmOp68(immediate)
    }
    Imm32(_) => {
      self.emit_byte(0x68)
      self.emit_immediate(immediate)
      PushImmOp68(immediate)
    }
    Imm64(_) => raise UnsupportedOperandWidth(Imm(immediate))
  }
}

///|
/// Emit PUSH.
///
/// Supports 16-bit and 64-bit register/memory operands, plus encodable
/// immediate forms.
pub fn JITContext::push(
  self : JITContext,
  operand : Operand,
) -> Unit raise ASMContextError {
  let instr = match operand {
    Reg(register) =>
      match register.width() {
        W16 => {
          self.emit_opcode_register(W16, 0x50, register, false)
          PushRegOp50(register)
        }
        W64 => {
          self.emit_opcode_register(W64, 0x50, register, false)
          PushRegOp50(register)
        }
        _ => raise UnsupportedPushOperand(operand)
      }
    Mem(memory) =>
      match memory.size {
        W16 => {
          self.emit_group_rm(W16, 0xFF, 6, mem_as_rm(memory), false)
          PushRmOpFFExt6(operand)
        }
        W64 => {
          self.emit_group_rm(W64, 0xFF, 6, mem_as_rm(memory), false)
          PushRmOpFFExt6(operand)
        }
        _ => raise UnsupportedPushOperand(operand)
      }
    Imm(immediate) => self.emit_push_imm(immediate)
    _ => raise UnsupportedPushOperand(operand)
  }
  self.instrs.push(instr)
}

///|
/// Emit POP.
///
/// Supports 16-bit and 64-bit register/memory operands.
pub fn JITContext::pop(
  self : JITContext,
  operand : Operand,
) -> Unit raise ASMContextError {
  let instr = match operand {
    Reg(register) =>
      match register.width() {
        W16 => {
          self.emit_opcode_register(W16, 0x58, register, false)
          PopRegOp58(register)
        }
        W64 => {
          self.emit_opcode_register(W64, 0x58, register, false)
          PopRegOp58(register)
        }
        _ => raise UnsupportedPopOperand(operand)
      }
    Mem(memory) =>
      match memory.size {
        W16 => {
          self.emit_group_rm(W16, 0x8F, 0, mem_as_rm(memory), false)
          PopRmOp8FExt0(operand)
        }
        W64 => {
          self.emit_group_rm(W64, 0x8F, 0, mem_as_rm(memory), false)
          PopRmOp8FExt0(operand)
        }
        _ => raise UnsupportedPopOperand(operand)
      }
    _ => raise UnsupportedPopOperand(operand)
  }
  self.instrs.push(instr)
}

///|
/// Emit CALL rel32 to either an in-buffer label or an external symbol.
pub fn JITContext::call(self : JITContext, target : Target) -> Unit {
  let dst = match target {
    Label(label) => label.offset
    Extern(dst) => dst
  }
  let src = self.mem_offset
  // x86 CALL rel32 is relative to the first byte after the displacement.
  let rel = dst - (src + 5)
  self.emit_byte(0xE8)
  self.emit_i32(rel)
  self.instrs.push(CallRel32OpE8(target, rel))
}

///|
/// Emit SYSCALL.
///
/// The caller is responsible for loading the platform-specific syscall number
/// and arguments into the required registers.
pub fn JITContext::syscall(self : JITContext) -> Unit {
  self.emit_byte(0x0F)
  self.emit_byte(0x05)
  self.instrs.push(SyscallOp0F05)
}
