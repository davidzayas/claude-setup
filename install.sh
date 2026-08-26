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
DRY_RUN="${DRY_RUN-0}"
SKIP_CHECKS="${SKIP_CHECKS-0}"

source "$REPO/managed-files.sh"

for flag in DRY_RUN SKIP_CHECKS; do
  val="${!flag}"
  if [[ "$val" != 0 && "$val" != 1 ]]; then
    echo "error: $flag must be 0 or 1 (got: $val)" >&2
    exit 1
  fi
done

# ---- preflight: the pipeline this config drives needs these working --------
#
# Presence and registration are the only things checkable offline. A clean
# preflight does NOT prove credentials — only a live request does; see
# README "Prerequisites" for the layered verification.

missing=()

if [[ "$SKIP_CHECKS" == 1 ]]; then
  echo "SKIP_CHECKS=1 — dependency preflight bypassed."
else
  have_claude=0
  if command -v claude >/dev/null 2>&1; then
    have_claude=1
    echo "  found    claude"
  else
    missing+=("claude CLI not found in PATH — install Claude Code first")
  fi

  if command -v codex >/dev/null 2>&1; then
    ver="$(codex --version 2>/dev/null || true)"
    echo "  found    codex (${ver:-version unknown})"
    echo "  note     Azure providers need 0.149.1+ (0.147.0–0.148.x are broken) — see docs/azure-openai-codex.md"
  else
    missing+=("codex CLI not found in PATH — npm install -g @openai/codex@0.149.1")
  fi

  if [[ "$have_claude" == 1 ]]; then
    if claude mcp get codex >/dev/null 2>&1; then
      echo "  found    codex MCP registration (handshake only — live credentials not tested)"
    else
      missing+=("codex MCP registration could not be verified (claude mcp get codex failed)")
    fi
  else
    echo "  skip     codex MCP registration (needs the claude CLI)"
  fi
  echo "  note     superpowers plugin is not checked — it comes from settings.json (merge by hand)"

  if (( ${#missing[@]} > 0 )); then
    if [[ "$DRY_RUN" == 1 ]]; then
      echo "advisory (dry run): required dependencies are unavailable:"
      for m in "${missing[@]}"; do echo "  $m"; done
    else
      echo "Nothing changed — required dependencies are unavailable:" >&2
      for m in "${missing[@]}"; do echo "  $m" >&2; done
      echo "Install them first (README: Prerequisites), or re-run with" >&2
      echo "SKIP_CHECKS=1 to link the config files anyway." >&2
      exit 1
    fi
  fi
fi

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
for f in "${MANAGED_FILES[@]}"; do link "$f"; done

echo
echo "settings.json is NOT linked — yours almost certainly has keys this repo"
echo "does not (auth, MCP servers, machine-specific paths). Merge by hand:"
echo "  diff <(python3 -m json.tool '$REPO/settings.json') \\"
echo "       <(python3 -m json.tool '$DEST/settings.json')"
echo
echo "Note: this repo's settings.json deliberately omits permissions.defaultMode"
echo "and skipDangerousModePermissionPrompt. See README.md before adding them."
