# Uninstall Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `uninstall.sh` that removes only symlinks verifiably owned by this repo and restores the installer's `.backup-<timestamp>` files, per the approved spec at `docs/superpowers/specs/2026-08-07-uninstall-script-design.md`.

**Architecture:** A data-only `managed-files.sh` manifest is sourced by both `install.sh` and the new `uninstall.sh`. The uninstaller is two-phase: a read-only phase (preflight ownership check → backup discovery → interactive selection → whole-plan validation → plan print) and a mutate phase that rechecks each entry immediately before touching it. A self-contained bash test suite drives everything inside a `mktemp -d` fixture.

**Tech Stack:** Plain bash (macOS `/bin/bash` 3.2 compatible), `mv`/`ln`/`readlink`, BSD `script` for pty-driven interactive tests. No frameworks, no dependencies.

## Global Constraints

- All scripts start with `set -euo pipefail`.
- **Bash 3.2 compatibility** (macOS default): no associative arrays, no `${var,,}`, no `readarray`. Regex patterns must live in a variable (`[[ $x =~ $pat ]]`), not inline. Guard possibly-empty array expansion under `set -u` with `${arr[@]+"${arr[@]}"}` or a length check — `"${arr[@]}"` on an empty array is an unbound-variable error in bash 3.2.
- Numeric input from the user must be forced to base 10 in arithmetic (`10#$pick`) — otherwise `08` is an invalid-octal crash under `set -e`.
- The only thing the uninstaller ever deletes is a symlink whose raw `readlink` output exactly equals `"$REPO/<rel>"`. Nothing is ever overwritten. `settings.json` is never inspected or modified.
- Backup candidates must match exactly `.backup-<8 digits>-<6 digits>` at end of name; anything else is ignored. Candidates are listed oldest first (fixed-width stamps make glob order chronological).
- Tests must never touch the caller's real `~/.claude`; every case runs against a throwaway `CLAUDE_HOME` under `mktemp -d`, cleaned by `trap ... EXIT`.
- The `${CLAUDE_HOME:-$HOME/.claude}` empty-string-falls-back behavior is verified by inspection only (both scripts use the identical expansion); executing that case would touch the real home directory.
- Comment style: sparse, lowercase-sentence comments explaining *why*, matching `install.sh`.

---

### Task 1: Shared manifest + install.sh refactor + test harness

**Files:**
- Create: `managed-files.sh`
- Modify: `install.sh:19-25`
- Test: `tests/uninstall-test.sh` (new — harness plus installer regression tests)

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `MANAGED_FILES` — an indexed bash array of the five managed relative paths, defined by sourcing `managed-files.sh`. Test helpers used by every later task: `fixture <name>` (builds `$FREPO`/`$FHOME`), `install_f`, `uninstall_f`, `snapshot <dir>`, `check <desc> <cmd...>`, `ok`/`bad`, and the `PASS`/`FAIL` counters. All later test blocks are inserted **above** the `# ---- summary` section.

- [ ] **Step 1: Write the manifest**

Create `managed-files.sh`:

```bash
#!/usr/bin/env bash
#
# The one list both install.sh and uninstall.sh source, so they can never
# disagree about which paths this repo owns. Data only — no side effects.

MANAGED_FILES=(
  CLAUDE.md
  agents/codex-adversary.md
  commands/adversarial-review.md
  commands/gpt-brainstorm.md
  skills/gpt-brainstorming/SKILL.md
)
```

- [ ] **Step 2: Write the failing test harness**

Create `tests/uninstall-test.sh` (mode 755):

