# Crash Pattern Reference

Use this to classify a segfault once you've symbolized the crash site. Match on the *signature* — the concrete evidence in the log or source — not just the vibe of the code.

## 1. Null pointer dereference

**Signature:**
- Crash address is `0x0` or very close to it (e.g. `0x0000000000000008` — a null struct pointer plus a small field offset)
- GDB: `Cannot access memory at address 0x8` or similar tiny address
- ASAN: `SEGV on unknown address 0x000000000000 ... The signal is caused by a READ/WRITE memory access.`

**Source check:** at the crash line, find the pointer being dereferenced (`->`, `*`, `[]`). Trace backward: was it checked for NULL after allocation/lookup (`malloc`, `find`, a function that can return NULL) before use?

**Typical fix:** add a NULL check after the allocation/lookup, or fix the code path that failed to initialize the pointer.

## 2. Use-after-free (UAF)

**Signature:**
- ASAN: `heap-use-after-free` explicitly, with two extra stack traces — "freed by thread ... here" and "previously allocated by ... here"
- Plain GDB: crash address looks like a valid heap pointer (not near 0) but the object's contents look like freed/poisoned memory, or a debug allocator has scribbled a pattern (e.g. `0xdeadbeef`, `0xfeeefeee` on some allocators)

**Source check:** find where the object was `free()`/`delete`d, then find the later access. Check for: pointer stored in multiple places (aliasing) without clearing all copies, callback/async use of a stack- or scope-local object after it went out of scope, container reallocation invalidating an iterator/pointer.

**Typical fix:** set pointer to NULL after free and check before use; fix ownership so free happens after last use; use RAII/smart pointers in C++ to tie lifetime to scope.

## 3. Heap/stack buffer overflow (out-of-bounds)

**Signature:**
- ASAN: `heap-buffer-overflow` or `stack-buffer-overflow`, with "READ/WRITE of size N at ... which is 0 bytes to the right/left of a M-byte region"
- Plain segfault: address is just past a legitimately-owned buffer, often after a loop or `memcpy`/`strcpy`/array index

**Source check:** find the index/pointer arithmetic or copy length. Check loop bounds (`<=` vs `<`), off-by-one on allocation size vs. usage size, unchecked external/user-controlled length or index, `strcpy`/`sprintf`/`memcpy` without a size check.

**Typical fix:** correct the bound (`<` not `<=`), use the safe/length-bounded variant (`snprintf`, `strncpy` with proper handling, `memcpy` with validated size), validate external input length before use.

## 4. Stack overflow (exhausted stack, not a buffer overflow)

**Signature:**
- Backtrace is extremely deep with the *same function repeating* (unbounded/uncontrolled recursion), or is truncated/corrupted because gdb can't unwind further
- Crash address is near the stack pointer (`sp`) boundary; dmesg line often shows `sp` very close to `ip` and a very large/odd fault address
- May show `*** stack smashing detected ***` (canary) only if a local buffer overflowed the frame, which is a different, more specific case — see pattern 3 but confined to a stack buffer

**Source check:** find the recursive function at the top of the repeating frames; look for a missing/incorrect base case, or an unbounded loop that keeps calling deeper, or a huge stack-allocated local (`char buf[huge]`, VLA) blowing the stack in one frame.

**Typical fix:** add/fix the recursion base case, convert to iteration, or move a large local buffer to the heap.

## 5. Dangling / wild pointer (uninitialized or already-invalid)

**Signature:**
- Crash address looks like garbage (not 0, not a plausible heap/stack address) — e.g. `0x41414141` (often literal `'A'` bytes — a strong hint the pointer was overwritten by a string/buffer overflow elsewhere) or another clearly bogus value
- No corresponding "freed by" trace in ASAN (rules out clean UAF) — the pointer was likely never validly set, or was clobbered by an unrelated overflow

**Source check:** is the pointer declared without initialization and used on a path that skips assignment? Is it a member of a struct that was never fully initialized (e.g. `malloc` without zeroing, partial constructor)? Cross-check pattern 3 — a wild pointer value is a classic symptom of a buffer overflow overwriting adjacent memory.

**Typical fix:** initialize pointers at declaration (`= NULL`), ensure all paths through a constructor/init function set every pointer member, fix the overflow if one is clobbering it.

## 6. Double free / heap corruption

**Signature:**
- Not always a SEGV at the point of the bad access — glibc/ASAN often aborts *inside* `free()`/`malloc()` itself
- ASAN: `attempting double-free` or `invalid-free`, with the allocation and (two) free stack traces
- glibc: `free(): double free detected in tcache 2` or `malloc(): invalid pointer`

**Source check:** find both free sites; usually one owner frees, and another owner (alias, container destructor, error-path cleanup) frees the same pointer again.

**Typical fix:** clear ownership — one clear owner frees once; set pointer to NULL after free so a second free is a no-op-safe check if guarded, or restructure ownership (unique_ptr in C++).

## Using ASAN's shadow legend

When ASAN prints a shadow byte map, it explicitly names the region kind (`Heap left/right redzone`, `Freed heap region`, `Stack left/right redzone`, `Shadow gap`). Prefer this explicit label over inferring the pattern from the address alone — it removes the guesswork for patterns 2, 3, and 6.
