# Demo: null-pointer dereference

`crash_demo.c` is a minimal reproduction of a classic bug: a function that
looks up a node in a linked list, doesn't find it, returns `NULL`, and the
caller dereferences the result without checking.

## Reproduce it

```bash
gcc -g -O0 -o crash_demo crash_demo.c
./crash_demo
# Segmentation fault (core dumped)
```

If your system has `systemd-coredump` enabled, grab the crash report with:

```bash
coredumpctl gdb crash_demo
# or, for the full report used in crashs.log:
coredumpctl info crash_demo
```

`crashs.log` is a real coredump report captured this way — paste it (or a
GDB `bt full`, ASAN report, or dmesg oops line) to trigger the
`c-crash-analyzer` skill.

## Expected analysis

Given `crashs.log`, the skill should identify:

- **Crash site:** `use_node()` at `crash_demo.c:23`, dereferencing `n->value` where `n == 0x0`
- **Call chain:** `main` → `process_list` (`crash_demo.c:28`) → `use_node` (`crash_demo.c:23`)
- **Root cause:** `find_node()` returns `NULL` when `target` isn't in the list (`crash_demo.c:18`); `process_list()` passes that result straight into `use_node()` with no NULL check (`crash_demo.c:27-28`)
- **Classification:** NULL pointer dereference
- **Suggested fix:** check `found != NULL` in `process_list()` before calling `use_node()`, e.g.:

```c
int process_list(node_t *head, int target) {
    node_t *found = find_node(head, target);
    if (!found) {
        return -1; /* or however the caller signals "not found" */
    }
    return use_node(found);
}
```
