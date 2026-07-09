# c-crash-analyzer

A Claude Code / agent skill that analyzes C/C++ segmentation fault crash logs — GDB backtraces, `dmesg`/kernel oops lines, AddressSanitizer (ASAN) reports, and `systemd-coredump`/`coredumpctl` output — and turns them into a clear, actionable root-cause report: exact crash site, call chain, bug classification (null deref, use-after-free, buffer overflow, stack overflow, dangling pointer, double free), and a suggested fix.

## What it does

Given a crash log (and ideally the binary + source), it walks through:

1. Identifying the log format (GDB / dmesg / ASAN / coredump)
2. Symbolizing raw addresses to `file:line` (via `addr2line`/`gdb`, using the bundled `scripts/symbolize.sh`)
3. Reading the actual source at the crash site
4. Classifying the failure against a pattern catalog (see [REFERENCE.md](REFERENCE.md))
5. Reporting back: crash site → call chain → classification → root cause → suggested fix → confidence/gaps

See [SKILL.md](SKILL.md) for the full instruction set the agent follows.

## Repo layout

```
c-crash-analyzer/
├── SKILL.md            # Main instructions the agent loads on trigger
├── REFERENCE.md         # Crash pattern catalog (null deref, UAF, OOB, stack overflow, dangling ptr, double free)
├── scripts/
│   └── symbolize.sh     # addr2line/gdb wrapper: resolves addresses -> file:line
└── demo/
    ├── crash_demo.c      # Minimal null-deref reproduction
    ├── crashs.log        # Real coredumpctl report from running it
    └── README.md         # How to reproduce + expected analysis
```

---

## Demo

[`demo/`](demo) has a self-contained example: a linked-list lookup that
returns `NULL` on a miss, and a caller that dereferences it without
checking. Build and crash it yourself:

```bash
cd demo
gcc -g -O0 -o crash_demo crash_demo.c
./crash_demo
```

Or skip straight to the payoff — paste [`demo/crashs.log`](demo/crashs.log)
(a real `coredumpctl` report from this crash) into a Claude Code session
with this skill installed and watch it walk from stack trace to root cause
to fix. See [`demo/README.md`](demo/README.md) for the expected output.

---

## Install for Claude Code

Claude Code auto-loads any skill placed in `~/.claude/skills/<name>/` (personal, all projects) or `.claude/skills/<name>/` (project-local, shared via git). Only the `name` + `description` frontmatter of every skill is loaded up front; the full `SKILL.md` (and linked files) load only when triggered.

**Personal install (all your projects):**
```bash
git clone <this-repo-url> ~/.claude/skills/c-crash-analyzer
chmod +x ~/.claude/skills/c-crash-analyzer/scripts/symbolize.sh
```

**Project install (checked into a repo, shared with your team):**
```bash
git clone <this-repo-url> .claude/skills/c-crash-analyzer
chmod +x .claude/skills/c-crash-analyzer/scripts/symbolize.sh
git add .claude/skills/c-crash-analyzer
git commit -m "Add c-crash-analyzer skill"
```

No further configuration needed — Claude Code will trigger it automatically whenever you paste/attach a crash log, or you can invoke it explicitly:

```
/c-crash-analyzer @path/to/crashlog.txt
```

---

## Use with ChatGPT / GPT

ChatGPT doesn't have Claude Code's skill-loading mechanism (auto-triggered, progressively-disclosed instruction files with tool access), so there's no drop-in equivalent — but you can adapt the same instructions as a **Custom GPT**:

1. Go to **ChatGPT → Explore GPTs → Create**.
2. In **Instructions**, paste the contents of [`SKILL.md`](SKILL.md) (it's plain Markdown instructions, no Claude-specific syntax).
3. Under **Knowledge**, upload [`REFERENCE.md`](REFERENCE.md) so the GPT can retrieve the pattern catalog.
4. `scripts/symbolize.sh` won't run automatically — a stock GPT has no shell access. Two options:
   - Enable **Code Interpreter** in the GPT's capabilities and upload `symbolize.sh`; instruct the GPT (in the Instructions box) to use Code Interpreter's shell to run it against an uploaded binary.
   - Or drop the script and instead tell the GPT to walk you through running `addr2line`/`gdb` yourself and pasting the output back in — this is the more reliable fallback since Code Interpreter's sandbox may not have `addr2line`/`gdb` preinstalled or your binary's exact architecture support.
5. Save, and use it by pasting/uploading your crash log in a chat with that GPT.

This gets you equivalent *instructions and knowledge*, but not the automatic trigger-on-paste behavior or native shell execution Claude Code gives you out of the box.

---

## Requirements

- `addr2line` (binutils) and/or `gdb` on PATH for symbolization
- Binary built with debug symbols (`-g`, ideally `-O0`) for anything beyond ASAN (which is already symbolized)
- Source tree access to read the actual crash-site code

