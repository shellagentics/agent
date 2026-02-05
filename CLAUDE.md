# CLAUDE.md - AI Assistant Guide for `agen`

## Project Overview

**agen** is a Unix-native CLI tool that embodies "Vision B: Agent in the Shell" - where AI agents compose in pipelines as one tool among many, rather than replacing the shell entirely.

```bash
# The Unix way: agents compose in pipelines
cat error.log | agen "diagnose" | agen "suggest fix" > recommendations.md
```

## Why Bash

1. **Zero dependencies** - runs anywhere with bash, curl, jq
2. **Forces simplicity** - can't over-engineer in bash
3. **Transparency** - anyone can read the source in 5 minutes
4. **Unix credibility** - the tool embodies the philosophy it advocates

This is Phase 1 of a larger vision. Bash proves the interface contract.

## Directory Structure

```
agen/
├── agen               # Main CLI script (~300 lines bash)
├── test.sh            # Test suite
├── README.md          # User documentation
├── DEVLOG.md          # Development notes and decisions
├── CLAUDE.md          # This file - AI assistant guide
└── .git/              # One commit per phase
```

## Interface Contract

### Synopsis

```
agen [OPTIONS] [PROMPT]
command | agen [OPTIONS] [PROMPT]
```

### Options

| Option | Description |
|--------|-------------|
| `--help` | Show help message |
| `--version` | Show version |
| `--batch` | No interactive prompts; exit 2 if input needed |
| `--json` | Output JSON instead of plain text |
| `--state=FILE` | State file for persistence/resume |
| `--resume` | Continue from state file |
| `--checkpoint` | Save state after completion |
| `--max-turns=N` | Maximum agentic loop iterations (default: 1) |
| `--tools=LIST` | Tools to enable (default: none). Available: bash |
| `--model=MODEL` | Model to use (default: claude-sonnet-4-20250514) |
| `--verbose` | Debug output on stderr |

### Exit Codes

| Code | Name | Meaning | Usage |
|------|------|---------|-------|
| 0 | SUCCESS | Task completed | `agen && echo "done"` |
| 1 | FAILURE | Error occurred | `agen \|\| echo "failed"` |
| 2 | NEEDS_INPUT | Human input required (batch mode) | Retry with more context |
| 3 | LIMIT | Hit max-turns | Increase limit or checkpoint |

### State File Format

```json
{
  "version": "1",
  "created_at": "2026-01-22T10:30:00Z",
  "updated_at": "2026-01-22T10:35:00Z",
  "model": "claude-sonnet-4-20250514",
  "messages": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ],
  "tools_enabled": ["bash"],
  "turn_count": 3,
  "status": "completed"
}
```

## Development Phases

| Phase | Name | What It Adds | Key Test |
|-------|------|--------------|----------|
| 0 | Interface Contract | `--help`, `--version` only | Help text displays |
| 1 | Basic Flow | stdin → LLM → stdout | `echo "hi" \| agen "respond"` works |
| 2 | Exit Semantics | `--batch`, exit codes 0/1/2 | Script can `case $?` |
| 3 | State | `--state`, `--resume` | Multi-turn conversation persists |
| 4 | Agentic Loop | `--tools=bash`, `--max-turns` | Agent creates a file |
| 5 | Checkpoint | `--checkpoint` with metadata | State includes timestamps |

Each phase produces a tested commit with message format: `"Phase N: Description"`

## Bash Coding Conventions

### Script Header

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION="0.3.0"
DEFAULT_MODEL="claude-sonnet-4-20250514"

# Exit codes as named constants
EXIT_SUCCESS=0
EXIT_FAILURE=1
```

### Argument Parsing Pattern

```bash
while [[ $# -gt 0 ]]; do
  case $1 in
    --help)
      show_help
      exit 0
      ;;
    --batch)
      BATCH_MODE=true
      shift
      ;;
    --state=*)
      STATE_FILE="${1#*=}"
      shift
      ;;
    --*)
      die "Unknown option: $1"
      ;;
    *)
      PROMPT="$1"
      shift
      ;;
  esac
done
```

### Utility Functions

```bash
log() {
  if [[ "$VERBOSE" == true ]]; then
    echo "[agen] $*" >&2
  fi
}

die() {
  echo "agen: $*" >&2
  exit $EXIT_FAILURE
}