```bash
#!/usr/bin/env bash
#
# Self-contained regression tests for install.sh / uninstall.sh.
# Everything happens inside one mktemp directory; the caller's real
# ~/.claude is never touched.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok()  { PASS=$((PASS + 1)); echo "  ok    $1"; }
bad() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }

# check <description> <command...> — pass/fail on the command's exit status
check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

# fixture <name> — builds $TMP/<name>/{repo,home}, sets FREPO and FHOME.
# The fixture repo holds copies of the scripts plus dummy managed files, so
# tests never depend on the real repo's content and every mv/ln stays in $TMP.
fixture() {
  FREPO="$TMP/$1/repo"
  FHOME="$TMP/$1/home"
  mkdir -p "$FREPO" "$FHOME"
  cp "$SRC/install.sh" "$SRC/managed-files.sh" "$FREPO/"
  if [[ -f "$SRC/uninstall.sh" ]]; then
    cp "$SRC/uninstall.sh" "$FREPO/"
  fi
  source "$SRC/managed-files.sh"
  local rel
  for rel in "${MANAGED_FILES[@]}"; do
    mkdir -p "$FREPO/$(dirname "$rel")"
    echo "repo content: $rel" > "$FREPO/$rel"
  done
}

install_f()   { CLAUDE_HOME="$FHOME" bash "$FREPO/install.sh" "$@"; }
uninstall_f() { CLAUDE_HOME="$FHOME" bash "$FREPO/uninstall.sh" "$@"; }

# snapshot <dir> — one line per entry (path, type, target/checksum), so two
# snapshots being equal proves the tree is byte-for-byte unchanged.
snapshot() {
  (cd "$1" && find . -mindepth 1 | LC_ALL=C sort | while IFS= read -r p; do
    if   [[ -L "$p" ]]; then echo "$p link $(readlink "$p")"
    elif [[ -f "$p" ]]; then echo "$p file $(cksum < "$p")"
    else                     echo "$p dir"
    fi
  done)
}

# ---- installer regression ----------------------------------------------------

echo "install: fresh home links all five"
fixture inst-fresh
install_f >/dev/null
for rel in "${MANAGED_FILES[@]}"; do
  check "links $rel" test "$(readlink "$FHOME/$rel")" = "$FREPO/$rel"
done

echo "install: pre-existing file is backed up, not overwritten"
fixture inst-backup
mkdir -p "$FHOME"
echo "user original" > "$FHOME/CLAUDE.md"
install_f >/dev/null
check "CLAUDE.md is now the repo link" test "$(readlink "$FHOME/CLAUDE.md")" = "$FREPO/CLAUDE.md"
backup_count=$(ls "$FHOME"/CLAUDE.md.backup-* 2>/dev/null | wc -l | tr -d ' ')
check "exactly one backup created" test "$backup_count" = "1"
check "backup keeps original content" grep -q "user original" "$FHOME"/CLAUDE.md.backup-*

echo "install: DRY_RUN=1 changes nothing"
fixture inst-dry
before=$(snapshot "$FHOME")
DRY_RUN=1 install_f >/dev/null
check "home unchanged after dry-run install" test "$(snapshot "$FHOME")" = "$before"

# ---- summary -------------------------------------------------------------------

echo
echo "$PASS passed, $FAIL failed"
if (( FAIL > 0 )); then exit 1; fi
```

- [ ] **Step 3: Run the suite to capture the pre-refactor baseline**

Run: `bash tests/uninstall-test.sh`
Expected: PASS against the *unrefactored* installer (this refactor is behavior-preserving, so there is no red state to demand — the suite is the safety net, not the driver). Record the pass count; Step 5 must reproduce it exactly. If anything fails here, the harness itself is wrong — fix it before touching install.sh.

- [ ] **Step 4: Refactor install.sh to source the manifest**

In `install.sh`, replace lines 19–25:

```bash
FILES=(
  CLAUDE.md
  agents/codex-adversary.md
  commands/adversarial-review.md
  commands/gpt-brainstorm.md
  skills/gpt-brainstorming/SKILL.md
)
```

with:

```bash
source "$REPO/managed-files.sh"
```

and change the loop at the bottom from:

```bash
for f in "${FILES[@]}"; do link "$f"; done
```

to:

```bash
for f in "${MANAGED_FILES[@]}"; do link "$f"; done
```

- [ ] **Step 5: Run tests to verify the refactor is behavior-preserving**

