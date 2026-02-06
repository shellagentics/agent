# agent

## What Is This?

`agent` is a Unix primitive for LLM inference — stdin in, stdout out, nothing else. `agent` is to LLM inference what `curl` is to HTTP: a request primitive. It sends a prompt to an LLM and emits the response to stdout. This is infrastructure for [Shell Agentics](https://github.com/shellagentics/shell-agentics) — the thesis that agents should be files, processes, and streams, not chat interfaces.

```bash
cat error.log | agent "diagnose" | agent "suggest fix" > recommendations.md
```

## Shell Agentics

Part of the [Shell Agentics](https://github.com/shellagentics/shell-agentics) toolkit - small programs that compose via pipes and text streams to build larger agentic structures using Unix primitives. No frameworks. No magic. Total observability.

## Installation

```bash
git clone https://github.com/shellagentics/agent.git
cd agent
./agent --help
```

No build step. Just bash.

## Backends

agent supports multiple LLM backends:

| Backend | Command | Cost | Best for |
|---------|---------|------|----------|
| `claude-code` | `claude` CLI | Max subscription | Daily use, no API costs |
| `llm` | `llm` CLI | API costs | Multi-provider flexibility |
| `api` | Direct curl | API costs | No dependencies |
| `stub` | None | Free | Testing, demos, development |

Auto-detection tries them in order. Override with `--backend=` or `AGENT_BACKEND=`.

### Setup by backend

**Claude Code** (recommended for Max subscribers):
```bash
# Install Claude Code, then:
./agent "hello"  # auto-detects
```

**llm CLI**:
```bash
pip install llm
llm keys set anthropic  # or configure other providers
./agent --backend=llm "hello"
```

**Direct API**:
```bash
export ANTHROPIC_API_KEY="your-key"
./agent --backend=api "hello"
```

## Usage

```
agent [OPTIONS] [PROMPT]
command | agent [OPTIONS] [PROMPT]
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

agent is deliberately a single-shot primitive: prompt in, response out. It does not implement tool-calling loops, state management, or multi-turn conversations. This is an architectural commitment rooted in observability and control flow legibility.

#### How most agent frameworks handle tool calling

You define tools as JSON schemas and send them alongside a prompt. The LLM may respond with structured tool-call requests — JSON specifying the tool name and arguments. The framework's dispatch loop executes the requested tool, feeds the result back into the conversation context, and calls the LLM again. This continues until the LLM responds with text instead of a tool call. The tool-calling loop, the dispatch logic, and the execution sequence all live inside the framework process.

#### How Shell Agentics handles tool calling

The orchestrating script calls `agent` to get a response. When the LLM returns a structured tool-call request (JSON with a tool name and arguments), the script parses it and matches the tool name against a `case` statement — an explicit allowlist of permitted tools. Only tools listed in the `case` execute. Unmatched requests fall through. This is default-deny dispatch.

```bash
case "$tool" in
  ping)    result=$("$TOOLS_DIR/ping.sh" "$args") ;;
  curl)    result=$("$TOOLS_DIR/curl.sh" "$args") ;;
  *)       result="Tool not permitted: $tool" ;;
esac
```

#### Observability and control flow legibility

This architecture provides two complementary properties.

**Observability.** Every tool invocation is a visible line in the script. The execution trace — which tools ran, with what arguments, in what order — is available through standard Unix mechanisms: `set -x` traces every command, [`alog`](https://github.com/shellagentics/alog) records structured events, process output flows through pipes. Logging, conditional pauses, and additional checks can be inserted between any steps.

**Control flow legibility.** The script is a readable artifact that exists before runtime. `cat agent-1.sh` shows every tool that could run and under what conditions. The `case` statement is auditable as a specification — you can read it and know with certainty which tools are permitted. This legibility is diffable, git-blameable, and reviewable in a pull request. It describes what *can* happen, not just what *did* happen.

When the agentic loop lives in the shell script, both properties are present: you can observe what happened, and you can read what can happen. See [shellclaw/agents/agent-1.sh](https://github.com/shellagentics/shellclaw/blob/main/agents/agent-1.sh) for the pattern.

### Exit Codes

| Code | Meaning | Script Usage |
|------|---------|--------------|
| 0 | Success | `agent && echo "done"` |
| 1 | Failure | `agent \|\| echo "failed"` |

## Examples

### Simple Query

```bash
agent "Explain Unix pipes"
```

### Pipeline Usage

```bash
# Diagnose an error
cat error.log | agent "diagnose this error"

# Chain agents
cat data.csv | agent "summarize" | agent "format as markdown" > summary.md
```

### With System Prompt

```bash
# Inline system prompt
git diff | agent --system="You are a code reviewer. Be concise." "review these changes"

# System prompt from file (for agent soul files)
git diff | agent --system-file=SYSTEM.md "review these changes"
```

### Scripting

```bash
# Use in scripts with proper error handling
if cat report.txt | agent "summarize in one sentence"; then
  echo "Done"
else
  echo "Failed with exit code $?"
fi
```

## How It Works

agent constructs a prompt from layers:

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

## Stub Backend

The `stub` backend returns `"LLM return N"` with an incrementing counter. No LLM calls are made. This makes the entire toolkit runnable without API keys or subscriptions — useful for testing, demos, and understanding the architecture.

```bash
# Run with stub backend
AGENT_BACKEND=stub agent "hello"       # → "LLM return 1"
AGENT_BACKEND=stub agent "hello again" # → "LLM return 2"

# Reset the counter
rm /tmp/agent-stub-counter

# Custom counter file
AGENT_STUB_FILE=/tmp/my-counter AGENT_BACKEND=stub agent "test"
```

## Directory Structure

```
agent/
├── agent               # Main CLI script (~350 lines bash)
├── test.sh             # Test suite
├── README.md           # This file
├── DEVLOG.md           # Development notes and decisions
└── CLAUDE.md           # AI assistant guide (coding conventions)
```

## License

MIT