check_dependencies() {
  local missing=()
  command -v curl >/dev/null || missing+=(curl)
  command -v jq >/dev/null || missing+=(jq)

  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing dependencies: ${missing[*]}"
  fi
}
```

### API Calls

```bash
call_api() {
  local user_content="$1"

  local request_body
  request_body=$(jq -n \
    --arg model "$MODEL" \
    --arg content "$user_content" \
    '{model: $model, max_tokens: 4096, messages: [{role: "user", content: $content}]}')

  local response
  response=$(curl -s "https://api.anthropic.com/v1/messages" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d "$request_body")

  # Check for API error
  if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
    die "API error: $(echo "$response" | jq -r '.error.message')"
  fi

  echo "$response" | jq -r '.content[0].text'
}
```

## Testing Conventions

### Test Harness Pattern

```bash
TESTS_RUN=0
TESTS_PASSED=0

test_case() {
  local name="$1"
  local expected_exit="$2"
  shift 2

  TESTS_RUN=$((TESTS_RUN + 1))

  set +e
  "$@" >/dev/null 2>&1
  local actual_exit=$?
  set -e

  if [[ $actual_exit -eq $expected_exit ]]; then
    echo "✓ $name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "✗ $name (expected $expected_exit, got $actual_exit)"
  fi
}

# Usage
test_case "--help exits 0" 0 ./agen --help
test_case "missing API key exits 1" 1 env -u ANTHROPIC_API_KEY ./agen "test"
```

### Test Summary

```bash
echo ""
echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"
[[ $TESTS_PASSED -eq $TESTS_RUN ]] && exit 0 || exit 1
```

## Common Mistakes to Avoid

### JSON Parsing

```bash
# BAD: Fragile grep/sed
response=$(echo "$json" | grep -o '"text":"[^"]*"' | cut -d'"' -f4)

# GOOD: Use jq
response=$(echo "$json" | jq -r '.content[0].text')
```

### Variable Quoting

```bash
# BAD: Word splitting breaks on spaces
if [[ $user_input == "" ]]; then

# GOOD: Always quote
if [[ "$user_input" == "" ]]; then
```

### API Error Handling

```bash
# BAD: Assumes success
response=$(curl -s "$URL" -d "$body")
echo "$response" | jq -r '.content[0].text'

# GOOD: Check for error first
response=$(curl -s "$URL" -d "$body")
if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
  die "API error: $(echo "$response" | jq -r '.error.message')"
fi
echo "$response" | jq -r '.content[0].text'
```

### Script Location

```bash
# BAD: Assumes current directory
source ./utils.sh

# GOOD: Relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
```

## Dependencies

- **bash 4+** - for associative arrays and modern features
- **curl** - for HTTP requests to Anthropic API
- **jq** - for JSON parsing and construction
- **ANTHROPIC_API_KEY** - environment variable with API key

## Quick Reference

```
USAGE
  agen [OPTIONS] [PROMPT]
  command | agen [OPTIONS] [PROMPT]

EXIT CODES
  0 = success    1 = failure    2 = needs input    3 = hit limit

KEY PATTERNS
  Stateless:     cat log | agen "diagnose"
  Stateful:      agen --state=s.json "start" → agen --state=s.json --resume "continue"
  Agentic:       agen --tools=bash --max-turns=5 "do complex task"
  Scripted:      cat data | agen --batch && echo "ok" || echo "failed: $?"
```

## For AI Assistants

When working on this codebase:

1. **Follow the phase structure** - Build incrementally, one phase at a time
2. **Test before committing** - Each phase must pass its tests
3. **Use named exit codes** - Never hardcode exit numbers
4. **Prefer jq for JSON** - Never parse JSON with grep/sed
5. **Always quote variables** - Prevent word splitting issues
6. **Check API errors** - Never assume API calls succeed
7. **Write to stderr for logging** - stdout is for output only
8. **Update DEVLOG.md** - Document decisions and learnings
9. **Keep it simple** - Bash should stay readable (~300 lines total)
10. **One commit per phase** - Format: `"Phase N: Description"`

### Commit Message Format

```
Phase 0: Define agen CLI interface contract
Phase 1: Basic stdin→LLM→stdout flow
Phase 2: Add --batch mode and exit code semantics
Phase 3: Add state persistence and --resume
Phase 4: Add agentic loop with bash tool
Phase 5: Formalize checkpoint with full state metadata
```
