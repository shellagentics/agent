# AGENTS.md - AI Assistant Guide for `agent`

## Project Overview

**agent** is a Unix primitive for LLM inference — stdin in, stdout out, nothing else. It composes in pipelines as one tool among many, rather than replacing the shell.

```bash
cat error.log | agent "diagnose" | agent "suggest fix" > recommendations.md
```

Part of the [Shell Agentics](https://github.com/shellagentics/shell-agentics) toolkit.

## Build & Run

No build step. Single bash script.
Run: `./agent --help`

## Testing

Methodology: https://github.com/shellagentics/shell-agentics/blob/main/TESTING.md
Run tests: `./tests/test.sh`
Update expected outputs: `UPDATE=1 ./tests/test.sh`
Harness: `tests/test_harness.sh` — source this from test.sh, do not modify directly.
Backend: always use `AGENT_BACKEND=stub` for deterministic tests.

## Conventions

- Unix philosophy: stdin → process → stdout
- Exit 0 on success, non-zero on failure
- `--help` and `--version` are mandatory flags
- All tests must pass with stub backend (no network, no API keys)

## Why Bash

1. **Zero dependencies** - runs anywhere with bash, curl, jq
2. **Forces simplicity** - can't over-engineer in bash
3. **Transparency** - anyone can read the source in 5 minutes
4. **Unix credibility** - the tool embodies the philosophy it advocates

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
    --backend=*)
      BACKEND="${1#*=}"
      shift
      ;;
    --system-file=*)
      SYSTEM_FILE="${1#*=}"
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
die() {
  echo "agent: $*" >&2
  exit $EXIT_FAILURE
}

verbose() {
  if [[ "${VERBOSE:-}" == "1" ]]; then
    echo "agent: $*" >&2
  fi
}
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

## For AI Assistants

When working on this codebase:

1. **Use named exit codes** - Never hardcode exit numbers
2. **Prefer jq for JSON** - Never parse JSON with grep/sed
3. **Always quote variables** - Prevent word splitting issues
4. **Check API errors** - Never assume API calls succeed
5. **Write to stderr for logging** - stdout is for output only
6. **Keep it simple** - Bash should stay readable
