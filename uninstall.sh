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
