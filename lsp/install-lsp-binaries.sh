#!/usr/bin/env bash
#
# install-lsp-binaries.sh
# Installs the language server binaries required by Claude Code's official
# code intelligence (LSP) plugins on macOS.
#
# Languages: C/C++, C#, Go, Java, Kotlin, Python, Rust, Swift, TypeScript
#
# Safe to re-run: anything already installed is skipped.
# Usage: ./install-lsp-binaries.sh
#
set -uo pipefail

# ---------- helpers ----------------------------------------------------------
log()  { printf "\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n" "$*"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
err()  { printf "  \033[31m✗\033[0m %s\n" "$*"; }

FAILED=()
have() { command -v "$1" >/dev/null 2>&1; }

brew_install() {
  local formula="$1"
  if brew list --formula "$formula" >/dev/null 2>&1; then
    ok "$formula already installed"
  elif brew install "$formula"; then
    ok "installed $formula"
  else
    err "failed to install $formula"; FAILED+=("$formula")
  fi
}

# Symlink a binary into Homebrew's bin dir so it's on PATH
link_into_path() {
  local name="$1" target="$2"
  if ln -sf "$target" "$BREW_BIN/$name"; then
    ok "linked $name -> $target"
  else
    err "could not link $name"; FAILED+=("$name")
  fi
}

add_to_zprofile() {
  local line="$1"
  touch "$HOME/.zprofile"
  grep -qxF "$line" "$HOME/.zprofile" || echo "$line" >> "$HOME/.zprofile"
}

# ts_shadowed <resolved-path> <homebrew-path> — true when Homebrew's
# typescript-language-server exists but PATH resolves a different copy first
# (typically an npm -g install under nvm/fnm/asdf; see docs/lsp-setup.md).
ts_shadowed() {
  [[ -n "$1" && -x "$2" && "$1" != "$2" ]]
}

# Test seam: tests/lsp-installers-test.sh sources this file with
# LSP_BINARIES_SOURCE_ONLY=1 to reach the helpers above without provisioning.
# (`return` fails when executed rather than sourced, hence the exit fallback.)
if [[ "${LSP_BINARIES_SOURCE_ONLY:-0}" == 1 ]]; then return 0 2>/dev/null || exit 0; fi

# ---------- prerequisites ----------------------------------------------------
[[ "$(uname)" == "Darwin" ]] || { echo "This script is for macOS only."; exit 1; }

log "Checking prerequisites"

if ! xcode-select -p >/dev/null 2>&1; then
  warn "Xcode Command Line Tools not found. Launching the installer..."
  xcode-select --install
  echo "Re-run this script once the Command Line Tools installer finishes."
  exit 1
fi
ok "Xcode Command Line Tools: $(xcode-select -p)"

if ! have brew; then
  warn "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi
have brew || { err "Homebrew is still not available; aborting."; exit 1; }
ok "Homebrew: $(brew --prefix)"
BREW_BIN="$(brew --prefix)/bin"

brew update >/dev/null 2>&1 || warn "brew update failed; continuing with cached formulae"

# ---------- C/C++: clangd ----------------------------------------------------
log "C/C++ → clangd"
if have clangd; then
  ok "clangd already on PATH ($(command -v clangd))"
elif p="$(xcrun --find clangd 2>/dev/null)" && [[ -n "$p" ]]; then
  link_into_path clangd "$p"          # use Apple's toolchain clangd
else
  # LLVM is keg-only; link only clangd so Apple clang stays the default compiler
  brew_install llvm
  link_into_path clangd "$(brew --prefix llvm)/bin/clangd"
fi

# ---------- C#: csharp-ls ----------------------------------------------------
# Current csharp-ls releases need the .NET 10 SDK/runtime. Many machines already
# have an older .NET (e.g. Homebrew's dotnet@8) and a DOTNET_ROOT pointing at it,
# which breaks both installing and launching csharp-ls. So we:
#   1. install the current .NET SDK cask to /usr/local/share/dotnet (side by side;
#      it does not replace or change your existing .NET),
#   2. install csharp-ls using THAT dotnet,
#   3. put a small wrapper on PATH that launches csharp-ls with
#      DOTNET_ROOT=/usr/local/share/dotnet, without touching your global DOTNET_ROOT.
log "C# → csharp-ls"
DOTNET_NEW_ROOT="/usr/local/share/dotnet"
DOTNET_NEW="$DOTNET_NEW_ROOT/dotnet"
CSHARP_LS_REAL="$HOME/.dotnet/tools/csharp-ls"

has_net10_sdk() {
  [[ -x "$DOTNET_NEW" ]] && "$DOTNET_NEW" --list-sdks 2>/dev/null | grep -Eq '^(1[0-9]|[2-9][0-9])\.'
}

if has_net10_sdk; then
  ok ".NET 10+ SDK present at $DOTNET_NEW_ROOT"
else
  warn "Installing current .NET SDK to $DOTNET_NEW_ROOT (may prompt for your password)"
  if brew list --cask dotnet-sdk >/dev/null 2>&1; then
    brew upgrade --cask dotnet-sdk || true
  else
    brew install --cask dotnet-sdk || true
  fi
  has_net10_sdk && ok ".NET SDK installed: $("$DOTNET_NEW" --list-sdks | tail -n1)" \
    || { err ".NET 10+ SDK still not found at $DOTNET_NEW_ROOT"; FAILED+=("dotnet-sdk"); }
fi

add_to_zprofile 'export PATH="$PATH:$HOME/.dotnet/tools"'
export PATH="$PATH:$HOME/.dotnet/tools"

if has_net10_sdk; then
  export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
  if [[ -x "$CSHARP_LS_REAL" ]]; then
    ok "csharp-ls already installed; updating"
    "$DOTNET_NEW" tool update --global csharp-ls >/dev/null 2>&1 || true
  elif "$DOTNET_NEW" tool install --global csharp-ls; then
    ok "installed csharp-ls"
  else
    err "failed to install csharp-ls"; FAILED+=("csharp-ls")
  fi

  if [[ -x "$CSHARP_LS_REAL" ]]; then
    cat > "$BREW_BIN/csharp-ls" << EOF
#!/bin/sh
# Wrapper created by install-lsp-binaries.sh: run csharp-ls on the .NET 10 runtime
# regardless of any DOTNET_ROOT set for older .NET versions.
export DOTNET_ROOT=$DOTNET_NEW_ROOT
exec "\$HOME/.dotnet/tools/csharp-ls" "\$@"
EOF
    chmod +x "$BREW_BIN/csharp-ls"
    ok "wrapper written to $BREW_BIN/csharp-ls"
  fi
fi

# ---------- Go: gopls --------------------------------------------------------
log "Go → gopls"
brew_install go
brew_install gopls

# ---------- Java: jdtls ------------------------------------------------------
log "Java → jdtls"
brew_install jdtls          # pulls in OpenJDK as a dependency

# ---------- Kotlin: kotlin-language-server -----------------------------------
log "Kotlin → kotlin-language-server"
brew_install kotlin-language-server

# ---------- Python: pyright-langserver ---------------------------------------
log "Python → pyright-langserver"
brew_install pyright        # provides both pyright and pyright-langserver

# ---------- Rust: rust-analyzer ----------------------------------------------
log "Rust → rust-analyzer"
if have rustup; then
  rustup component add rust-analyzer && ok "rust-analyzer added via rustup" \
    || { err "rustup component add failed"; FAILED+=("rust-analyzer"); }
else
  brew_install rust-analyzer
  warn "No rustup found. rust-analyzer needs a Rust toolchain for real projects;"
  warn "install one with: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
fi

# ---------- Swift: sourcekit-lsp ---------------------------------------------
log "Swift → sourcekit-lsp"
if have sourcekit-lsp; then
  ok "sourcekit-lsp already on PATH ($(command -v sourcekit-lsp))"
elif p="$(xcrun --find sourcekit-lsp 2>/dev/null)" && [[ -n "$p" ]]; then
  link_into_path sourcekit-lsp "$p"
else
  err "sourcekit-lsp not found. Install Xcode from the App Store (or a Swift toolchain from swift.org) and re-run."
  FAILED+=("sourcekit-lsp")
fi

# ---------- TypeScript: typescript-language-server ---------------------------
# Installed via Homebrew (not npm) so it doesn't depend on whichever Node
# version nvm/fnm/asdf happens to have active.
log "TypeScript → typescript-language-server"
brew_install typescript-language-server
brew_install typescript

# ---------- verification -----------------------------------------------------
hash -r
log "Verifying binaries"
MISSING=0
PATH_WARNINGS=0
for bin in clangd csharp-ls gopls jdtls kotlin-language-server pyright-langserver \
           rust-analyzer sourcekit-lsp typescript-language-server; do
  if ! have "$bin"; then
    err "$(printf '%-28s' "$bin") NOT FOUND"; MISSING=$((MISSING + 1))
  elif [[ "$bin" == typescript-language-server ]] \
       && ts_shadowed "$(command -v "$bin")" "$BREW_BIN/$bin"; then
    warn "$(printf '%-28s' "$bin") $(command -v "$bin") (found, with PATH warning)"
    warn "  Homebrew's copy at $BREW_BIN/$bin is shadowed; it breaks when you switch Node versions."
    warn "  See docs/lsp-setup.md: \"TypeScript plugin stops working after switching Node versions\"."
    PATH_WARNINGS=$((PATH_WARNINGS + 1))
  else
    ok "$(printf '%-28s' "$bin") $(command -v "$bin")"
  fi
done

# csharp-ls can be on PATH but still fail to launch (wrong .NET runtime), so run it
if have csharp-ls; then
  if v="$(csharp-ls --version 2>&1)"; then
    ok "csharp-ls launches: ${v%%+*}"
  else
    err "csharp-ls is installed but won't start — see 'csharp-ls won't start' in docs/lsp-setup.md"
    MISSING=$((MISSING + 1))
  fi
fi

echo
if (( MISSING == 0 && ${#FAILED[@]} == 0 && PATH_WARNINGS == 0 )); then
  printf "\033[32mAll language servers installed.\033[0m\n"
elif (( MISSING == 0 && ${#FAILED[@]} == 0 )); then
  printf "\033[32mAll language servers installed\033[0m, with %d PATH warning(s) above.\n" "$PATH_WARNINGS"
else
  printf "\033[33mFinished with issues.\033[0m Missing/broken: %d  Failed steps: %s\n" \
    "$MISSING" "${FAILED[*]:-none}"
  echo "See the Troubleshooting section of docs/lsp-setup.md."
fi
echo
echo "Next: open a new terminal (or run: source ~/.zprofile), then run lsp/install-claude-lsp-plugins.sh"
