#!/usr/bin/env bash
#
# Self-contained tests for the LSP kit in lsp/. The plugins installer runs
# against a fake `claude` on a shim-only PATH; the binaries installer is only
# sourced (via its test seam) to exercise the TypeScript shadowing predicate.
# Real plugin configuration and real language servers are never touched.

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PLUGINS_SH="$SRC/lsp/install-claude-lsp-plugins.sh"
BINARIES_SH="$SRC/lsp/install-lsp-binaries.sh"

ALL_BINS="clangd csharp-ls gopls jdtls kotlin-language-server pyright-langserver rust-analyzer sourcekit-lsp typescript-language-server"
ALL_PLUGINS="clangd-lsp csharp-lsp gopls-lsp jdtls-lsp kotlin-lsp pyright-lsp rust-analyzer-lsp swift-lsp typescript-lsp"

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

# ---- fixtures ------------------------------------------------------------------
# Each case gets its own shim-only PATH: the fake claude, the fake servers the
# case asks for, and symlinks to the two host utilities the script needs. Not
# /usr/bin — this Mac ships real /usr/bin/clangd and /usr/bin/sourcekit-lsp,
# which would leak into every "binary missing" case.

OFFICIAL_LISTING='Configured marketplaces:

  ❯ claude-plugins-official
    Source: GitHub (anthropics/claude-plugins-official)
'

# fixture <name> — fresh $FDIR with bin/ (on PATH), home/, and the fake
# claude's knobs: marketplaces.txt (what `marketplace list` prints), add_exit
# (status of `marketplace add`), fail_plugin (an id whose install exits 1).
fixture() {
  FDIR="$TMP/$1"; SHIMBIN="$FDIR/bin"; FHOME="$FDIR/home"; OUT="$FDIR/out.txt"
  mkdir -p "$SHIMBIN" "$FHOME"
  : > "$FDIR/claude.log"
  printf '%s' "$OFFICIAL_LISTING" > "$FDIR/marketplaces.txt"
  echo 0 > "$FDIR/add_exit"
  : > "$FDIR/fail_plugin"
  local u
  for u in grep head; do ln -s "$(command -v "$u")" "$SHIMBIN/$u"; done
}

# shim_claude — fake CLI in $SHIMBIN. Logs each call's argv to claude.log (one
# line per call) and answers from the fixture's knob files. Uses absolute
# paths only: its PATH is the shim-only one.
shim_claude() {
  cat > "$SHIMBIN/claude" <<'EOF'
#!/bin/sh
D="${0%/bin/claude}"
echo "$*" >> "$D/claude.log"
case "$1" in
  --version) echo "9.9.9 (Claude Code)"; exit 0 ;;
  plugin)
    case "$2" in
      marketplace)
        case "$3" in
          list) /bin/cat "$D/marketplaces.txt"; exit 0 ;;
          add)  exit "$(/bin/cat "$D/add_exit")" ;;
        esac ;;
      install)
        [ "$3" = "$(/bin/cat "$D/fail_plugin")" ] && exit 1
        exit 0 ;;
    esac ;;
esac
exit 0
EOF
  chmod +x "$SHIMBIN/claude"
}

# fake_bins <name...> — executable stubs standing in for language servers
fake_bins() {
  local b
  for b in "$@"; do printf '#!/bin/sh\nexit 0\n' > "$SHIMBIN/$b"; chmod +x "$SHIMBIN/$b"; done
}

# run_plugins [scope] — the plugins installer on the fixture's PATH and HOME;
# output in $OUT; returns the script's exit status
run_plugins() {
  env -i PATH="$SHIMBIN" HOME="$FHOME" /bin/bash "$PLUGINS_SH" "$@" > "$OUT" 2>&1
}

# installed — plugin names the script asked to install, sorted, space-joined
installed() {
  grep '^plugin install ' "$FDIR/claude.log" | awk '{print $3}' | sed 's/@.*//' \
    | sort | tr '\n' ' ' | sed 's/ $//'
}

echo "lsp-installers-test: $SRC"

# Sourcing through the seam stops before most of the binaries script, so a
# syntax error further down would go unnoticed without a full parse.
echo "syntax: both installers parse under /bin/bash 3.2"
check "install-claude-lsp-plugins.sh parses" /bin/bash -n "$PLUGINS_SH"
check "install-lsp-binaries.sh parses" /bin/bash -n "$BINARIES_SH"

# ---- plugins installer ---------------------------------------------------------

echo "plugins: all nine binaries, marketplace present"
fixture all; shim_claude; fake_bins $ALL_BINS
check "exits 0" run_plugins
check "installs all nine" test "$(installed)" = "$ALL_PLUGINS"
check "every install is @claude-plugins-official --scope user" \
  test "$(grep -c '^plugin install [a-z-]*@claude-plugins-official --scope user$' "$FDIR/claude.log")" = 9
check "does not re-add the marketplace" test_fails grep -q '^plugin marketplace add' "$FDIR/claude.log"

echo "plugins: no binaries at all"
fixture none; shim_claude
check "host servers do not leak into the shim PATH" \
  test_fails env -i PATH="$SHIMBIN" /bin/bash -c 'command -v clangd || command -v sourcekit-lsp'
check "exits 0" run_plugins
check "installs nothing" test -z "$(installed)"
check "reports all nine skipped" grep -qF "Skipped:   $ALL_PLUGINS" "$OUT"

