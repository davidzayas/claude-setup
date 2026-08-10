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
  exit "$FAIL"
}

main
