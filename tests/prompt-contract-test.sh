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

# exactly_once_fixed <file> <fixed-string> <label> — literal match, for markers
exactly_once_fixed() {
  local n
  n="$(grep -Fc -e "$2" "$REPO/$1" 2>/dev/null || true)"
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

# line_of <file> <fixed-string> — line number of the first match, empty if none
line_of() {
  grep -Fn -e "$2" "$REPO/$1" 2>/dev/null | head -n1 | cut -d: -f1
}

# model_for <brainstorm|second_opinion|review> — prints configured default
model_for() {
  grep -E "^gpt_${1}_model:" "$REPO/CLAUDE.md" | awk '{print $2}' | head -n1
}

# overlay_models <file> <role> — every model with an overlay begin marker
overlay_models() {
  grep -o "<!-- gpt-overlay:${2}:[^:]*:begin -->" "$REPO/$1" 2>/dev/null \
    | sed -E 's/.*:([^:]*):begin -->/\1/' | sort -u
}

# check_overlay <role> <file> <model> <baseline-bytes>
# Every overlay present is held to the same contract as the configured one:
# both markers exactly once and in order (a missing end marker would make
# extract run to EOF), non-empty body, and baseline+overlay within the cap.
check_overlay() {
  local role="$1" file="$2" model="$3" bytes_b="$4"
  local bb eb lb le bytes_o
  bb="<!-- gpt-overlay:${role}:${model}:begin -->"
  eb="<!-- gpt-overlay:${role}:${model}:end -->"

  exactly_once_fixed "$file" "$bb" "$file: overlay ${model} begin marker exactly once"
  exactly_once_fixed "$file" "$eb" "$file: overlay ${model} end marker exactly once"
  lb="$(line_of "$file" "$bb")"
  le="$(line_of "$file" "$eb")"
  if [[ -n "$lb" && -n "$le" && "$lb" -lt "$le" ]]; then
    pass "$file: overlay ${model} markers ordered (begin line $lb, end line $le)"
  else
    fail "$file: overlay ${model} end marker missing or before begin (begin ${lb:-none}, end ${le:-none})"
  fi

  bytes_o="$(extract "$file" "$bb" "$eb" | wc -c | tr -d ' ')"
  if [[ "$bytes_o" -eq 0 ]]; then
    fail "$file: overlay ${model} body is empty"
  fi
  if (( bytes_b + bytes_o <= MAX_FIXED_PROMPT_BYTES )); then
    pass "$file: ${role} baseline+overlay(${model}) ${bytes_b}+${bytes_o} bytes within ${MAX_FIXED_PROMPT_BYTES}"
  else
    fail "$file: ${role} baseline+overlay(${model}) ${bytes_b}+${bytes_o} bytes exceeds ${MAX_FIXED_PROMPT_BYTES}"
  fi
}

# check_role_pack <role> <file> <config-key>
# Verifies: baseline markers present exactly once, an overlay exists for the
# configured default model, and every overlay present passes check_overlay.
check_role_pack() {
  local role="$1" file="$2" key="$3"
  local model bytes_b m

  exactly_once_fixed "$file" "<!-- gpt-baseline:${role}:begin -->" \
    "$file: ${role} baseline begin marker exactly once"
  exactly_once_fixed "$file" "<!-- gpt-baseline:${role}:end -->" \
    "$file: ${role} baseline end marker exactly once"

  bytes_b="$(extract "$file" "<!-- gpt-baseline:${role}:begin -->" \
    "<!-- gpt-baseline:${role}:end -->" | wc -c | tr -d ' ')"
  if [[ "$bytes_b" -eq 0 ]]; then
    fail "$file: ${role} baseline body is empty"
  fi

  model="$(model_for "$key")"
  if [[ -z "$model" ]]; then
    fail "$file: cannot resolve model for ${key}"
    return
  fi
  exactly_once_fixed "$file" "<!-- gpt-overlay:${role}:${model}:begin -->" \
    "$file: overlay for configured model ${model} present"

  for m in $(overlay_models "$file" "$role"); do
    check_overlay "$role" "$file" "$m" "$bytes_b"
  done
}

check_ideation() {
  check_role_pack ideation skills/gpt-brainstorming/SKILL.md brainstorm
  contains skills/gpt-brainstorming/SKILL.md '20KB' \
    "SKILL.md: states 20KB working budget"
  contains skills/gpt-brainstorming/SKILL.md '30KB' \
    "SKILL.md: states 30KB hard boundary"
  contains skills/gpt-brainstorming/SKILL.md 'read-only' \
    "SKILL.md: read-only codex rule present"
  contains skills/gpt-brainstorming/SKILL.md 'STOP and tell the user' \
    "SKILL.md: stop-on-MCP-failure rule present"
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
  contains agents/codex-adversary.md 'report it and stop' \
    "codex-adversary: stop-on-MCP-failure rule present"
  contains agents/codex-adversary.md 'overlay model' \
    "codex-adversary: names the overlay model the caller passes"
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

check_second_opinion() {
  check_role_pack second-opinion commands/gpt-brainstorm.md second_opinion
  contains commands/gpt-brainstorm.md '--model' \
    "gpt-brainstorm: documents --model option"
  contains commands/gpt-brainstorm.md '20KB' \
    "gpt-brainstorm: states 20KB working budget"
  contains commands/gpt-brainstorm.md '30KB' \
    "gpt-brainstorm: states 30KB hard boundary"
  contains commands/gpt-brainstorm.md 'read-only' \
    "gpt-brainstorm: read-only codex rule present"
}

check_todo() {
  if [[ ! -f "$REPO/TODO.md" ]]; then
    fail "TODO.md exists at repo root"
    return
  fi
  pass "TODO.md exists at repo root"

  # Only lines that ARE entries (start with the checkbox) are validated;
  # the documented format line in prose starts with a backtick and is skipped.
  local bad dupes
  bad="$(grep -n '^- \[ \] prompt-variant' "$REPO/TODO.md" \
    | grep -Ev 'prompt-variant: role=(ideation|second-opinion|review) model=[^ ]+$' || true)"
  if [[ -z "$bad" ]]; then
    pass "TODO.md: all prompt-variant entries match the schema"
  else
    fail "TODO.md: malformed prompt-variant entries: $bad"
  fi

  # A pair is a duplicate whether its entries are open or ticked, and
  # regardless of trailing notes — the runtime's "skip if already present"
  # rule keys on the role/model pair, not the whole line.
  dupes="$(grep -E '^- \[[ x]\] prompt-variant:' "$REPO/TODO.md" \
    | grep -Eo 'role=[^ ]+ model=[^ ]+' | sort | uniq -d)"
  if [[ -z "$dupes" ]]; then
    pass "TODO.md: no duplicate role/model pairs (open or ticked)"
  else
    fail "TODO.md: duplicate role/model pairs: $dupes"
  fi

  if grep -q 'TODO.md' "$REPO/managed-files.sh"; then
    fail "managed-files.sh must NOT include TODO.md"
  else
    pass "managed-files.sh does not include TODO.md"
  fi
}

check_alias_registry() {
  # Zero alias lines is valid; every present line must match the schema
  # exactly (see CLAUDE.md "GPT model routing"): one deployment, '=', one
  # family, no whitespace (spaces, tabs, etc.) in either.
  local bad dupes
  bad="$(grep -En '^gpt_model_alias:' "$REPO/CLAUDE.md" \
    | grep -Ev '^[0-9]+:gpt_model_alias: [^[:space:]=]+=[^[:space:]=]+$' \
    || true)"
  if [[ -z "$bad" ]]; then
    pass "CLAUDE.md: all gpt_model_alias lines match the schema"
  else
    fail "CLAUDE.md: malformed gpt_model_alias lines: $bad"
  fi

  dupes="$(grep -E '^gpt_model_alias:' "$REPO/CLAUDE.md" \
    | awk -F'[ =]' '{print $2}' | sort | uniq -d)"
  if [[ -z "$dupes" ]]; then
    pass "CLAUDE.md: no conflicting alias left sides"
  else
    fail "CLAUDE.md: conflicting aliases for: $dupes"
  fi
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
  check_alias_registry
  check_ideation
  check_review_agent
  check_review_command
  check_second_opinion
  check_todo
  exit "$FAIL"
}

main
