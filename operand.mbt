///|
/// Segment override supported by 64-bit integer memory operands.
pub(all) enum Segment {
  FS
  GS
} derive(Debug, Eq)

///|
/// Immediate operand with an explicit encoded width.
pub(all) enum Immediate {
  Imm8(Int)
  Imm16(Int)
  Imm32(Int)
  Imm64(Int64)
} derive(Debug, Eq)

///|
/// ModR/M + optional SIB memory operand.
///
/// `base` and `index` are 64-bit address registers when present. `rip_relative`
/// selects the special 64-bit mode `[rip + disp32]` encoding and ignores
/// `base`, `index`, and `scale`.
pub(all) struct Memory {
  size : Width
  base : Register?
  index : Register?
  scale : Int
  disp : Int
  segment : Segment?
  rip_relative : Bool
} derive(Debug, Eq)

///|
/// Relative target operand reserved for instruction forms that encode relative
/// immediates.
pub(all) enum RelTarget {
  RelLabel(Label)
  Rel32(Int)
} derive(Debug, Eq)

///|
/// Operand forms accepted by instruction helpers.
pub(all) enum Operand {
  Reg(Register)
  Imm(Immediate)
  Mem(Memory)
  Rel(RelTarget)
} derive(Debug, Eq)

///|
/// A position inside an `ASMContext` code buffer.
///
/// Labels store byte offsets, not absolute addresses, so they are only valid
/// for the context that created them.
struct Label {
  offset : Int
} derive(Debug, Eq)

///|
/// Destination accepted by `ASMContext::call`.
///
/// `Label` is an in-buffer target. `Extern` stores an offset from the current
/// code buffer start to an external function pointer so CALL can still emit a
/// relative displacement.
pub(all) enum Target {
  Label(Label)
  Extern(Int)
} derive(Debug, Eq)

///|
/// Convert a label into a call target.
pub fn Label::target(self : Label) -> Target {
  Label(self)
}

///|
/// Wrap a register value as an instruction operand.
///
/// Register constants such as `rax`, `eax`, `r8`, and `r8b` are plain
/// `Register` values, so instruction calls use `reg(rax)` when a register
/// operand is needed.
pub fn reg(register : Register) -> Operand {
  Reg(register)
}

///|
/// Build an 8-bit immediate operand.
///
/// The encoder accepts signed 8-bit values and byte-sized unsigned literals
/// in the range `0..255`; out-of-range values raise `ImmediateOutOfRange`.
pub fn imm8(value : Int) -> Operand {
  Imm(Imm8(value))
}

///|
/// Build a 16-bit immediate operand.
///
/// Values must fit in the 16-bit encoded field used by the selected
/// instruction form.
pub fn imm16(value : Int) -> Operand {
  Imm(Imm16(value))
}

///|
/// Build a 32-bit immediate operand.
///
/// Many 64-bit integer instructions encode `imm32` and sign-extend it to the
/// operand width, matching the x86-64 instruction tables.
pub fn imm32(value : Int) -> Operand {
  Imm(Imm32(value))
}

///|
/// Build a 64-bit immediate operand.
///
/// This is primarily used by `mov r64, imm64`; most other integer instruction
/// forms do not have an `imm64` encoding.
pub fn imm64(value : Int64) -> Operand {
  Imm(Imm64(value))
}

///|
fn memory(
  size : Width,
  base : Register?,
  index : Register?,
  scale : Int,
  disp : Int,
  segment : Segment?,
  rip_relative : Bool,
) -> Operand {
  Mem(Memory::{ size, base, index, scale, disp, segment, rip_relative })
}

///|
/// Build an explicit-width memory operand.
///
/// `base` and `index` must be 64-bit GPRs when present. `scale` must be one of
/// `1`, `2`, `4`, or `8`. Use the width-specific helpers (`mem8`, `mem16`,
/// `mem32`, `mem64`) for the common forms.
pub fn mem(
  size~ : Width,
  base? : Register? = None,
  index? : Register? = None,
  scale? : Int = 1,
  disp? : Int = 0,
  segment? : Segment? = None,
) -> Operand {
  memory(size, base, index, scale, disp, segment, false)
}

///|
/// Convert the public width-specific helper defaults into optional registers.
///
/// MoonBit optional labeled arguments cannot use `None` for a non-optional
/// `Register` parameter, so the public helpers use private sentinel defaults
/// and translate them here before encoding.
fn optional_memory_register(
  register : Register,
  sentinel : High8Reg,
) -> Register? {
  match (register, sentinel) {
    (High8(AH), AH) => None
    (High8(CH), CH) => None
    _ => Some(register)
  }
}

///|
/// Build an 8-bit memory operand such as `[rax + rdx * 4 - 8]`.
///
/// Omitting both `base` and `index` encodes an absolute disp32 memory operand.
pub fn mem8(
  base? : Register = High8(AH),
  index? : Register = High8(CH),
  scale? : Int = 1,
  disp? : Int = 0,
  segment? : Segment? = None,
) -> Operand {
  memory(
    W8,
    optional_memory_register(base, AH),
    optional_memory_register(index, CH),
    scale,
    disp,
    segment,
    false,
  )
}

///|
/// Build a 16-bit memory operand.
///
/// This controls the data width, not the address width; addresses are still
/// 64-bit mode addresses.
pub fn mem16(
  base? : Register = High8(AH),
  index? : Register = High8(CH),
  scale? : Int = 1,
  disp? : Int = 0,
  segment? : Segment? = None,
) -> Operand {
  memory(
    W16,
    optional_memory_register(base, AH),
    optional_memory_register(index, CH),
    scale,
    disp,
    segment,
    false,
  )
}

///|
/// Build a 32-bit memory operand.
pub fn mem32(
  base? : Register = High8(AH),
  index? : Register = High8(CH),
  scale? : Int = 1,
  disp? : Int = 0,
  segment? : Segment? = None,
) -> Operand {
  memory(
    W32,
    optional_memory_register(base, AH),
    optional_memory_register(index, CH),
    scale,
    disp,
    segment,
    false,
  )
}

///|
/// Build a 64-bit memory operand.
///
/// Examples include `mem64(base=rax)`, `mem64(base=rbp, disp=-8)`, and
/// `mem64(base=rax, index=r12, scale=4, disp=8)`.
pub fn mem64(
  base? : Register = High8(AH),
  index? : Register = High8(CH),
  scale? : Int = 1,
  disp? : Int = 0,
  segment? : Segment? = None,
) -> Operand {
  memory(
    W64,
    optional_memory_register(base, AH),
    optional_memory_register(index, CH),
    scale,
    disp,
    segment,
    false,
  )
}

///|
/// Build an 8-bit RIP-relative memory operand.
pub fn rip8(disp : Int, segment? : Segment? = None) -> Operand {
  memory(W8, None, None, 1, disp, segment, true)
}

///|
/// Build a 16-bit RIP-relative memory operand.
pub fn rip16(disp : Int, segment? : Segment? = None) -> Operand {
  memory(W16, None, None, 1, disp, segment, true)
}

///|
/// Build a 32-bit RIP-relative memory operand.
pub fn rip32(disp : Int, segment? : Segment? = None) -> Operand {
  memory(W32, None, None, 1, disp, segment, true)
}

///|
/// Build a 64-bit RIP-relative memory operand.
///
/// RIP-relative memory always uses the ModR/M `mod=00 r/m=101` form with a
/// disp32 field in 64-bit mode.
pub fn rip64(disp : Int, segment? : Segment? = None) -> Operand {
  memory(W64, None, None, 1, disp, segment, true)
}
