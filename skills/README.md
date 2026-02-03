# Skills

Skills are shell scripts that orchestrate agen for specific workflows.

## The Pattern

In Vision A (agent as shell), skills are prompts the agent interprets.
In Vision B (agent in shell), skills are **scripts that invoke the agent**.

```
Vision A:  User → Agent TUI → reads skill.md → executes
Vision B:  User → ./skills/ship → invokes agen → uses output
```

The shell is the orchestrator. agen is a tool it calls.

## Anatomy of a Skill

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGEN="${SCRIPT_DIR}/../agen"

# 1. Gather context (git, files, env)
diff=$(git diff --cached)

# 2. Call agen with that context
result=$(echo "$diff" | "$AGEN" --system=SYSTEM.md "analyze this")

# 3. Act on the result
if echo "$result" | grep -q "PROBLEM"; then
  echo "Issues found"
  exit 1
fi
```

## Included Skills

| Skill | Purpose |
|-------|---------|
| `ship` | Commit checkpoint with semantic README check |
| `review` | Code review for staged changes or files |

## Creating Skills

1. Create an executable script in `skills/`
2. Use agen for the LLM parts
3. Use shell for orchestration (git, file ops, conditionals)

Skills can:
- Pipe data to agen
- Parse agen's output
- Make decisions based on responses
- Chain multiple agen calls
- Integrate with other tools

## Why This Matters

Claude Code skills are markdown files the agent reads.
agen skills are programs that use the agent.

The difference:
- **Composable**: Skills can call other skills, other tools, agen multiple times
- **Testable**: Skills are scripts you can test without an LLM
- **Portable**: Skills work with any agen backend, any model
- **Observable**: `bash -x ./skills/ship` shows exactly what happens