Run: `bash tests/uninstall-test.sh && bash -n install.sh managed-files.sh tests/uninstall-test.sh`
Expected: same pass count as the Step 3 baseline, zero failures, `bash -n` silent.

- [ ] **Step 6: Commit**

```bash
git add managed-files.sh install.sh tests/uninstall-test.sh
git commit -m "Extract managed-file manifest shared by install and uninstall

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: uninstall.sh preflight — refuse anything the repo doesn't own

**Files:**
- Create: `uninstall.sh` (mode 755)
- Test: `tests/uninstall-test.sh` (append conflict tests above the summary)

**Interfaces:**
- Consumes: `MANAGED_FILES` from `managed-files.sh`; `fixture`/`install_f`/`uninstall_f`/`snapshot`/`check` from Task 1.
- Produces: `uninstall.sh` that exits 0 with `Preflight ok.` on a clean install and exits 1 listing **all** conflicts (changing nothing) otherwise. Later tasks replace the `Preflight ok.` tail; everything above it is final.

- [ ] **Step 1: Write the failing tests**

First add this helper next to `check()` in the harness (it inverts an expected failure without tripping `set -e`):

```bash
# test_fails <command...> — succeeds iff the command exits nonzero
test_fails() { if "$@" >/dev/null 2>&1; then return 1; else return 0; fi; }
```

Then insert above `# ---- summary` in `tests/uninstall-test.sh`:

```bash
# ---- uninstall preflight -------------------------------------------------------

echo "uninstall: regular file is a conflict, nothing changes"
fixture pre-regular
install_f >/dev/null
rm "$FHOME/CLAUDE.md"
echo "user file" > "$FHOME/CLAUDE.md"
before=$(snapshot "$FHOME")
check "exits nonzero" test_fails uninstall_f
check "home unchanged" test "$(snapshot "$FHOME")" = "$before"

echo "uninstall: wrong-target symlink is a conflict"
fixture pre-foreign
install_f >/dev/null
rm "$FHOME/agents/codex-adversary.md"
ln -s /etc/hosts "$FHOME/agents/codex-adversary.md"
before=$(snapshot "$FHOME")
check "exits nonzero" test_fails uninstall_f
check "home unchanged" test "$(snapshot "$FHOME")" = "$before"

echo "uninstall: missing path (partial install) blocks everything"
fixture pre-partial
install_f >/dev/null
rm "$FHOME/commands/gpt-brainstorm.md"
before=$(snapshot "$FHOME")
check "exits nonzero" test_fails uninstall_f
check "no managed link was removed" test -L "$FHOME/CLAUDE.md"
check "home unchanged" test "$(snapshot "$FHOME")" = "$before"

echo "uninstall: directory at a managed path is a conflict"
fixture pre-dir
install_f >/dev/null
rm "$FHOME/CLAUDE.md"
mkdir "$FHOME/CLAUDE.md"
check "exits nonzero" test_fails uninstall_f
check "directory still there" test -d "$FHOME/CLAUDE.md"

echo "uninstall: clean install passes preflight"
fixture pre-clean
install_f >/dev/null
check "exits zero" uninstall_f
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/uninstall-test.sh`
Expected: new checks FAIL — `uninstall.sh` does not exist, so `uninstall_f` fails even in the "clean install passes" case, and `test_fails uninstall_f` misleadingly passes; the `exits zero` check is the honest failure. Suite exits 1.

- [ ] **Step 3: Write the preflight implementation**

Create `uninstall.sh`:

