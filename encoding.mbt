///|
/// Register-direct or memory operand after it has been classified for ModR/M.
priv enum RmOperand {
  RmReg(Register)
  RmMem(Memory)
}

///|
/// Fully resolved ModR/M-side encoding state.
///
/// The encoder computes this before writing bytes so validation errors do not
/// leave a partially emitted instruction in the context buffer.
priv struct EncodedRm {
  // The ModR/M byte, including the caller-provided reg/opcode field.
  modrm : Byte
  // Optional SIB byte required by rsp/r12 bases or scaled index addressing.
  sib : Byte?
  // Signed displacement value, encoded using `disp_size` bytes.
  disp : Int64
  disp_size : Int
  // REX bits contributed by the r/m base and SIB index fields.
  rex_b : Bool
  rex_x : Bool
  // Low 8-bit spl/bpl/sil/dil force a bare REX prefix even without extension.
  force_rex : Bool
  // High 8-bit registers are illegal in any instruction that emits REX.
  has_high8 : Bool
  segment : Segment?
}

///|
/// Memory addressing mode and displacement width chosen from base + disp.
priv struct ModDisp {
  mod_bits : Byte
  disp_size : Int
}

///|
fn bool_byte(value : Bool, bit : Byte) -> Byte {
  if value {
    bit
  } else {
    0
  }
}

///|
fn fits_i8(value : Int) -> Bool {
  value >= -128 && value <= 127
}

///|
fn fits_i8_i64(value : Int64) -> Bool {
  value >= -128L && value <= 127L
}

///|
fn fits_imm8(value : Int) -> Bool {
  value >= -128 && value <= 255
}

///|
fn fits_imm16(value : Int) -> Bool {
  value >= -32768 && value <= 65535
}

///|
fn fits_i32(value : Int64) -> Bool {
  value >= -2147483648L && value <= 2147483647L
}

///|
fn fits_imm32(value : Int64) -> Bool {
  value >= -2147483648L && value <= 4294967295L
}

///|
/// Return the two SIB scale bits for the public scale value.
fn scale_bits(scale : Int) -> Byte raise ASMContextError {
  match scale {
    1 => 0
    2 => 1
    4 => 2
    8 => 3
    _ => raise InvalidMemoryScale(scale)
  }
}

///|
fn operand_width(operand : Operand) -> Width? {
  match operand {
    Reg(register) => Some(register.width())
    Mem(memory) => Some(memory.size)
    Imm(immediate) => Some(immediate.width())
    Rel(_) => None
  }
}

///|
fn Immediate::width(self : Immediate) -> Width {
  match self {
    Imm8(_) => W8
    Imm16(_) => W16
    Imm32(_) => W32
    Imm64(_) => W64
  }
}

///|
fn Immediate::validate(self : Immediate) -> Unit raise ASMContextError {
  match self {
    Imm8(value) => if !fits_imm8(value) { raise ImmediateOutOfRange(self) }
    Imm16(value) => if !fits_imm16(value) { raise ImmediateOutOfRange(self) }
    Imm32(value) => if !fits_imm32(value) { raise ImmediateOutOfRange(self) }
    Imm64(_) => ()
  }
}

///|
fn Immediate::validate_signed_imm32(
  self : Immediate,
) -> Unit raise ASMContextError {
  match self {
    Imm32(value) => if !fits_i32(value) { raise ImmediateOutOfRange(self) }
    _ => self.validate()
  }
}

///|
fn width_or_error(operand : Operand) -> Width raise ASMContextError {
  match operand_width(operand) {
    Some(width) => width
    None => raise UnsupportedOperandWidth(operand)
  }
}

///|
fn require_same_width(
  lhs : Operand,
  rhs : Operand,
) -> Width raise ASMContextError {
  let lhs_width = width_or_error(lhs)
  let rhs_width = width_or_error(rhs)
  if lhs_width != rhs_width {
    raise OperandWidthMismatch(lhs_width, rhs_width)
  }
  lhs_width
}

///|
fn reg_as_rm(register : Register) -> RmOperand {
  RmReg(register)
}

///|
fn mem_as_rm(memory : Memory) -> RmOperand {
  RmMem(memory)
}

///|
/// Normalize an addressing base register.
///
/// This package intentionally supports only 64-bit mode addressing, so base
/// and index registers must be `W64` GPRs.
fn memory_base(register : Register) -> GprBase raise ASMContextError {
  if !register.is_address_register() {
    raise InvalidMemoryBase(register)
  }
  match register.as_gpr_base() {
    Some(base) => base
    None => raise InvalidMemoryBase(register)
  }
}

///|
/// Normalize an addressing index register.
///
/// x86-64 reserves SIB index code 100 for "no index", so rsp cannot be an
/// index. r12 can be an index because REX.X distinguishes it from rsp.
fn memory_index(register : Register) -> GprBase raise ASMContextError {
  if !register.is_address_register() {
    raise InvalidMemoryIndex(register)
  }
  match register.as_gpr_base() {
    Some(SP) => raise MemoryIndexCannotBeStackPointer(register)
    Some(base) => base
    None => raise InvalidMemoryIndex(register)
  }
}

