#!/usr/bin/env bash
#
# Static contract checks for the GPT prompt files (see
# docs/superpowers/specs/2026-08-10-prompt-updates-design.md §5).
# Dependency-free: bash + grep + awk + wc only.

set -u

MAX_FIXED_PROMPT_BYTES=12288

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

pass() { echo "  ok       $1"; }
fail() { echo "  FAIL     $1"; FAIL=1; }

# exactly_once <file> <extended-regex> <label>
exactly_once() {
  local n
  n="$(grep -Ec "$2" "$REPO/$1" 2>/dev/null || true)"
  if [[ "$n" == "1" ]]; then pass "$3"; else fail "$3 (found $n, want 1)"; fi
}

# contains <file> <fixed-string> <label>
# (-e guards fixed strings that start with a dash, e.g. "--model")
contains() {
  if grep -qF -e "$2" "$REPO/$1" 2>/dev/null; then pass "$3"; else fail "$3"; fi
}

# extract <file> <begin-marker> <end-marker> — prints block body (exclusive)
extract() {
  awk -v b="$2" -v e="$3" '
    index($0, e) { f = 0 }
    f            { print }
    index($0, b) { f = 1 }
  ' "$REPO/$1"
}

# model_for <brainstorm|second_opinion|review> — prints configured default
model_for() {
  grep -E "^gpt_${1}_model:" "$REPO/CLAUDE.md" | awk '{print $2}' | head -n1
}

# check_role_pack <role> <file> <config-key>
# Verifies: baseline markers present exactly once, an overlay exists for the
# configured default model, and composed baseline+overlay fits the byte cap.
check_role_pack() {
  local role="$1" file="$2" key="$3"
  local model bb eb bytes_b bytes_o

  exactly_once "$file" "<!-- gpt-baseline:${role}:begin -->" \
    "$file: ${role} baseline begin marker exactly once"
  exactly_once "$file" "<!-- gpt-baseline:${role}:end -->" \
    "$file: ${role} baseline end marker exactly once"

  model="$(model_for "$key")"
  if [[ -z "$model" ]]; then
    fail "$file: cannot resolve model for ${key}"
    return
  fi

  bb="<!-- gpt-overlay:${role}:${model}:begin -->"
  eb="<!-- gpt-overlay:${role}:${model}:end -->"
  exactly_once "$file" "$bb" "$file: overlay for ${model} present"

  bytes_b="$(extract "$file" "<!-- gpt-baseline:${role}:begin -->" \
    "<!-- gpt-baseline:${role}:end -->" | wc -c | tr -d ' ')"
  bytes_o="$(extract "$file" "$bb" "$eb" | wc -c | tr -d ' ')"

  if [[ "$bytes_b" -eq 0 ]]; then
    fail "$file: ${role} baseline body is empty"
  fi
  if (( bytes_b + bytes_o <= MAX_FIXED_PROMPT_BYTES )); then
    pass "$file: ${role} baseline+overlay ${bytes_b}+${bytes_o} bytes within ${MAX_FIXED_PROMPT_BYTES}"
  else
    fail "$file: ${role} baseline+overlay ${bytes_b}+${bytes_o} bytes exceeds ${MAX_FIXED_PROMPT_BYTES}"
  fi
}

check_ideation() {
  check_role_pack ideation skills/gpt-brainstorming/SKILL.md brainstorm
  contains skills/gpt-brainstorming/SKILL.md '20KB' \
    "SKILL.md: states 20KB working budget"
  contains skills/gpt-brainstorming/SKILL.md '30KB' \
    "SKILL.md: states 30KB hard boundary"
  contains skills/gpt-brainstorming/SKILL.md 'read-only' \
    "SKILL.md: read-only codex rule present"
}

check_review_agent() {
  check_role_pack review agents/codex-adversary.md review
  contains agents/codex-adversary.md '20KB' \
    "codex-adversary: states 20KB working budget"
  contains agents/codex-adversary.md '30KB' \
    "codex-adversary: states 30KB hard boundary"
  contains agents/codex-adversary.md 'read-only' \
    "codex-adversary: read-only rule present"
  contains agents/codex-adversary.md 'Never retry a timed-out payload unchanged' \
    "codex-adversary: unchanged-timeout prohibition present"
  contains agents/codex-adversary.md '## Verdict' \
    "codex-adversary: Verdict heading present"
  contains agents/codex-adversary.md '## Findings' \
    "codex-adversary: Findings heading present"
  contains agents/codex-adversary.md '## Discarded' \
    "codex-adversary: Discarded heading present"
  contains agents/codex-adversary.md '## Reviewer disagreements' \
    "codex-adversary: Reviewer disagreements heading present"
}

check_review_command() {
  contains commands/adversarial-review.md '--model' \
    "adversarial-review: documents --model option"
  contains commands/adversarial-review.md 'do not auto-loop more than once' \
    "adversarial-review: one-loop maximum preserved"
  contains commands/adversarial-review.md 'TODO.md' \
    "adversarial-review: owns missing-variant TODO side effect"
}

check_claude_md() {
  exactly_once CLAUDE.md '^gpt_brainstorm_model:' \
    "CLAUDE.md: gpt_brainstorm_model exactly once"
  exactly_once CLAUDE.md '^gpt_second_opinion_model:' \
    "CLAUDE.md: gpt_second_opinion_model exactly once"
  exactly_once CLAUDE.md '^gpt_review_model:' \
    "CLAUDE.md: gpt_review_model exactly once"
  contains CLAUDE.md '20KB' "CLAUDE.md: states 20KB working budget"
  contains CLAUDE.md '30KB' "CLAUDE.md: states 30KB hard boundary"
  contains CLAUDE.md 'TODO.md' "CLAUDE.md: pins missing-variant tracking to TODO.md"
  contains CLAUDE.md 'unavailable at stage 1 or 3, stop' \
    "CLAUDE.md: stop-on-MCP-failure rule present"
}

main() {
  echo "prompt-contract-test: $REPO"
  check_claude_md
  check_ideation
  check_review_agent
  check_review_command
  exit "$FAIL"
}

main
