///|
/// Integer operand width used by registers, immediates, and memory operands.
pub(all) enum Width {
  W8
  W16
  W32
  W64
} derive(Debug, Eq)

///|
/// The 16 x86-64 general-purpose register bases.
pub(all) enum GprBase {
  A
  C
  D
  B
  SP
  BP
  SI
  DI
  R8
  R9
  R10
  R11
  R12
  R13
  R14
  R15
} derive(Debug, Eq)

///|
/// Legacy high 8-bit register names. These cannot be encoded in instructions
/// that require any REX prefix.
pub(all) enum High8Reg {
  AH
  CH
  DH
  BH
} derive(Debug, Eq)

///|
/// x86-64 integer register operand.
pub(all) enum Register {
  Gpr(GprBase, Width)
  High8(High8Reg)
} derive(Debug, Eq)

///|
fn GprBase::low3(self : GprBase) -> Byte {
  match self {
    A | R8 => 0
    C | R9 => 1
    D | R10 => 2
    B | R11 => 3
    SP | R12 => 4
    BP | R13 => 5
    SI | R14 => 6
    DI | R15 => 7
  }
}

///|
fn GprBase::needs_rex_bit(self : GprBase) -> Bool {
  match self {
    R8 | R9 | R10 | R11 | R12 | R13 | R14 | R15 => true
    _ => false
  }
}

///|
fn GprBase::is_base_pointer_encoding(self : GprBase) -> Bool {
  match self {
    BP | R13 => true
    _ => false
  }
}

///|
fn Register::width(self : Register) -> Width {
  match self {
    Gpr(_, width) => width
    High8(_) => W8
  }
}

///|
fn Register::low3(self : Register) -> Byte {
  match self {
    Gpr(base, _) => base.low3()
    High8(AH) => 4
    High8(CH) => 5
    High8(DH) => 6
    High8(BH) => 7
  }
}

///|
fn Register::needs_rex_bit(self : Register) -> Bool {
  match self {
    Gpr(base, _) => base.needs_rex_bit()
    High8(_) => false
  }
}

///|
fn Register::requires_rex_byte(self : Register) -> Bool {
  match self {
    Gpr(SP | BP | SI | DI, W8) => true
    Gpr(base, _) => base.needs_rex_bit()
    High8(_) => false
  }
}

///|
fn Register::is_high8(self : Register) -> Bool {
  match self {
    High8(_) => true
    _ => false
  }
}

///|
fn Register::as_gpr_base(self : Register) -> GprBase? {
  match self {
    Gpr(base, _) => Some(base)
    High8(_) => None
  }
}

///|
fn Register::is_address_register(self : Register) -> Bool {
  match self {
    Gpr(_, W64) => true
    _ => false
  }
}

// Public register constants use Intel names and are plain `Register` values.
// Wrap them with `reg(...)` when passing them to instruction helpers.

///|
pub let rax : Register = Gpr(A, W64)

///|
pub let eax : Register = Gpr(A, W32)

///|
pub let ax : Register = Gpr(A, W16)

///|
pub let al : Register = Gpr(A, W8)

///|
pub let rcx : Register = Gpr(C, W64)

///|
pub let ecx : Register = Gpr(C, W32)

///|
pub let cx : Register = Gpr(C, W16)

///|
pub let cl : Register = Gpr(C, W8)

///|
pub let rdx : Register = Gpr(D, W64)

///|
pub let edx : Register = Gpr(D, W32)

///|
pub let dx : Register = Gpr(D, W16)

///|
pub let dl : Register = Gpr(D, W8)

///|
pub let rbx : Register = Gpr(B, W64)

///|
pub let ebx : Register = Gpr(B, W32)

///|
pub let bx : Register = Gpr(B, W16)

///|
pub let bl : Register = Gpr(B, W8)

///|
pub let rsp : Register = Gpr(SP, W64)

///|
pub let esp : Register = Gpr(SP, W32)

///|
pub let sp : Register = Gpr(SP, W16)

///|
pub let spl : Register = Gpr(SP, W8)

///|
pub let rbp : Register = Gpr(BP, W64)

///|
pub let ebp : Register = Gpr(BP, W32)

///|
pub let bp : Register = Gpr(BP, W16)

///|
pub let bpl : Register = Gpr(BP, W8)

///|
pub let rsi : Register = Gpr(SI, W64)

///|
pub let esi : Register = Gpr(SI, W32)

///|
pub let si : Register = Gpr(SI, W16)

///|
pub let sil : Register = Gpr(SI, W8)

///|
pub let rdi : Register = Gpr(DI, W64)

///|
pub let edi : Register = Gpr(DI, W32)

///|
pub let di : Register = Gpr(DI, W16)

///|
pub let dil : Register = Gpr(DI, W8)

///|
pub let r8 : Register = Gpr(R8, W64)

///|
pub let r8d : Register = Gpr(R8, W32)

///|
pub let r8w : Register = Gpr(R8, W16)

///|
pub let r8b : Register = Gpr(R8, W8)

///|
pub let r9 : Register = Gpr(R9, W64)

///|
pub let r9d : Register = Gpr(R9, W32)

///|
pub let r9w : Register = Gpr(R9, W16)

///|
pub let r9b : Register = Gpr(R9, W8)

///|
pub let r10 : Register = Gpr(R10, W64)

///|
pub let r10d : Register = Gpr(R10, W32)

///|
pub let r10w : Register = Gpr(R10, W16)

///|
pub let r10b : Register = Gpr(R10, W8)

///|
pub let r11 : Register = Gpr(R11, W64)

///|
pub let r11d : Register = Gpr(R11, W32)

///|
pub let r11w : Register = Gpr(R11, W16)

///|
pub let r11b : Register = Gpr(R11, W8)

///|
pub let r12 : Register = Gpr(R12, W64)

///|
pub let r12d : Register = Gpr(R12, W32)

///|
pub let r12w : Register = Gpr(R12, W16)

///|
pub let r12b : Register = Gpr(R12, W8)

///|
pub let r13 : Register = Gpr(R13, W64)

///|
pub let r13d : Register = Gpr(R13, W32)

///|
pub let r13w : Register = Gpr(R13, W16)

///|
pub let r13b : Register = Gpr(R13, W8)

///|
pub let r14 : Register = Gpr(R14, W64)

///|
pub let r14d : Register = Gpr(R14, W32)

///|
pub let r14w : Register = Gpr(R14, W16)

///|
pub let r14b : Register = Gpr(R14, W8)

///|
pub let r15 : Register = Gpr(R15, W64)

///|
pub let r15d : Register = Gpr(R15, W32)

///|
pub let r15w : Register = Gpr(R15, W16)

///|
pub let r15b : Register = Gpr(R15, W8)

// Legacy high 8-bit names. They remain useful for byte instructions, but they
// cannot appear in an instruction that also needs a REX prefix.

///|
pub let ah : Register = High8(AH)

///|
pub let ch : Register = High8(CH)

///|
pub let dh : Register = High8(DH)

///|
pub let bh : Register = High8(BH)