```bash
#!/usr/bin/env bash
#
# Undoes install.sh: removes the symlinks it created and restores the
# .backup-<timestamp> files it moved aside.
#
# Same philosophy as the installer: nothing is overwritten, the only thing
# ever deleted is a symlink that provably points into this repo, and when in
# doubt — a path this repo doesn't own, several backups to pick from — it
# stops and asks instead of guessing.
#
# DRY_RUN=1 runs everything (preflight, backup selection) and prints the
# exact plan without changing anything.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}"
DRY_RUN="${DRY_RUN:-0}"

source "$REPO/managed-files.sh"

if [[ "$DRY_RUN" != 0 && "$DRY_RUN" != 1 ]]; then
  echo "error: DRY_RUN must be 0 or 1 (got: $DRY_RUN)" >&2
  exit 1
fi

# ---- preflight: refuse to run unless every managed path is our symlink ------

conflicts=()
for rel in "${MANAGED_FILES[@]}"; do
  dst="$DEST/$rel"
  if [[ ! -L "$dst" && -e "$dst" ]]; then
    conflicts+=("$rel — exists but is not a symlink")
  elif [[ ! -L "$dst" ]]; then
    conflicts+=("$rel — missing (never installed, or already uninstalled)")
  elif [[ "$(readlink "$dst")" != "$REPO/$rel" ]]; then
    conflicts+=("$rel — symlink to $(readlink "$dst"), not this repo")
  elif [[ ! -w "$(dirname "$dst")" ]]; then
    conflicts+=("$rel — parent directory is not writable")
  fi
done

if (( ${#conflicts[@]} > 0 )); then
  echo "Nothing changed — these paths are not owned by this repo:" >&2
  for c in "${conflicts[@]}"; do echo "  $c" >&2; done
  echo "Resolve them manually, then re-run." >&2
  exit 1
fi

echo "Preflight ok."
```

Then: `chmod +x uninstall.sh`

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/uninstall-test.sh`
Expected: all checks pass, including every Task 1 check.

- [ ] **Step 5: Commit**

```bash
git add uninstall.sh tests/uninstall-test.sh
git commit -m "uninstall.sh: preflight refuses anything this repo does not own

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Backup discovery, plan, dry-run gate, and execution (zero/one backup)

**Files:**
- Modify: `uninstall.sh` (replace the `echo "Preflight ok."` tail)
- Test: `tests/uninstall-test.sh` (append above the summary)

**Interfaces:**
- Consumes: preflight-clean state from Task 2; `choices` does not exist yet — this task introduces it.
- Produces: the complete happy path. `choices` — array parallel to `MANAGED_FILES` holding the selected backup's absolute path or `""`. `stamp_pat='\.backup-[0-9]{8}-[0-9]{6}$'`. Multiple candidates unconditionally exit 1 listing them (Task 4 upgrades that branch to a menu when stdin is a tty — the exit-1 branch survives as the no-terminal behavior). Plan output lines use the fixed verbs `remove` / `restore` / `leave`. `DRY_RUN=1` exits 0 after printing the plan.

- [ ] **Step 1: Write the failing tests**

Insert above `# ---- summary`:

