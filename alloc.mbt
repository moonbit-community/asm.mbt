///|
let default_exec_memory_size : UInt64 = 256UL * 1024UL

///|
/// Allocate writable memory for one JIT context.
fn allocate_jit_memory(mem_size : UInt64) -> UInt64 raise ASMContextError {
  mmap(mem_size)
}