echo "plugins: some binaries"
fixture some; shim_claude; fake_bins gopls pyright-langserver
check "exits 0" run_plugins
check "installs exactly the matching two" test "$(installed)" = "gopls-lsp pyright-lsp"

echo "plugins: dotnet tools dir (fresh terminal, ~/.zprofile not re-sourced)"
fixture dotnet; shim_claude
mkdir -p "$FHOME/.dotnet/tools"
printf '#!/bin/sh\nexit 0\n' > "$FHOME/.dotnet/tools/csharp-ls"; chmod +x "$FHOME/.dotnet/tools/csharp-ls"
check "exits 0" run_plugins
check "finds csharp-ls in ~/.dotnet/tools and installs csharp-lsp" test "$(installed)" = "csharp-lsp"

echo "plugins: marketplace absent"
fixture nomkt; shim_claude; fake_bins gopls
printf 'Configured marketplaces:\n' > "$FDIR/marketplaces.txt"
check "exits 0" run_plugins
check "adds anthropics/claude-plugins-official" \
  grep -qx 'plugin marketplace add anthropics/claude-plugins-official' "$FDIR/claude.log"
check "then installs" test "$(installed)" = "gopls-lsp"

echo "plugins: marketplace absent and cannot be added"
fixture addfail; shim_claude; fake_bins gopls
printf 'Configured marketplaces:\n' > "$FDIR/marketplaces.txt"
echo 1 > "$FDIR/add_exit"
check "exits nonzero" test_fails run_plugins
check "installs nothing" test -z "$(installed)"

echo "plugins: look-alike marketplace (mirror of the official repo, or a longer name)"
fixture lookalike; shim_claude; fake_bins gopls
cat > "$FDIR/marketplaces.txt" <<'EOF'
Configured marketplaces:

  ❯ my-mirror
    Source: GitHub (anthropics/claude-plugins-official)

  ❯ claude-plugins-official-fork
    Source: GitHub (someone/claude-plugins-official-fork)
EOF
check "exits 0" run_plugins
check "still adds the real official marketplace" \
  grep -qx 'plugin marketplace add anthropics/claude-plugins-official' "$FDIR/claude.log"

for scope in project local; do
  echo "plugins: scope '$scope' is forwarded"
  fixture "scope-$scope"; shim_claude; fake_bins gopls
  check "exits 0" run_plugins "$scope"
  check "installs with --scope $scope" \
    grep -qx "plugin install gopls-lsp@claude-plugins-official --scope $scope" "$FDIR/claude.log"
done

echo "plugins: invalid scope"
fixture badscope; shim_claude; fake_bins gopls
check "exits nonzero" test_fails run_plugins global
check "never calls claude" test ! -s "$FDIR/claude.log"

echo "plugins: one install fails"
fixture onefail; shim_claude; fake_bins gopls jdtls pyright-langserver
echo 'jdtls-lsp@claude-plugins-official' > "$FDIR/fail_plugin"
check "exits nonzero" test_fails run_plugins
check "still attempts every plugin after the failure" test "$(installed)" = "gopls-lsp jdtls-lsp pyright-lsp"
check "names the failure in the summary" grep -qF "Failed:    jdtls-lsp" "$OUT"

echo "plugins: claude CLI missing"
fixture noclaude; fake_bins gopls
check "exits nonzero" test_fails run_plugins
check "says why" grep -qF "not found on PATH" "$OUT"

# ---- binaries installer: TypeScript shadowing predicate -------------------------
# Sourced through its test seam under a shim-only PATH with no `uname`: if the
# seam ever stopped returning early, the script's first real step (the Darwin
# check) exits 1 before provisioning anything, and these cases fail.

# ts_shadowed_in <resolved> <homebrew> — the script's predicate, via the seam
ts_shadowed_in() {
  env -i PATH="$SHIMBIN" LSP_BINARIES_SOURCE_ONLY=1 /bin/bash -c \
    'source "$1" && ts_shadowed "$2" "$3"' _ "$BINARIES_SH" "$1" "$2"
}

echo "binaries: sourcing through the seam provisions nothing"
fixture seam
check "sourcing prints nothing and returns 0" \
  test "$(env -i PATH="$SHIMBIN" LSP_BINARIES_SOURCE_ONLY=1 /bin/bash -c \
           'source "$1" && echo sourced-ok' _ "$BINARIES_SH" 2>&1)" = "sourced-ok"

echo "binaries: TypeScript shadowing"
fixture ts
BREW_TS="$SHIMBIN/typescript-language-server"
NVM_TS="$FHOME/.nvm/versions/node/v22/bin/typescript-language-server"
mkdir -p "$(dirname "$NVM_TS")"
for f in "$BREW_TS" "$NVM_TS"; do printf '#!/bin/sh\nexit 0\n' > "$f"; chmod +x "$f"; done
check "nvm copy resolving ahead of Homebrew's is flagged" ts_shadowed_in "$NVM_TS" "$BREW_TS"
check "Homebrew's copy resolving first is not flagged" test_fails ts_shadowed_in "$BREW_TS" "$BREW_TS"
check "no Homebrew copy to compare against is not flagged" test_fails ts_shadowed_in "$NVM_TS" "$FDIR/absent"
check "not on PATH at all is not flagged" test_fails ts_shadowed_in "" "$BREW_TS"

# ---- summary -------------------------------------------------------------------

echo
echo "$PASS passed, $FAIL failed"
if (( FAIL > 0 )); then exit 1; fi
