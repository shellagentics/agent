#!/usr/bin/env bash
# test_harness.sh — shared test infrastructure
# Copy of the canonical harness from shell-agentics/tests/test_harness.sh

set -euo pipefail

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors (if terminal)
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; DIM='\033[0;90m'; NC='\033[0m'
else
  GREEN=''; RED=''; DIM=''; NC=''
fi

# ─── Core check functions ───────────────────────────────────

# Check exit code only
check_exit() {
  local name="$1" expected_exit="$2"
  shift 2
  TESTS_RUN=$((TESTS_RUN + 1))
  set +e; "$@" >/dev/null 2>&1; local actual_exit=$?; set -e
  if [[ $actual_exit -eq $expected_exit ]]; then
    echo -e "${GREEN}✓${NC} $name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name ${DIM}(exit: expected $expected_exit, got $actual_exit)${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Check stdout matches expected string exactly
check_output() {
  local name="$1" expected="$2"
  shift 2
  TESTS_RUN=$((TESTS_RUN + 1))
  set +e; local actual; actual=$("$@" 2>/dev/null); set -e
  if [[ "$actual" == "$expected" ]]; then
    echo -e "${GREEN}✓${NC} $name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name"
    echo -e "  ${DIM}expected:${NC} $(echo "$expected" | head -3)"
    echo -e "  ${DIM}actual:${NC}   $(echo "$actual" | head -3)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Check stdout contains a pattern (grep -q)
check_contains() {
  local name="$1" pattern="$2"
  shift 2
  TESTS_RUN=$((TESTS_RUN + 1))
  set +e; local output; output=$("$@" 2>&1); set -e
  if echo "$output" | grep -q "$pattern"; then
    echo -e "${GREEN}✓${NC} $name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name ${DIM}(output missing: '$pattern')${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Check piped input → tool → stdout
check_pipe() {
  local name="$1" input="$2" expected="$3"
  shift 3
  TESTS_RUN=$((TESTS_RUN + 1))
  set +e; local actual; actual=$(echo "$input" | "$@" 2>/dev/null); set -e
  if [[ "$actual" == "$expected" ]]; then
    echo -e "${GREEN}✓${NC} $name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name"
    echo -e "  ${DIM}expected:${NC} $(echo "$expected" | head -3)"
    echo -e "  ${DIM}actual:${NC}   $(echo "$actual" | head -3)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Check stderr contains a pattern (for --verbose, error messages)
check_stderr_contains() {
  local name="$1" pattern="$2"
  shift 2
  TESTS_RUN=$((TESTS_RUN + 1))
  set +e; local err; err=$("$@" 2>&1 >/dev/null); set -e
  if echo "$err" | grep -q "$pattern"; then
    echo -e "${GREEN}✓${NC} $name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name ${DIM}(stderr missing: '$pattern')${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Check a file exists and contains a pattern
check_file_contains() {
  local name="$1" filepath="$2" pattern="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ ! -f "$filepath" ]]; then
    echo -e "${RED}✗${NC} $name ${DIM}(file missing: $filepath)${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  elif grep -q "$pattern" "$filepath"; then
    echo -e "${GREEN}✓${NC} $name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name ${DIM}(file missing pattern: '$pattern')${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# ─── Data-driven fixture runner ─────────────────────────────

# Run all .input/.expected pairs from a directory.
# Usage: check_fixtures <dir> <command...>
# Pipes each .input file into the command, compares stdout to .expected.
# With UPDATE=1, overwrites .expected files with actual output.
check_fixtures() {
  local fixture_dir="$1"
  shift
  if [[ ! -d "$fixture_dir" ]]; then return; fi
  for input_file in "$fixture_dir"/*.input; do
    [[ -f "$input_file" ]] || continue
    local base="${input_file%.input}"
    local name="$(basename "$base")"
    local expected_file="$base.expected"
    local actual

    TESTS_RUN=$((TESTS_RUN + 1))
    set +e
    actual=$(cat "$input_file" | "$@" 2>/dev/null)
    set -e

    if [[ "${UPDATE:-}" == "1" ]]; then
      echo "$actual" > "$expected_file"
      echo -e "${GREEN}✓${NC} $name ${DIM}(updated)${NC}"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [[ ! -f "$expected_file" ]]; then
      echo -e "${RED}✗${NC} $name ${DIM}(missing $expected_file — run with UPDATE=1)${NC}"
      TESTS_FAILED=$((TESTS_FAILED + 1))
    elif diff -q <(echo "$actual") "$expected_file" >/dev/null 2>&1; then
      echo -e "${GREEN}✓${NC} $name"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      echo -e "${RED}✗${NC} $name"
      diff --color=auto <(echo "$actual") "$expected_file" | head -10
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  done
}

# ─── Summary ────────────────────────────────────────────────

summary() {
  echo ""
  echo "════════════════════════════════"
  echo "Tests: $TESTS_PASSED/$TESTS_RUN passed"
  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed.${NC}"
    exit 0
  else
    echo -e "${RED}$TESTS_FAILED failed.${NC}"
    exit 1
  fi
}