///|
/// Pick the ModR/M `mod` field and displacement width for a base address.
///
/// rbp/r13 with no displacement cannot use `mod=00` because that encoding
/// means disp32 or RIP-relative, so they are emitted as disp8 = 0.
fn mod_disp_for_base(
  base : GprBase,
  disp : Int64,
) -> ModDisp raise ASMContextError {
  if disp == 0 && !base.is_base_pointer_encoding() {
    { mod_bits: 0, disp_size: 0 }
  } else if fits_i8_i64(disp) {
    { mod_bits: 1, disp_size: 1 }
  } else if fits_i32(disp) {
    { mod_bits: 2, disp_size: 4 }
  } else {
    raise MemoryDisplacementOutOfRange(disp)
  }
}

///|
/// Encode the r/m side of a ModR/M instruction.
fn encode_rm(
  reg_bits : Byte,
  rm : RmOperand,
) -> EncodedRm raise ASMContextError {
  match rm {
    RmReg(register) =>
      {
        modrm: (0xC0 : Byte) | (reg_bits << 3) | register.low3(),
        sib: None,
        disp: 0,
        disp_size: 0,
        rex_b: register.needs_rex_bit(),
        rex_x: false,
        force_rex: register.requires_rex_byte(),
        has_high8: register.is_high8(),
        segment: None,
      }
    RmMem(memory) => encode_memory_rm(reg_bits, memory)
  }
}

///|
fn encode_memory_rm(
  reg_bits : Byte,
  memory : Memory,
) -> EncodedRm raise ASMContextError {
  if memory.rip_relative {
    if !fits_i32(memory.disp) {
      raise MemoryDisplacementOutOfRange(memory.disp)
    }
    // In 64-bit mode, mod=00 r/m=101 is RIP-relative regardless of REX.B.
    // Keep rex_b false so this never accidentally becomes the r13 base form.
    {
      modrm: (reg_bits << 3) | 5,
      sib: None,
      disp: memory.disp,
      disp_size: 4,
      rex_b: false,
      rex_x: false,
      force_rex: false,
      has_high8: false,
      segment: memory.segment,
    }
  } else {
    let scale = scale_bits(memory.scale)
    let index = match memory.index {
      Some(register) => Some(memory_index(register))
      None => None
    }
    let base = match memory.base {
      Some(register) => Some(memory_base(register))
      None => None
    }
    match base {
      Some(base) => {
        let mod_disp = mod_disp_for_base(base, memory.disp)
        // rsp/r12 as a base require a SIB byte because r/m=100 selects SIB.
        let use_sib = match index {
          Some(_) => true
          None => base.low3() == 4
        }
        if use_sib {
          let index_bits = match index {
            Some(index) => index.low3()
            None => 4
          }
          let rex_x = match index {
            Some(index) => index.needs_rex_bit()
            None => false
          }
          {
            modrm: (mod_disp.mod_bits << 6) | (reg_bits << 3) | 4,
            sib: Some((scale << 6) | (index_bits << 3) | base.low3()),
            disp: memory.disp,
            disp_size: mod_disp.disp_size,
            rex_b: base.needs_rex_bit(),
            rex_x,
            force_rex: false,
            has_high8: false,
            segment: memory.segment,
          }
        } else {
          {
            modrm: (mod_disp.mod_bits << 6) | (reg_bits << 3) | base.low3(),
            sib: None,
            disp: memory.disp,
            disp_size: mod_disp.disp_size,
            rex_b: base.needs_rex_bit(),
            rex_x: false,
            force_rex: false,
            has_high8: false,
            segment: memory.segment,
          }
        }
      }
      None => {
        // No base uses the SIB base=101 form with a mandatory disp32.
        if !fits_i32(memory.disp) {
          raise MemoryDisplacementOutOfRange(memory.disp)
        }
        let index_bits = match index {
          Some(index) => index.low3()
          None => 4
        }
        let rex_x = match index {
          Some(index) => index.needs_rex_bit()
          None => false
        }
        {
          modrm: (reg_bits << 3) | 4,
          sib: Some((scale << 6) | (index_bits << 3) | 5),
          disp: memory.disp,
          disp_size: 4,
          rex_b: false,
          rex_x,
          force_rex: false,
          has_high8: false,
          segment: memory.segment,
        }
      }
    }
  }
}

///|
fn JITContext::emit_i8(self : JITContext, value : Int) -> Unit {
  self.emit_byte(value.to_byte())
}

///|
fn JITContext::emit_i16(self : JITContext, value : Int) -> Unit {
  for shift in [0, 8] {
    self.emit_byte(((value >> shift) & 0xFF).to_byte())
  }
}

///|
fn JITContext::emit_i8_i64(self : JITContext, value : Int64) -> Unit {
  self.emit_byte(value.to_byte())
}

