# TODO

1. Handle executable memory allocation and buffer size failures.
   - Risk: `mmap` failure is not checked, and `alloc` returns the raw pointer directly. If allocation fails, `exec` can copy to and call an invalid address. `ASMContext` also does not know the allocated size, so generated code can overflow the mapping.
   - Suggested fix: make allocation fallible or raising, record allocation size in `ASMContext`, and reject `exec` when generated code exceeds the mapping.

2. Validate all 32-bit encoded fields before emission.
   - Risk: `imm32`, memory displacements, RIP-relative displacements, and `call rel32` are written as 4 bytes without range checks. Out-of-range `Int` values can silently truncate and generate wrong machine code.
   - Suggested fix: add signed/unsigned range helpers for each encoded field and raise structured `ASMContextError` variants before emitting bytes.

3. Make external symbol resolution fallible.
   - Risk: `ASMContext::extern_fn` does not handle `dlopen` or `dlsym` failure. A missing symbol can become a bogus `Extern` target and later emit a call to an invalid address.
   - Suggested fix: return `Target?` or raise an explicit symbol-resolution error, and add tests for missing symbols.

4. Remove high-8 register sentinel ambiguity from memory helpers.
   - Risk: `mem8`/`mem16`/`mem32`/`mem64` use `ah` and `ch` as private sentinel defaults. Explicitly passing those invalid address registers can be treated as "argument omitted" instead of raising `InvalidMemoryBase` or `InvalidMemoryIndex`.
   - Suggested fix: prefer optional register parameters where possible, or use a sentinel representation that cannot collide with public register values.
