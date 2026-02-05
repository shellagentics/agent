# agen

## What Is This?

`agen` is to LLM inference what `curl` is to HTTP: a request primitive. It sends a prompt to an LLM and emits the response to stdout. This is infrastructure for [Unix Agentics](https://stratta.dev) — the thesis that agents should be files, processes, and streams, not chat interfaces.

```bash
cat error.log | agen "diagnose" | agen "suggest fix" > recommendations.md
```

## Shell Agentics

Part of the [Shell Agentics](https://github.com/shellagentics) toolkit - small programs that compose via pipes and text streams to build larger agentic structures using Unix primitives. No frameworks. No magic. Total observability.

When you or another agent want to know what an agent did, you check the execution trace. Every command, every decision, every timestamp is inspectable with Unix tools. It's all Unix and it's all in the shell.

## Installation

```bash
git clone https://github.com/shellagentics/agen.git
cd agen
./agen --help
```

No build step. Just bash.

## Backends

agen supports multiple LLM backends:

| Backend | Command | Cost | Best for |
|---------|---------|------|----------|
| `claude-code` | `claude` CLI | Max subscription | Daily use, no API costs |
| `llm` | `llm` CLI | API costs | Multi-provider flexibility |
| `api` | Direct curl | API costs | No dependencies |

Auto-detection tries them in order. Override with `--backend=` or `AGEN_BACKEND=`.

### Setup by backend

**Claude Code** (recommended for Max subscribers):
```bash
# Install Claude Code, then:
./agen "hello"  # auto-detects
```

**llm CLI**:
```bash
pip install llm
llm keys set anthropic  # or configure other providers
./agen --backend=llm "hello"
```

**Direct API**:
```bash
export ANTHROPIC_API_KEY="your-key"
./agen --backend=api "hello"
```

## Usage

```
agen [OPTIONS] [PROMPT]
command | agen [OPTIONS] [PROMPT]
```

### Working Options

| Option | Description |
|--------|-------------|
| `--help` | Show help message |
| `--version` | Show version |
| `--backend=BACKEND` | LLM backend: claude-code, llm, api, auto |
| `--model=MODEL` | Model to use (default: claude-sonnet-4-20250514) |
| `--system=STRING` | Inline system prompt |
| `--system-file=FILE` | System prompt from file |
| `--verbose` | Debug output on stderr |

### Design: Single-Shot by Choice

agen is deliberately a single-shot primitive: prompt in, response out. It does not implement tool-calling loops, state management, or multi-turn conversations. This is an architectural commitment, not a limitation.

In Shell Agentics, the orchestrating script controls the loop. The LLM is an oracle — it answers questions, it doesn't make decisions about tool use. Decisions live in auditable shell scripts. This provides a fundamentally different security posture: the LLM can suggest whatever it wants, but the skill script is the gatekeeper. See [shellclaw](https://github.com/shellagentics/shellclaw) for how this works in practice.

### Exit Codes

| Code | Meaning | Script Usage |
|------|---------|--------------|
| 0 | Success | `agen && echo "done"` |
| 1 | Failure | `agen \|\| echo "failed"` |

## Examples

### Simple Query

```bash
agen "Explain Unix pipes"
```

### Pipeline Usage

```bash
# Diagnose an error
cat error.log | agen "diagnose this error"

# Chain agents
cat data.csv | agen "summarize" | agen "format as markdown" > summary.md
```

### With System Prompt

```bash
# Inline system prompt
git diff | agen --system="You are a code reviewer. Be concise." "review these changes"

# System prompt from file (for agent soul files)
git diff | agen --system-file=SYSTEM.md "review these changes"
```

### Scripting

```bash
# Use in scripts with proper error handling
if cat report.txt | agen "summarize in one sentence"; then
  echo "Done"
else
  echo "Failed with exit code $?"
fi
```

## How It Works

agen constructs a prompt from layers:

```
┌─────────────────────────────────────┐
│ System prompt (--system/--system-file) │  ← Identity, rules
├─────────────────────────────────────┤
│ Input (stdin if piped)         │  ← Material to process
├─────────────────────────────────┤
│ Task (positional arguments)    │  ← What to do
└─────────────────────────────────┘
```

The layered prompt goes to the LLM. Response goes to stdout. Errors go to stderr.

This is the Unix way: stdin/stdout/stderr, composable with pipes, scriptable.

## Skills

Skills are shell scripts that orchestrate agen for specific workflows. Unlike prompt-based skills (Vision A), these are **programs that use the agent**.

See [agen-skills](https://github.com/shellagentics/agen-skills) for a collection of ready-to-use skills.

### The Pattern

```bash
#!/usr/bin/env bash
# A skill is just a script that calls agen

diff=$(git diff --cached)
result=$(echo "$diff" | agen --system=reviewer.md "review this")

if echo "$result" | grep -q "CRITICAL"; then
  echo "Blocking issues found"
  exit 1
fi
```

The shell orchestrates. agen is one tool among many.

## Directory Structure

```
agen/
├── agen                # Main CLI script (~350 lines bash)
├── test.sh             # Test suite
├── README.md           # This file
├── DEVLOG.md           # Development notes and decisions
├── CLAUDE.md           # AI assistant guide
└── prompts/            # Versioned prompts
    ├── README.md       # Prompt versioning guide
    └── BUILD_PROMPT.md # Build specification (v1.0.0)
```

## License

MIT