```bash
# ---- uninstall happy path ------------------------------------------------------

echo "uninstall: fresh install, no backups — links removed, paths absent"
fixture un-fresh
install_f >/dev/null
check "exits zero" uninstall_f
for rel in "${MANAGED_FILES[@]}"; do
  check "$rel absent" test_fails test -e "$FHOME/$rel"
done
check "parent dirs survive" test -d "$FHOME/agents"

echo "uninstall: single backup is restored with content and mode"
fixture un-restore
mkdir -p "$FHOME"
echo "user original" > "$FHOME/CLAUDE.md"
chmod 600 "$FHOME/CLAUDE.md"
install_f >/dev/null
check "exits zero" uninstall_f
check "content restored" grep -q "user original" "$FHOME/CLAUDE.md"
check "not a symlink anymore" test_fails test -L "$FHOME/CLAUDE.md"
check "mode restored" test "$(stat -f %Lp "$FHOME/CLAUDE.md")" = "600"
leftover=$(ls "$FHOME"/CLAUDE.md.backup-* 2>/dev/null | wc -l | tr -d ' ')
check "backup name consumed by the move" test "$leftover" = "0"

echo "uninstall: backup that is a (dangling) symlink is moved, not dereferenced"
fixture un-symlink
mkdir -p "$FHOME"
ln -s /nonexistent/target "$FHOME/CLAUDE.md"
install_f >/dev/null
check "exits zero" uninstall_f
check "restored as symlink" test -L "$FHOME/CLAUDE.md"
check "raw target preserved" test "$(readlink "$FHOME/CLAUDE.md")" = "/nonexistent/target"

echo "uninstall: malformed backup suffixes are ignored"
fixture un-malformed
install_f >/dev/null
echo junk > "$FHOME/CLAUDE.md.backup-notastamp"
echo junk > "$FHOME/CLAUDE.md.backup-2026"
check "exits zero" uninstall_f
check "CLAUDE.md left absent (no valid backup)" test_fails test -e "$FHOME/CLAUDE.md"
check "malformed files untouched" test -f "$FHOME/CLAUDE.md.backup-notastamp"

echo "uninstall: unrelated files are never touched"
fixture un-unrelated
mkdir -p "$FHOME"
echo "{}" > "$FHOME/settings.json"
install_f >/dev/null
check "exits zero" uninstall_f
check "settings.json intact" grep -q "{}" "$FHOME/settings.json"

echo "uninstall: DRY_RUN=1 prints a plan and changes nothing"
fixture un-dry
mkdir -p "$FHOME"
echo "user original" > "$FHOME/CLAUDE.md"
install_f >/dev/null
before=$(snapshot "$FHOME")
out=$(DRY_RUN=1 uninstall_f)
check "home unchanged" test "$(snapshot "$FHOME")" = "$before"
check "plan mentions restore" grep -q "restore" <<<"$out"
check "plan mentions leave-absent" grep -q "leave" <<<"$out"

echo "uninstall: bad DRY_RUN value fails before changing anything"
fixture un-badflag
install_f >/dev/null
before=$(snapshot "$FHOME")
check "exits nonzero" test_fails env DRY_RUN=yes CLAUDE_HOME="$FHOME" bash "$FREPO/uninstall.sh"
check "home unchanged" test "$(snapshot "$FHOME")" = "$before"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/uninstall-test.sh`
Expected: FAIL — clean fixtures print `Preflight ok.` and exit 0 but remove nothing, so the `$rel absent` and restore checks fail.

- [ ] **Step 3: Replace the tail of uninstall.sh**

Delete the line `echo "Preflight ok."` and append:

