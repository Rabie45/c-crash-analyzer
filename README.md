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

## Install for OpenAI Codex (CLI)

Codex CLI is a shell-native coding agent, like Claude Code, so `scripts/symbolize.sh` runs as-is — no sandbox workaround needed. Codex has two extension points that map onto this skill:

**Option A — custom slash-command prompt (closest equivalent to a Claude Code skill):**

Codex CLI loads any Markdown file in `~/.codex/prompts/` as a `/name` slash command, with the file's body as the prompt.

```bash
mkdir -p ~/.codex/prompts
cp SKILL.md ~/.codex/prompts/c-crash-analyzer.md
cp -r REFERENCE.md scripts ~/.codex/skills-data/c-crash-analyzer/   # keep linked files alongside, referenced by relative/absolute path in the prompt
chmod +x ~/.codex/skills-data/c-crash-analyzer/scripts/symbolize.sh
```

Codex prompts don't do progressive disclosure the way Claude Code skills do (there's no separate "load on trigger" step — the whole prompt file is the command), so edit the copied `c-crash-analyzer.md` to point at the absolute path of `REFERENCE.md` and `scripts/symbolize.sh` you copied above, instead of the relative links used in this repo.

Invoke it inside a Codex CLI session with:
```
/c-crash-analyzer path/to/crashlog.txt
```

**Option B — project-wide instructions via `AGENTS.md`:**

Codex automatically reads `AGENTS.md` at your repo root (and `~/.codex/AGENTS.md` globally) as standing instructions for every session in that project — no explicit invocation needed. Append a pointer so Codex knows to apply this skill whenever it sees a crash log:

```bash
cat SKILL.md >> AGENTS.md   # or reference it: "See c-crash-analyzer/SKILL.md for crash log analysis steps"
```

Use Option A if you want an explicit, opt-in command; use Option B if you want Codex to apply this automatically anytime it's working in a repo with crash logs.

---

## Requirements

- `addr2line` (binutils) and/or `gdb` on PATH for symbolization
- Binary built with debug symbols (`-g`, ideally `-O0`) for anything beyond ASAN (which is already symbolized)
- Source tree access to read the actual crash-site code

