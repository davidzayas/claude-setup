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

# test_fails <command...> — succeeds iff the command exits nonzero
test_fails() { if "$@" >/dev/null 2>&1; then return 1; else return 0; fi; }

# present <path> — true if anything is at the path, including a dangling symlink
present() { [[ -e "$1" || -L "$1" ]]; }

# run_pty <input-lines> <command...> — run the command on a pseudo-terminal
# (so [[ -t 0 ]] is true) feeding it input. BSD and util-linux `script`
# disagree on syntax; try BSD (macOS) first.
run_pty() {
  local input="$1"; shift
  # keep the writer open briefly: BSD script forwards EOF from a closed
  # stdin pipe before the buffered input reaches the child's pty
  if script -q /dev/null true >/dev/null 2>&1; then
    { printf '%s\n' "$input"; sleep 1; } | script -q /dev/null "$@"
  else
    { printf '%s\n' "$input"; sleep 1; } | script -qec "$*" /dev/null
  fi
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

# SKIP_CHECKS: these fixtures test linking/backup mechanics, not the
# dependency preflight (which has its own shim-based cases below), and must
# not depend on what's installed on the developer machine.
install_f()   { CLAUDE_HOME="$FHOME" SKIP_CHECKS=1 bash "$FREPO/install.sh" "$@"; }
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

# ---- preflight shims -----------------------------------------------------------
# Preflight cases run install.sh under a sanitized PATH containing only a
# per-fixture bin dir plus /usr/bin:/bin, so the developer machine's real
# claude/codex are never consulted. Each shim drops a "<name>.called"
# marker beside itself so tests can assert whether a probe ran.

shim_dir() { SHIMBIN="$TMP/$1/bin"; mkdir -p "$SHIMBIN"; }

# shim_claude <mcp-get-exit-code> — answers `mcp get codex` with the given
# status; anything else exits 0.
shim_claude() {
  cat > "$SHIMBIN/claude" <<EOF
#!/bin/sh
: >> "\$0.called"
if [ "\$1" = "mcp" ] && [ "\$2" = "get" ] && [ "\$3" = "codex" ]; then
  exit $1
fi
exit 0
EOF
  chmod +x "$SHIMBIN/claude"
}

# shim_codex [version-line] — answers --version with the given line
# (default "codex-cli 0.146.1"); anything else exits 0.
shim_codex() {
  cat > "$SHIMBIN/codex" <<EOF
#!/bin/sh
: >> "\$0.called"
if [ "\$1" = "--version" ]; then
  echo "${1:-codex-cli 0.146.1}"
  exit 0
fi
exit 0
EOF
  chmod +x "$SHIMBIN/codex"
}

# preflight_install [VAR=val ...] — install.sh with sanitized PATH; extra
# env pairs (DRY_RUN=1, SKIP_CHECKS=1, ...) go before the command.
preflight_install() {
  env PATH="$SHIMBIN:/usr/bin:/bin" CLAUDE_HOME="$FHOME" "$@" \
    bash "$FREPO/install.sh"
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

# ---- uninstall happy path ------------------------------------------------------

echo "uninstall: fresh install, no backups — links removed, paths absent"
fixture un-fresh
install_f >/dev/null
check "exits zero" uninstall_f
for rel in "${MANAGED_FILES[@]}"; do
  check "$rel absent" test_fails present "$FHOME/$rel"
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
leftover=$(find "$FHOME" -maxdepth 1 -name 'CLAUDE.md.backup-*' | wc -l | tr -d ' ')
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
echo junk > "$FHOME/CLAUDE.md.backup-junk.backup-20990101-000000"
check "exits zero" uninstall_f
check "CLAUDE.md left absent (no valid backup)" test_fails present "$FHOME/CLAUDE.md"
check "malformed files untouched" test -f "$FHOME/CLAUDE.md.backup-notastamp"
check "double-suffix name untouched" test -f "$FHOME/CLAUDE.md.backup-junk.backup-20990101-000000"

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
check "empty DRY_RUN rejected" test_fails env DRY_RUN= CLAUDE_HOME="$FHOME" bash "$FREPO/uninstall.sh"
check "home unchanged" test "$(snapshot "$FHOME")" = "$before"

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
check "exits nonzero" test_fails uninstall_f </dev/null
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

# ---- uninstall: rerun ------------------------------------------------------------

echo "uninstall: second run reports conflicts, changes nothing"
fixture rerun
install_f >/dev/null
uninstall_f >/dev/null
before=$(snapshot "$FHOME")
check "second run exits nonzero" test_fails uninstall_f
check "home unchanged" test "$(snapshot "$FHOME")" = "$before"

# ---- install preflight ---------------------------------------------------------

echo "preflight: all prerequisites pass, install proceeds, honest wording"
fixture pf-pass; shim_dir pf-pass; shim_claude 0; shim_codex
out="$(preflight_install 2>&1)" || bad "pf-pass exited nonzero"
check "links created" test -L "$FHOME/CLAUDE.md"
check "credentials-untested wording" grep -q "live credentials not tested" <<<"$out"

echo "preflight: both binaries missing — both reported, nothing changed"
fixture pf-none; shim_dir pf-none
before=$(snapshot "$FHOME")
out="$(preflight_install 2>&1)" && bad "pf-none should have failed" || ok "exits nonzero"
check "reports claude missing" grep -q "claude CLI not found" <<<"$out"
check "reports codex missing" grep -q "codex CLI not found" <<<"$out"
check "established voice" grep -q "Nothing changed — required dependencies" <<<"$out"
check "mentions SKIP_CHECKS" grep -q "SKIP_CHECKS=1" <<<"$out"
check "home unchanged" test "$(snapshot "$FHOME")" = "$before"

echo "preflight: claude missing — MCP check skipped, not a second failure"
fixture pf-noclaude; shim_dir pf-noclaude; shim_codex
out="$(preflight_install 2>&1)" && bad "pf-noclaude should have failed" || ok "exits nonzero"
check "reports claude missing" grep -q "claude CLI not found" <<<"$out"
check "MCP reported as skipped" grep -q "skip     codex MCP registration" <<<"$out"
check "MCP not a failure" test_fails grep -q "could not be verified" <<<"$out"

echo "preflight: codex missing — remediation names the pinned install"
fixture pf-nocodex; shim_dir pf-nocodex; shim_claude 0
out="$(preflight_install 2>&1)" && bad "pf-nocodex should have failed" || ok "exits nonzero"
check "reports codex missing" grep -q "codex CLI not found" <<<"$out"
check "names the pin" grep -q "@openai/codex@0.146.1" <<<"$out"

echo "preflight: MCP lookup fails — 'could not be verified', nothing changed"
fixture pf-nomcp; shim_dir pf-nomcp; shim_claude 1; shim_codex
before=$(snapshot "$FHOME")
out="$(preflight_install 2>&1)" && bad "pf-nomcp should have failed" || ok "exits nonzero"
check "could-not-verify wording" grep -q "could not be verified" <<<"$out"
check "home unchanged" test "$(snapshot "$FHOME")" = "$before"

echo "preflight: dry run with failures — advisory, preview shown, exit 0"
fixture pf-dry; shim_dir pf-dry
before=$(snapshot "$FHOME")
out="$(preflight_install DRY_RUN=1 2>&1)" || bad "dry run should exit 0"
check "advisory label" grep -q "advisory" <<<"$out"
check "preview still shown" grep -q "link     CLAUDE.md" <<<"$out"
check "home unchanged" test "$(snapshot "$FHOME")" = "$before"

echo "preflight: SKIP_CHECKS=1 — probes not invoked, install proceeds"
fixture pf-skip; shim_dir pf-skip; shim_claude 0; shim_codex
out="$(preflight_install SKIP_CHECKS=1 2>&1)" || bad "pf-skip exited nonzero"
check "links created" test -L "$FHOME/CLAUDE.md"
check "bypass notice printed" grep -q "preflight bypassed" <<<"$out"
check "claude probe not invoked" test_fails test -f "$SHIMBIN/claude.called"
check "codex probe not invoked" test_fails test -f "$SHIMBIN/codex.called"

echo "preflight: invalid flag values fail before anything"
fixture pf-flags; shim_dir pf-flags; shim_claude 0; shim_codex
before=$(snapshot "$FHOME")
check "SKIP_CHECKS=2 rejected" test_fails preflight_install SKIP_CHECKS=2
check "DRY_RUN=abc rejected" test_fails preflight_install DRY_RUN=abc
check "whitespace-padded DRY_RUN rejected" test_fails preflight_install DRY_RUN=" 1"
check "empty DRY_RUN rejected" test_fails preflight_install DRY_RUN=
check "empty SKIP_CHECKS rejected" test_fails preflight_install SKIP_CHECKS=
check "claude probe not invoked on bad flags" test_fails test -f "$SHIMBIN/claude.called"
check "codex probe not invoked on bad flags" test_fails test -f "$SHIMBIN/codex.called"
check "home unchanged" test "$(snapshot "$FHOME")" = "$before"

echo "preflight: broken codex --version is a warning, not a gate"
fixture pf-warn; shim_dir pf-warn; shim_claude 0
cat > "$SHIMBIN/codex" <<'EOF'
#!/bin/sh
: >> "$0.called"
exit 1
EOF
chmod +x "$SHIMBIN/codex"
check "still installs" preflight_install
check "links created" test -L "$FHOME/CLAUDE.md"

# ---- summary -------------------------------------------------------------------

echo
echo "$PASS passed, $FAIL failed"
if (( FAIL > 0 )); then exit 1; fi
