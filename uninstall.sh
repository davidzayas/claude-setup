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

# ---- discover backups; decide what to restore --------------------------------

stamp_pat='^\.backup-[0-9]{8}-[0-9]{6}$'
choices=()   # parallel to MANAGED_FILES: backup to restore, "" for none

for rel in "${MANAGED_FILES[@]}"; do
  dst="$DEST/$rel"

  candidates=()   # fixed-width stamps make glob order chronological among these
  for b in "$dst".backup-*; do
    [[ -e "$b" || -L "$b" ]] || continue   # unmatched glob stays a literal
    [[ "${b#"$dst"}" =~ $stamp_pat ]] || continue   # ignore malformed names
    candidates+=("$b")
  done

  if (( ${#candidates[@]} <= 1 )); then
    choices+=("${candidates[0]-}")
    continue
  fi

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

  if ! rm "$dst"; then
    echo "error: could not remove $rel — stopping." >&2
    echo "Completed before stopping: $removed removed, $restored restored." >&2
    exit 1
  fi
  removed=$((removed + 1))

  if [[ -n "$sel" ]]; then
    # last-instant guard: never restore onto something that reappeared
    if [[ -e "$dst" || -L "$dst" ]]; then
      echo "error: something reappeared at $rel before restore — stopping." >&2
      echo "Completed before stopping: $removed removed, $restored restored." >&2
      echo "The chosen backup is still at ${sel#"$DEST"/}." >&2
      exit 1
    fi
    if ! mv "$sel" "$dst"; then
      echo "error: could not restore ${sel#"$DEST"/} — stopping." >&2
      echo "Completed before stopping: $removed removed, $restored restored." >&2
      echo "The chosen backup is still at ${sel#"$DEST"/}." >&2
      exit 1
    fi
    restored=$((restored + 1))
  else
    absent=$((absent + 1))
  fi
done

echo "Done: $removed symlinks removed, $restored backups restored, $absent paths left absent."