```bash
# ---- discover backups; decide what to restore --------------------------------

stamp_pat='\.backup-[0-9]{8}-[0-9]{6}$'
choices=()   # parallel to MANAGED_FILES: backup to restore, "" for none

for rel in "${MANAGED_FILES[@]}"; do
  dst="$DEST/$rel"

  candidates=()   # fixed-width stamps make glob order chronological
  for b in "$dst".backup-*; do
    [[ -e "$b" || -L "$b" ]] || continue   # unmatched glob stays a literal
    [[ "$b" =~ $stamp_pat ]] || continue   # ignore malformed names
    candidates+=("$b")
  done

  if (( ${#candidates[@]} <= 1 )); then
    choices+=("${candidates[0]-}")
    continue
  fi

  echo "error: $rel has ${#candidates[@]} backups and no way to choose one:" >&2
  for b in "${candidates[@]}"; do echo "  ${b#"$DEST"/}" >&2; done
  echo "Re-run interactively, or move aside the backups you don't want restored." >&2
  exit 1
done

# ---- validate the whole plan before touching anything -------------------------

i=0
for rel in "${MANAGED_FILES[@]}"; do
  dst="$DEST/$rel"; sel="${choices[i]}"; i=$((i + 1))
  if [[ ! -L "$dst" || "$(readlink "$dst")" != "$REPO/$rel" ]]; then
    echo "error: $rel changed while the plan was being made — nothing changed." >&2
    exit 1
  fi
  if [[ -n "$sel" && ! -e "$sel" && ! -L "$sel" ]]; then
    echo "error: ${sel#"$DEST"/} disappeared — nothing changed." >&2
    exit 1
  fi
done

# ---- the plan ------------------------------------------------------------------

echo "Plan for $DEST:"
i=0
for rel in "${MANAGED_FILES[@]}"; do
  sel="${choices[i]}"; i=$((i + 1))
  echo "  remove   $rel"
  if [[ -n "$sel" ]]; then
    echo "  restore  ${sel#"$DEST"/}"
  else
    echo "  leave    $rel absent (no backup)"
  fi
done

if [[ "$DRY_RUN" == 1 ]]; then
  echo "DRY RUN — nothing was changed."
  exit 0
fi

# ---- execute -------------------------------------------------------------------

removed=0; restored=0; absent=0
i=0
for rel in "${MANAGED_FILES[@]}"; do
  dst="$DEST/$rel"; sel="${choices[i]}"; i=$((i + 1))

  # last-instant recheck; on failure report what already completed
  if [[ ! -L "$dst" || "$(readlink "$dst")" != "$REPO/$rel" ]]; then
    echo "error: $rel changed mid-run — stopping." >&2
    echo "Completed before stopping: $removed removed, $restored restored." >&2
    exit 1
  fi
  if [[ -n "$sel" && ! -e "$sel" && ! -L "$sel" ]]; then
    echo "error: ${sel#"$DEST"/} disappeared mid-run — stopping." >&2
    echo "Completed before stopping: $removed removed, $restored restored." >&2
    exit 1
  fi

  rm "$dst"
  removed=$((removed + 1))

  if [[ -n "$sel" ]]; then
    mv "$sel" "$dst"
    restored=$((restored + 1))
  else
    absent=$((absent + 1))
  fi
done

echo "Done: $removed symlinks removed, $restored backups restored, $absent paths left absent."
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/uninstall-test.sh && bash -n uninstall.sh`
Expected: all checks pass (Tasks 1–3), `bash -n` silent.

- [ ] **Step 5: Commit**

```bash
git add uninstall.sh tests/uninstall-test.sh
git commit -m "uninstall.sh: restore backups, print the plan, honor DRY_RUN

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Interactive choice among multiple backups

**Files:**
- Modify: `uninstall.sh` (the multiple-candidates branch from Task 3)
- Test: `tests/uninstall-test.sh` (append above the summary)

**Interfaces:**
- Consumes: the `candidates` array and the exit-1 multiple-backups branch from Task 3.
- Produces: when stdin is a tty, a numbered menu (oldest first, symlink candidates annotated with their target); input validated as an in-range base-10 integer, re-prompted on garbage, aborted on EOF. The Task 3 exit-1 branch becomes the `[[ ! -t 0 ]]` path verbatim. Test helper `run_pty <input> <cmd...>` gives the command a pseudo-terminal.

- [ ] **Step 1: Write the failing tests**

Add this helper next to `test_fails` in the harness:

```bash
# run_pty <input-lines> <command...> — run the command on a pseudo-terminal
# (so [[ -t 0 ]] is true) feeding it input. BSD and util-linux `script`
# disagree on syntax; try BSD (macOS) first.
run_pty() {
  local input="$1"; shift
  if script -q /dev/null true >/dev/null 2>&1; then
    printf '%s\n' "$input" | script -q /dev/null "$@"
  else
    printf '%s\n' "$input" | script -qec "$*" /dev/null
  fi
}
```

Insert above `# ---- summary`:

