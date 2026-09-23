#!/usr/bin/env bash
#
# install-claude-lsp-plugins.sh
# Installs Claude Code's official code intelligence (LSP) plugins for
# C/C++, C#, Go, Java, Kotlin, Python, Rust, Swift, and TypeScript.
#
# Each plugin is only installed if its language server binary is on PATH,
# so run install-lsp-binaries.sh first.
#
# Usage: ./install-claude-lsp-plugins.sh [user|project|local]
#   user    (default) – for you, across all projects
#   project – for everyone on the repo (writes .claude/settings.json); run from the repo root
#   local   – for you, in the current repo only
#
set -uo pipefail

SCOPE="${1:-user}"
MARKETPLACE="claude-plugins-official"
MARKETPLACE_SRC="anthropics/claude-plugins-official"

# plugin:binary pairs (plain list for macOS's bash 3.2)
PLUGINS="
clangd-lsp:clangd
csharp-lsp:csharp-ls
gopls-lsp:gopls
jdtls-lsp:jdtls
kotlin-lsp:kotlin-language-server
pyright-lsp:pyright-langserver
rust-analyzer-lsp:rust-analyzer
swift-lsp:sourcekit-lsp
typescript-lsp:typescript-language-server
"

log()  { printf "\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n" "$*"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
err()  { printf "  \033[31m✗\033[0m %s\n" "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

case "$SCOPE" in
  user|project|local) ;;
  *) echo "Invalid scope '$SCOPE'. Use: user | project | local"; exit 1 ;;
esac

# Make sure dotnet global tools are visible even if the shell wasn't restarted
export PATH="$PATH:$HOME/.dotnet/tools"

have claude || { err "Claude Code CLI ('claude') not found on PATH."; exit 1; }
log "Claude Code $(claude --version 2>/dev/null | head -n1) — scope: $SCOPE"

# Ensure the official marketplace is registered
log "Checking marketplace '$MARKETPLACE'"
if claude plugin marketplace list 2>/dev/null | grep -q "$MARKETPLACE"; then
  ok "already added"
else
  if claude plugin marketplace add "$MARKETPLACE_SRC"; then
    ok "added $MARKETPLACE_SRC"
  else
    err "could not add marketplace (network/proxy or managed policy?)"; exit 1
  fi
fi

INSTALLED=(); SKIPPED=(); FAILED=()

log "Installing plugins"
for entry in $PLUGINS; do
  plugin="${entry%%:*}"
  bin="${entry#*:}"

  if ! have "$bin"; then
    warn "$plugin skipped — '$bin' not on PATH"
    SKIPPED+=("$plugin"); continue
  fi

  if claude plugin install "${plugin}@${MARKETPLACE}" --scope "$SCOPE"; then
    ok "$plugin"
    INSTALLED+=("$plugin")
  else
    err "$plugin failed"
    FAILED+=("$plugin")
  fi
done

log "Summary"
echo "  Installed: ${INSTALLED[*]:-none}"
echo "  Skipped:   ${SKIPPED[*]:-none}"
echo "  Failed:    ${FAILED[*]:-none}"
echo
echo "Start a new Claude Code session (or run /reload-plugins in an open one)."
echo "Check /plugin → Errors if a language server does not start; see README.md → Troubleshooting."

[[ ${#FAILED[@]} -eq 0 ]]
