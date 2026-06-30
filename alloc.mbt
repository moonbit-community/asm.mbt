///|
let default_exec_memory_size : UInt64 = 256UL * 1024UL

///|
priv struct ExecutableAllocation {
  start : UInt64
  size : UInt64
}

///|
let executable_allocations : Array[ExecutableAllocation] = []

///|
fn remember_executable_allocation(start : UInt64, size : UInt64) -> Unit {
  executable_allocations.push({ start, size })
}

///|
fn executable_allocation_size(start : UInt64) -> UInt64? {
  for allocation in executable_allocations {
    if allocation.start == start {
      return Some(allocation.size)
    }
  }
  None
}

///|
/// Allocate writable and executable memory for generated machine code.
///
/// The default size is intentionally generous for small tests and examples.
/// The returned value is the start address that must be passed to
/// `ASMContext::new`. Allocation failure raises `ASMContextError`.
pub fn alloc(
  mem_size? : UInt64 = default_exec_memory_size,
) -> UInt64 raise ASMContextError {
  let start = mmap(mem_size)
  remember_executable_allocation(start, mem_size)
  start
}