```bash
# ---- uninstall: multiple backups -----------------------------------------------

# make_two_backups — fixture with two valid backup candidates for CLAUDE.md
make_two_backups() {
  fixture "$1"
  mkdir -p "$FHOME"
  echo "older original" > "$FHOME/CLAUDE.md"
  install_f >/dev/null
  # forge a second, later-stamped backup alongside the installer's real one
  echo "newer original" > "$FHOME/CLAUDE.md.backup-20990101-000000"
}

echo "uninstall: multiple backups + no terminal = refuse, unchanged"
make_two_backups multi-notty
before=$(snapshot "$FHOME")
check "exits nonzero" test_fails uninstall_f
check "home unchanged" test "$(snapshot "$FHOME")" = "$before"

echo "uninstall: menu selection restores the chosen backup"
make_two_backups multi-pick
CLAUDE_HOME="$FHOME" run_pty "2" bash "$FREPO/uninstall.sh" >/dev/null
check "picked the second (newer) candidate" grep -q "newer original" "$FHOME/CLAUDE.md"
check "unselected backup untouched" ls "$FHOME"/CLAUDE.md.backup-* >/dev/null

echo "uninstall: garbage input is re-prompted, then honored"
make_two_backups multi-garbage
CLAUDE_HOME="$FHOME" run_pty "$(printf 'x\n9\n1')" bash "$FREPO/uninstall.sh" >/dev/null
check "eventually restored first candidate" grep -q "older original" "$FHOME/CLAUDE.md"

echo "uninstall: DRY_RUN with interactive selection changes nothing"
make_two_backups multi-dry
before=$(snapshot "$FHOME")
DRY_RUN=1 CLAUDE_HOME="$FHOME" run_pty "1" bash "$FREPO/uninstall.sh" >/dev/null
check "home unchanged" test "$(snapshot "$FHOME")" = "$before"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/uninstall-test.sh`
Expected: the no-terminal case already passes (Task 3 branch); the pty cases FAIL because the script exits 1 instead of showing a menu.

- [ ] **Step 3: Implement the menu**

In `uninstall.sh`, replace the Task 3 multiple-candidates block:

```bash
  echo "error: $rel has ${#candidates[@]} backups and no way to choose one:" >&2
  for b in "${candidates[@]}"; do echo "  ${b#"$DEST"/}" >&2; done
  echo "Re-run interactively, or move aside the backups you don't want restored." >&2
  exit 1
```

with:

```bash
  if [[ ! -t 0 ]]; then
    echo "error: $rel has ${#candidates[@]} backups and no terminal to choose one:" >&2
    for b in "${candidates[@]}"; do echo "  ${b#"$DEST"/}" >&2; done
    echo "Re-run interactively, or move aside the backups you don't want restored." >&2
    exit 1
  fi

  echo "$rel has ${#candidates[@]} backups (oldest first):"
  n=1
  for b in "${candidates[@]}"; do
    extra=""
    [[ -L "$b" ]] && extra="   (symlink -> $(readlink "$b"))"
    echo "  $n) ${b#"$DEST"/}$extra"
    n=$((n + 1))
  done
  while :; do
    if ! read -r -p "Restore which? [1-${#candidates[@]}] " pick; then
      echo "Aborted — nothing changed." >&2
      exit 1
    fi
    if [[ "$pick" =~ ^[0-9]+$ ]] && (( 10#$pick >= 1 && 10#$pick <= ${#candidates[@]} )); then
      break
    fi
    echo "Enter a number between 1 and ${#candidates[@]}."
  done
  choices+=("${candidates[10#$pick - 1]}")
```

