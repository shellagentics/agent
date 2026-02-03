# agen

A Unix-native AI agent CLI that composes in pipelines.

## Philosophy

**Vision B: Agent in the Shell** — The agent is one tool among many. The shell orchestrates. Agents compose in pipelines.

```bash
cat error.log | agen "diagnose" | agen "suggest fix" > recommendations.md
```

This is infrastructure for [Unix Agentics](https://stratta.dev) — the thesis that agents should be files, processes, and streams, not chat interfaces.

## Installation

```bash
git clone https://github.com/markreveley/agen.git
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
| `--system=FILE` | System prompt file to prepend |
| `--verbose` | Debug output on stderr |

### Planned Options (not yet implemented)

| Option | Description |
|--------|-------------|
| `--batch` | No interactive prompts; exit 2 if input needed |
| `--json` | Output JSON instead of plain text |
| `--state=FILE` | State file for persistence/resume |
| `--resume` | Continue from state file |
| `--checkpoint` | Save state after completion |
| `--max-turns=N` | Maximum agentic loop iterations |
| `--tools=LIST` | Tools to enable (agentic mode) |

### Exit Codes

| Code | Meaning | Script Usage |
|------|---------|--------------|
| 0 | Success | `agen && echo "done"` |
| 1 | Failure | `agen \|\| echo "failed"` |
| 2 | Needs input | Retry with more context |
| 3 | Hit limit | Increase --max-turns |

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
# Create a domain-specific agent
cat > SYSTEM.md << 'EOF'
You are a code reviewer. Be concise and focus on bugs.
EOF

git diff | agen --system=SYSTEM.md "review these changes"
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
┌─────────────────────────────────┐
│ System prompt (--system=FILE)  │  ← Identity, rules
├─────────────────────────────────┤
│ Input (stdin if piped)         │  ← Material to process
├─────────────────────────────────┤
│ Task (positional arguments)    │  ← What to do
└─────────────────────────────────┘
```

The layered prompt goes to the LLM. Response goes to stdout. Errors go to stderr.

This is the Unix way: stdin/stdout/stderr, composable with pipes, scriptable.

## Skills

Skills are shell scripts that orchestrate agen for specific workflows.

```bash
./skills/ship              # commit with README check
./skills/review            # code review staged changes
git diff | ./skills/review # review piped diff
```

Unlike prompt-based skills (Vision A), these are **programs that use the agent**:

```bash
#!/usr/bin/env bash
# A skill is just a script that calls agen

diff=$(git diff --cached)
result=$(echo "$diff" | ./agen --system=reviewer.md "review this")

if echo "$result" | grep -q "CRITICAL"; then
  echo "Blocking issues found"
  exit 1
fi
```

See `skills/README.md` for the pattern.

## License

MIT
