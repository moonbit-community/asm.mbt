# TODO

1. Validate all 32-bit encoded fields before emission.
   - Risk: `imm32`, memory displacements, RIP-relative displacements, and `call rel32` are written as 4 bytes without range checks. Out-of-range `Int` values can silently truncate and generate wrong machine code.
   - Call-specific task: make `JITContext::call` compute the final rel32 displacement before emitting, verify it fits signed 32-bit range, and raise a structured error without changing `bytes()` or `trace()` on failure.
   - Suggested fix: add signed/unsigned range helpers for each encoded field and raise structured `ASMContextError` variants before emitting bytes.

2. Make external symbol resolution fallible.
   - Risk: `JITContext::extern_fn` does not handle `dlopen` or `dlsym` failure. A missing symbol can become a bogus `Extern` target and later emit a call to an invalid address.
   - Suggested fix: return `Target?` or raise an explicit symbol-resolution error, and add tests for missing symbols.

3. Remove high-8 register sentinel ambiguity from memory helpers.
   - Risk: `mem8`/`mem16`/`mem32`/`mem64` use `ah` and `ch` as private sentinel defaults. Explicitly passing those invalid address registers can be treated as "argument omitted" instead of raising `InvalidMemoryBase` or `InvalidMemoryIndex`.
   - Suggested fix: prefer optional register parameters where possible, or use a sentinel representation that cannot collide with public register values.