(EOF-mid-prompt abort is exercised manually — `yes '' | ...` closes stdin oddly under a pty and is flaky in CI; the `if ! read` branch is the entire mechanism and is 3 lines.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/uninstall-test.sh && bash -n uninstall.sh`
Expected: all checks pass.

- [ ] **Step 5: Commit**

```bash
git add uninstall.sh tests/uninstall-test.sh
git commit -m "uninstall.sh: interactive choice among multiple backups

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: README, rerun test, and lint pass

**Files:**
- Modify: `README.md` (Install section and "What's here" table)
- Test: `tests/uninstall-test.sh` (append above the summary)

**Interfaces:**
- Consumes: the finished `uninstall.sh` behavior from Tasks 2–4.
- Produces: user-facing docs; the completed regression matrix.

- [ ] **Step 1: Write the failing test (rerun after uninstall)**

Insert above `# ---- summary`:

```bash
# ---- uninstall: rerun ------------------------------------------------------------

echo "uninstall: second run reports conflicts, changes nothing"
fixture rerun
install_f >/dev/null
uninstall_f >/dev/null
before=$(snapshot "$FHOME")
check "second run exits nonzero" test_fails uninstall_f
check "home unchanged" test "$(snapshot "$FHOME")" = "$before"
```

- [ ] **Step 2: Run tests to verify it passes already**

Run: `bash tests/uninstall-test.sh`
Expected: PASS — the missing-path conflict branch from Task 2 already produces this behavior. This test pins the spec's "safe to rerun, but not a silent no-op" requirement so a future refactor can't lose it.

- [ ] **Step 3: Update README.md**

In the `## Install` section, after the existing code block, append:

```markdown
To undo an install:

```bash
DRY_RUN=1 ./uninstall.sh   # preflight + backup selection + exact plan, no changes
./uninstall.sh
```

It removes only symlinks that point into this repo, then restores the
`.backup-<timestamp>` files install.sh created. If anything at a managed
path is *not* owned by this repo — a plain file, someone else's symlink, a
missing path — it lists every conflict and exits without changing anything.
A file with several backups gets a numbered prompt (it refuses to guess,
and refuses to run non-interactively until you thin the backups out). A
path that had no backup is removed and left absent, because nothing was
there before install. Uninstalling twice is safe but the second run exits
nonzero: with no record of *why* the paths are gone, it reports them as
conflicts rather than claiming success.
```

In the `## What's here` table, add rows:

```markdown
| `managed-files.sh` | The one list of managed paths both scripts source. |
| `uninstall.sh` | Removes the symlinks and restores the backups; conservative to a fault. See Install. |
| `tests/uninstall-test.sh` | Self-contained regression suite for both scripts (runs in a throwaway tmpdir). |
```

- [ ] **Step 4: Full verification pass**

Run:

```bash
bash tests/uninstall-test.sh
bash -n install.sh uninstall.sh managed-files.sh tests/uninstall-test.sh
command -v shellcheck >/dev/null && shellcheck install.sh uninstall.sh managed-files.sh tests/uninstall-test.sh || echo "shellcheck not installed — skipped (dev-only check)"
```

Expected: every check passes; `bash -n` silent; shellcheck clean or explicitly skipped. Fix any shellcheck findings that are real; disable-comment style nits only with a reason.

- [ ] **Step 5: Commit**

```bash
git add README.md tests/uninstall-test.sh
git commit -m "Document uninstall.sh and pin the rerun behavior

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Spec coverage map

| Spec requirement | Task |
|---|---|
| `managed-files.sh` manifest, Bash 3.2, data-only | 1 |
| `install.sh` sources manifest, behavior preserved | 1 |
| Installer regression (links, backups, dry-run) | 1 |
| Preflight ownership; conflicts (missing/regular/dir/foreign link/unwritable parent); report-all-then-exit | 2 |
| Partial install blocks everything | 2 |
| Backup discovery: exact stamp pattern, malformed ignored, dangling-symlink candidates, oldest-first | 3 |
| Zero backups → remove + leave absent; one → auto-restore | 3 |
| Whole-plan validation before mutation; per-entry recheck during execution; stop-and-report on mid-run failure | 3 |
| `DRY_RUN` value validation; dry-run prints exact plan, changes nothing | 3 |
| `mv` semantics: type/mode/symlink identity preserved, backup name consumed, never overwrite, parents kept | 3 |
| `settings.json` / unrelated files untouched; custom `CLAUDE_HOME` (all tests use it) | 3 |
| Interactive numbered menu, validated base-10 input, re-prompt, EOF abort | 4 |
| No-terminal-with-ambiguity refusal; unselected backups untouched; dry-run with interaction | 4 |
| README (usage, conflict behavior, no silent idempotency); rerun-after-uninstall pinned; `bash -n` + shellcheck | 5 |
| Empty `CLAUDE_HOME` falls back to `$HOME/.claude` | Global Constraints (verified by inspection — identical expansion to install.sh) |