///|
fn JITContext::emit_i32(self : JITContext, value : Int64) -> Unit {
  for shift in [0, 8, 16, 24] {
    self.emit_byte(((value >> shift) & 0xFFL).to_byte())
  }
}

///|
fn JITContext::emit_i64(self : JITContext, value : Int64) -> Unit {
  for shift in [0, 8, 16, 24, 32, 40, 48, 56] {
    self.emit_byte(((value >> shift) & 0xFFL).to_byte())
  }
}

///|
fn JITContext::emit_immediate(
  self : JITContext,
  immediate : Immediate,
) -> Unit raise ASMContextError {
  immediate.validate()
  match immediate {
    Imm8(value) => self.emit_i8(value)
    Imm16(value) => self.emit_i16(value)
    Imm32(value) => self.emit_i32(value)
    Imm64(value) => self.emit_i64(value)
  }
}

///|
/// Emit common prefixes in architectural order: segment, operand-size, REX.
///
/// REX is emitted only when needed, except that spl/bpl/sil/dil force a bare
/// REX prefix to select the low 8-bit register names.
fn JITContext::emit_prefixes(
  self : JITContext,
  width : Width,
  segment : Segment?,
  rex_w : Bool,
  rex_r : Bool,
  rex_x : Bool,
  rex_b : Bool,
  force_rex : Bool,
  has_high8 : Bool,
) -> Unit raise ASMContextError {
  let rex_needed = rex_w || rex_r || rex_x || rex_b || force_rex
  if has_high8 && rex_needed {
    raise High8RexConflict
  }
  match segment {
    Some(FS) => self.emit_byte(0x64)
    Some(GS) => self.emit_byte(0x65)
    None => ()
  }
  if width == W16 {
    self.emit_byte(0x66)
  }
  if rex_needed {
    self.emit_byte(
      (0x40 : Byte) |
      bool_byte(rex_w, 0x08) |
      bool_byte(rex_r, 0x04) |
      bool_byte(rex_x, 0x02) |
      bool_byte(rex_b, 0x01),
    )
  }
}

///|
fn JITContext::emit_encoded_rm(self : JITContext, encoded : EncodedRm) -> Unit {
  self.emit_byte(encoded.modrm)
  match encoded.sib {
    Some(sib) => self.emit_byte(sib)
    None => ()
  }
  match encoded.disp_size {
    0 => ()
    1 => self.emit_i8_i64(encoded.disp)
    4 => self.emit_i32(encoded.disp)
    _ => ()
  }
}

///|
fn JITContext::emit_reg_rm(
  self : JITContext,
  width : Width,
  opcode : Byte,
  reg_field : Register,
  rm : RmOperand,
  rex_w : Bool,
) -> Unit raise ASMContextError {
  let encoded = encode_rm(reg_field.low3(), rm)
  self.emit_prefixes(
    width,
    encoded.segment,
    rex_w,
    reg_field.needs_rex_bit(),
    encoded.rex_x,
    encoded.rex_b,
    reg_field.requires_rex_byte() || encoded.force_rex,
    reg_field.is_high8() || encoded.has_high8,
  )
  self.emit_byte(opcode)
  self.emit_encoded_rm(encoded)
}

///|
fn JITContext::emit_reg_rm_2(
  self : JITContext,
  width : Width,
  opcode1 : Byte,
  opcode2 : Byte,
  reg_field : Register,
  rm : RmOperand,
  rex_w : Bool,
) -> Unit raise ASMContextError {
  let encoded = encode_rm(reg_field.low3(), rm)
  self.emit_prefixes(
    width,
    encoded.segment,
    rex_w,
    reg_field.needs_rex_bit(),
    encoded.rex_x,
    encoded.rex_b,
    reg_field.requires_rex_byte() || encoded.force_rex,
    reg_field.is_high8() || encoded.has_high8,
  )
  self.emit_byte(opcode1)
  self.emit_byte(opcode2)
  self.emit_encoded_rm(encoded)
}

///|
fn JITContext::emit_group_rm(
  self : JITContext,
  width : Width,
  opcode : Byte,
  extension : Byte,
  rm : RmOperand,
  rex_w : Bool,
) -> Unit raise ASMContextError {
  let encoded = encode_rm(extension, rm)
  self.emit_prefixes(
    width,
    encoded.segment,
    rex_w,
    false,
    encoded.rex_x,
    encoded.rex_b,
    encoded.force_rex,
    encoded.has_high8,
  )
  self.emit_byte(opcode)
  self.emit_encoded_rm(encoded)
}

///|
fn JITContext::emit_opcode_register(
  self : JITContext,
  width : Width,
  opcode_base : Byte,
  register : Register,
  rex_w : Bool,
) -> Unit raise ASMContextError {
  self.emit_prefixes(
    width,
    None,
    rex_w,
    false,
    false,
    register.needs_rex_bit(),
    register.requires_rex_byte(),
    register.is_high8(),
  )
  self.emit_byte(opcode_base + register.low3())
}
