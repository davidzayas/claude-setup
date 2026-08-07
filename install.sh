#!/usr/bin/env bash
#
# Symlinks this repo's config into ~/.claude.
#
# Symlinks rather than copies, so editing either path edits the same file and
# git sees your changes. A copy would start drifting the moment you tuned
# anything.
#
# Anything already in place is moved aside to <name>.backup-<timestamp> first.
# Nothing is overwritten, and nothing is deleted.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}"
STAMP="$(date +%Y%m%d-%H%M%S)"
DRY_RUN="${DRY_RUN:-0}"

FILES=(
  CLAUDE.md
  agents/codex-adversary.md
  commands/adversarial-review.md
  commands/gpt-brainstorm.md
  skills/gpt-brainstorming/SKILL.md
)

link() {
  local rel="$1" src="$REPO/$1" dst="$DEST/$1"

  if [[ "$(readlink "$dst" 2>/dev/null)" == "$src" ]]; then
    echo "  ok       $rel (already linked)"
    return
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
    echo "  backup   $rel -> $rel.backup-$STAMP"
    [[ "$DRY_RUN" == "1" ]] || mv "$dst" "$dst.backup-$STAMP"
  fi

  echo "  link     $rel"
  [[ "$DRY_RUN" == "1" ]] || { mkdir -p "$(dirname "$dst")"; ln -s "$src" "$dst"; }
}

[[ "$DRY_RUN" == "1" ]] && echo "DRY RUN — nothing will be changed."
echo "Linking into $DEST"
for f in "${FILES[@]}"; do link "$f"; done

echo
echo "settings.json is NOT linked — yours almost certainly has keys this repo"
echo "does not (auth, MCP servers, machine-specific paths). Merge by hand:"
echo "  diff <(python3 -m json.tool '$REPO/settings.json') \\"
echo "       <(python3 -m json.tool '$DEST/settings.json')"
echo
echo "Note: this repo's settings.json deliberately omits permissions.defaultMode"
echo "and skipDangerousModePermissionPrompt. See README.md before adding them."
