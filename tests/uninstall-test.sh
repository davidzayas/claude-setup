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
