#!/usr/bin/env bash
#
# Negative tests for tests/prompt-contract-test.sh (and the uninstall suite's
# pty probe). Each case copies the repo into a temp dir, plants one defect the
# checker is supposed to catch, and asserts the checker fails — or, for the
# false-positive probes, that it still passes. Every guard added in the
# 2026-09-09 hardening rounds has its defect here, so a later change to the
# checker cannot silently regress a guard back open.
#
# Needs bash, rsync, and python3 (in-place edits; BSD and GNU sed disagree on -i).

set -u

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); echo "  ok    $1"; }
bad() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }

for dep in rsync python3; do
  command -v "$dep" >/dev/null 2>&1 || { echo "missing dependency: $dep"; exit 2; }
done

# mutant <name> — fresh copy of the repo (no .git, no scratch) at $M
mutant() {
  M="$TMP/$1"
  rm -rf "$M" && mkdir -p "$M"
  rsync -a --exclude .git --exclude .superpowers "$SRC/" "$M/"
}

# checker — run the copy's contract checker; log at $M.log; return its exit
checker() { bash "$M/tests/prompt-contract-test.sh" >"$M.log" 2>&1; }

# expect_caught <description> [fail-line substring]
expect_caught() {
  local desc="$1" needle="${2:-}"
  if checker; then
    bad "$desc (checker passed the mutant)"
  elif [[ -n "$needle" ]] && ! grep -qF -e "$needle" "$M.log"; then
    bad "$desc (checker failed, but not for the expected reason: $needle)"
  else
    ok "$desc"
  fi
}

# expect_clean <description> — a legitimate variation must still pass
expect_clean() {
  if checker; then ok "$1"; else bad "$1 (checker rejected a legitimate tree)"; fi
}

# replace <file> <old> <new> — literal, first occurrence; errors if absent
replace() {
  python3 - "$M/$1" "$2" "$3" <<'PY'
import sys
p, old, new = sys.argv[1:4]
s = open(p, encoding="utf-8").read()
if old not in s:
    sys.exit(f"replace: {old!r} not found in {p}")
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
}

# replace_all <file> <old> <new>
replace_all() {
  python3 - "$M/$1" "$2" "$3" <<'PY'
import sys
p, old, new = sys.argv[1:4]
s = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(s.replace(old, new))
PY
}

# delete_line <file> <exact line>
delete_line() {
  python3 - "$M/$1" "$2" <<'PY'
import sys
p, line = sys.argv[1:3]
lines = open(p, encoding="utf-8").read().split("\n")
if line not in lines:
    sys.exit(f"delete_line: {line!r} not found in {p}")
lines.remove(line)
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY
}

# append_to_overlay <file> <role> <model> <text> — add text at the end of an
# overlay body, just before its end marker
append_to_overlay() {
  python3 - "$M/$1" "$2" "$3" "$4" <<'PY'
import sys
p, role, model, text = sys.argv[1:5]
s = open(p, encoding="utf-8").read()
e = f"<!-- gpt-overlay:{role}:{model}:end -->"
j = s.index(e)
open(p, "w", encoding="utf-8").write(s[:j].rstrip("\n") + " " + text + "\n" + s[j:])
PY
}

SKILL=skills/gpt-brainstorming/SKILL.md
CMD=commands/gpt-brainstorm.md
AGENT=agents/codex-adversary.md

echo "prompt-contract-mutation-test: $SRC"

echo "baseline"
mutant baseline
expect_clean "unmodified tree passes the checker"

echo "string guards"
mutant m1
replace_all "$CMD" "20KB" "twentyKB"; replace_all "$CMD" "30KB" "thirtyKB"; replace_all "$CMD" "read-only" "readonly"
expect_caught "budget and read-only strings stripped from the second-opinion command" "gpt-brainstorm: states 20KB"
mutant m5
replace "$SKILL" "STOP and tell the user" "carry on quietly"
replace_all "$AGENT" "report it and stop" "keep going"
expect_caught "stop-on-MCP-failure language removed from SKILL.md and codex-adversary.md" "stop-on-MCP-failure"
mutant m6
replace_all "$AGENT" "overlay model" "variant"
expect_caught "'overlay model' seam phrase removed from codex-adversary.md" "names the overlay model"

