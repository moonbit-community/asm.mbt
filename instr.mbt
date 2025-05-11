///|
/// Debug representation of the instructions emitted into an `ASMContext`.
///
/// The encoder records these values alongside raw bytes so tests and future
/// diagnostics can inspect the logical instruction stream without decoding
/// machine code back from memory.
enum Instr {
  Ret
  Mov(Operand, Operand)
  Add(Operand, Operand)
  Sub(Operand, Operand)
  Mul(Operand)
  IMul(Operand, Operand)
  Xor(Operand, Operand)
  Inc(Operand)
  Dec(Operand)
  Push(Operand)
  Pop(Operand)
  Call(Target)
  LoopRel8(Label)
  Nop
  Syscall
} derive(Debug)
