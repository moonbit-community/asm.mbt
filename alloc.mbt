///|
/// Allocate writable and executable memory for generated machine code.
///
/// The default size is intentionally generous for small tests and examples.
/// The returned value is the start address that must be passed to
/// `ASMContext::new`.
pub fn alloc(mem_size? : UInt64 = 256UL * 1024UL) -> UInt64 {
  mmap(mem_size)
}
