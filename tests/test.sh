#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$TESTS_DIR")"
TOOL="$REPO_DIR/agent"

source "$TESTS_DIR/test_harness.sh"

# ─── Setup ──────────────────────────────────────────────────
STUB_FILE=$(mktemp)
rm -f "$STUB_FILE"
export AGENT_BACKEND=stub AGENT_STUB_FILE="$STUB_FILE"
cleanup() { rm -f "$STUB_FILE"; }
trap cleanup EXIT

# ─── Interface contract ─────────────────────────────────────
echo "=== Interface ==="
check_exit     "--help exits 0"              0  "$TOOL" --help
check_exit     "--version exits 0"           0  "$TOOL" --version
check_exit     "no args exits 1"             1  "$TOOL"
check_exit     "unknown flag exits 1"        1  "$TOOL" --unknown-flag
check_contains "--help shows SYNOPSIS"       "SYNOPSIS"  "$TOOL" --help
check_contains "--help shows OPTIONS"        "OPTIONS"    "$TOOL" --help
check_contains "--version shows number"      "0.3.0"      "$TOOL" --version

# ─── Stub backend ───────────────────────────────────────────
echo ""
echo "=== Stub Backend ==="
rm -f "$STUB_FILE"
check_output   "first call returns 1"        "LLM return 1"  "$TOOL" "test"
check_output   "second call returns 2"       "LLM return 2"  "$TOOL" "test"
check_output   "third call returns 3"        "LLM return 3"  "$TOOL" "another"

rm -f "$STUB_FILE"
check_output   "counter resets after delete"  "LLM return 1"  "$TOOL" "test"

# ─── Piped input ────────────────────────────────────────────
echo ""
echo "=== Piped Input ==="
rm -f "$STUB_FILE"
check_pipe     "pipe is consumed"  "hello world"  "LLM return 1"  "$TOOL" "summarize"
check_pipe     "pipe with no prompt uses default task"  "some data"  "LLM return 2"  "$TOOL"

# ─── System prompts ────────────────────────────────────────
echo ""
echo "=== System Prompts ==="
rm -f "$STUB_FILE"
check_exit     "--system flag exits 0"       0  "$TOOL" --system="Be concise." "hello"
check_exit     "--system-file missing exits 1"  1  "$TOOL" --system-file=nonexistent.md "hello"

# Create a temp system file for testing
SYSTEM_FILE=$(mktemp)
echo "You are a test assistant." > "$SYSTEM_FILE"
check_exit     "--system-file valid exits 0" 0  "$TOOL" --system-file="$SYSTEM_FILE" "hello"
rm -f "$SYSTEM_FILE"

# ─── Verbose mode ──────────────────────────────────────────
echo ""
echo "=== Verbose ==="
rm -f "$STUB_FILE"
check_stderr_contains  "--verbose shows debug"  "agent:"  "$TOOL" --verbose "test"

# ─── Error messages ─────────────────────────────────────────
echo ""
echo "=== Error Messages ==="
check_contains "no args shows help hint"     "help"  "$TOOL"
check_contains "unknown flag names the flag"  "unknown-flag"  "$TOOL" --unknown-flag

# ─── Data-driven fixtures ──────────────────────────────────
if [[ -d "$TESTS_DIR/test_data" ]] && ls "$TESTS_DIR/test_data"/*.input >/dev/null 2>&1; then
  echo ""
  echo "=== Fixtures ==="
  rm -f "$STUB_FILE"
  check_fixtures "$TESTS_DIR/test_data" \
    env AGENT_BACKEND=stub AGENT_STUB_FILE="$STUB_FILE" "$TOOL" "process"
fi

# ─── Slow tests (real backend, CI only) ────────────────────
if [[ "${RUN_SLOW_TESTS:-}" != "1" ]]; then
  echo ""
  echo "=== Skipping slow tests (set RUN_SLOW_TESTS=1) ==="
else
  echo ""
  echo "=== Slow: Real Backend ==="
  check_exit "api backend returns 0" 0 "$TOOL" --backend=api "hello"
fi

# ─── Done ───────────────────────────────────────────────────
summary
