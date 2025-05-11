///|
/// Legacy x86-64 general-purpose registers supported by this encoder.
///
/// The package currently handles the low eight integer registers only. R8-R15
/// need additional REX bits and are intentionally not represented yet.
enum Reg {
  RAX // Accumulator and implicit result register for arithmetic operations.
  RCX // Count register; the LOOP instruction decrements this register.
  RDX // Data register.
  RBX // Base register, commonly used as a general-purpose register.
  RSP // Current stack pointer.
  RBP // Base pointer / previous stack frame link.
  RSI // Source index pointer.
  RDI // Destination index pointer.
} derive(Debug)

///|
/// Return the three-bit register code used by ModR/M bytes and short opcodes.
fn Reg::index(self : Reg) -> Byte {
  match self {
    RAX => 0
    RCX => 1
    RDX => 2
    RBX => 3
    RSP => 4
    RBP => 5
    RSI => 6
    RDI => 7
  }
}