echo "overlay markers"
mutant m2
delete_line "$AGENT" "<!-- gpt-overlay:review:gpt-6-astra:end -->"
expect_caught "overlay END marker deleted" "end marker exactly once"
mutant m7
python3 - "$M/$CMD" <<'PY'
import sys
p = sys.argv[1]; lines = open(p, encoding="utf-8").read().split("\n")
b = "<!-- gpt-overlay:second-opinion:gpt-6-astra:begin -->"; e = "<!-- gpt-overlay:second-opinion:gpt-6-astra:end -->"
bi, ei = lines.index(b), lines.index(e); lines[bi], lines[ei] = lines[ei], lines[bi]
open(p, "w", encoding="utf-8").write("\n".join(lines))
PY
expect_caught "overlay END marker before its begin marker" "end marker missing or before begin"
mutant m8
printf '\n<!-- gpt-overlay:review::begin -->\nstray\n<!-- gpt-overlay:review::end -->\n' >> "$M/$AGENT"
expect_caught "overlay marker with an empty model id" "empty model id"
mutant m10
replace "$AGENT" "<!-- gpt-overlay:review:gpt-6-astra:end -->" "<!-- gpt-overlay:review:gpt-6-astra:end --><!-- gpt-overlay:review:gpt-6-astra:end -->"
expect_caught "overlay END marker pasted twice on one line" "found 2, want 1"

echo "byte cap"
mutant m3
python3 - "$M/$SKILL" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
b = "<!-- gpt-overlay:ideation:gpt-5.6-sol:begin -->\n"; e = "<!-- gpt-overlay:ideation:gpt-5.6-sol:end -->"
i = s.index(b) + len(b); j = s.index(e)
open(p, "w", encoding="utf-8").write(s[:i] + ("padding " * 2000) + "\n" + s[j:])
PY
expect_caught "a non-default overlay bloated past the cap" "exceeds 12288"

echo "TODO.md duplicates"
mutant m4
printf -- '- [ ] prompt-variant: role=ideation model=gpt-6-astra\n' >> "$M/TODO.md"
expect_caught "open prompt-variant entry duplicating a ticked one" "duplicate role/model pairs"
mutant m9
printf -- '- [x] prompt-variant: role=review model=gpt-old — replaced; see role=review model=gpt-new\n- [ ] prompt-variant: role=review model=gpt-new\n' >> "$M/TODO.md"
expect_clean "a ticked entry whose note mentions another pair is not a duplicate"

echo "no-restatement guard"
mutant m11
append_to_overlay "$SKILL" ideation gpt-6-astra "Stop after each section for Claude's verification; revise it until approved before advancing."
expect_caught "baseline sentence copied verbatim into an overlay" "restates a baseline clause"
mutant m12
python3 - "$M/$AGENT" <<'PY'
import sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
e = "<!-- gpt-overlay:review:gpt-6-astra:end -->"; j = s.index(e)
open(p, "w", encoding="utf-8").write(s[:j].rstrip("\n") + "\nReport a finding only when the supplied code\nsupports a plausible failure.\n" + s[j:])
PY
expect_caught "copied sentence wrapped across two overlay lines" "restates a baseline clause"
mutant m14
append_to_overlay "$AGENT" review gpt-6-astra "Do not request unrelated files."
expect_caught "short (31-byte) baseline rule copied" "Do not request unrelated files"
mutant m15
append_to_overlay "$AGENT" review gpt-6-astra "Output sections in this order: CRITICAL, HIGH, MEDIUM, LOW."
expect_caught "rule clause from a colon/bullet structure copied" "CRITICAL, HIGH, MEDIUM, LOW"
mutant m16
append_to_overlay "$AGENT" review gpt-6-astra "Review only the supplied scope."
expect_caught "rule that follows a template slot in the baseline" "Review only the supplied scope"
mutant m17
append_to_overlay "$AGENT" review gpt-6-astra "Exclude style preferences, diff restatements, duplicate root causes, and unsupported speculation."
expect_caught "rule preceded by a leftover quote character in the baseline" "Exclude style preferences"
mutant m18
append_to_overlay "$SKILL" ideation gpt-6-astra "Claude alone facilitates the discussion with the human and verifies approval."
expect_caught "rule that follows a slot line and a blank line (ideation)" "Claude alone facilitates"
mutant m19
append_to_overlay "$AGENT" review gpt-6-astra "Output sections in this order."
expect_caught "rule that follows an unpunctuated bullet and a paragraph break" "Output sections in this order"
mutant m20
append_to_overlay "$CMD" second-opinion gpt-6-astra "Attack that position constructively."
expect_caught "rule that follows the {claude_position} slot (second-opinion)" "Attack that position constructively"

echo "uninstall-test pty probe"
mutant m13
mkdir -p "$TMP/stub-bin"; printf '#!/bin/sh\nexit 1\n' > "$TMP/stub-bin/script"; chmod +x "$TMP/stub-bin/script"
if PATH="$TMP/stub-bin:$PATH" bash "$M/tests/uninstall-test.sh" >"$M.log" 2>&1 \
   && grep -q '^  skip' "$M.log" && grep -q 'skipped (no pseudo-terminal)' "$M.log"; then
  ok "with an always-failing 'script', the suite skips its pty tests and exits 0"
else
  bad "with an always-failing 'script', the suite should skip its pty tests and exit 0 (see $M.log)"
fi

echo
echo "$PASS passed, $FAIL failed"
if (( FAIL > 0 )); then exit 1; fi
