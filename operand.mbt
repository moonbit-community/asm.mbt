///|
/// Operand forms accepted by the instruction helpers.
///
/// This is intentionally small: immediates are encoded as signed 32-bit values
/// and register operands are limited to the legacy registers in `Reg`.
pub(all) enum Operand {
  // A signed immediate encoded in little-endian imm32 form.
  Imm32(Int)
  // A register operand.
  Reg(Reg)
} derive(Debug)

///|
/// A position inside an `ASMContext` code buffer.
///
/// Labels store byte offsets, not absolute addresses, so they are only valid
/// for the context that created them.
struct Label {
  offset : Int
} derive(Debug)

///|
/// Destination accepted by `ASMContext::call`.
///
/// `Label` is an in-buffer target. `Extern` stores an offset from the current
/// code buffer start to an external function pointer so CALL can still emit a
/// relative displacement.
pub(all) enum Target {
  Label(Label)
  Extern(Int)
} derive(Debug)

///|
/// Convert a label into a call target.
pub fn Label::target(self : Label) -> Target {
  Label(self)
}

///|
/// Operand constant for the RAX register.
pub let rax : Operand = Reg(RAX)

///|
/// Operand constant for the RSI register.
pub let rsi : Operand = Reg(RSI)

///|
/// Operand constant for the RCX register.
pub let rcx : Operand = Reg(RCX)

///|
/// Operand constant for the RBP register.
pub let rbp : Operand = Reg(RBP)

///|
/// Operand constant for the RSP register.
pub let rsp : Operand = Reg(RSP)

///|
/// Operand constant for the RDI register.
pub let rdi : Operand = Reg(RDI)

///|
/// Operand constant for the RDX register.
pub let rdx : Operand = Reg(RDX)

///|
/// Operand constant for the RBX register.
pub let rbx : Operand = Reg(RBX)
