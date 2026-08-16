# Install Prerequisite Preflight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved spec at `docs/superpowers/specs/2026-08-16-install-prereq-preflight-design.md` — an aggregated dependency preflight in install.sh and a prominent README Prerequisites section with layered verification.

**Architecture:** install.sh gains a preflight phase (flag validation → probe `claude`, `codex`, `claude mcp get codex` → aggregated report → mode gate) before any filesystem mutation; the test harness gains PATH-shim helpers and runs existing fixtures with `SKIP_CHECKS=1` so the 53 current checks stay machine-independent; README gets Prerequisites before Install and a consolidated Requirements section.

**Tech Stack:** Plain bash (bash 3.2 compatible), `command -v`, PATH shims in the existing dependency-free test harness.

## Global Constraints

- Hard blockers (normal mode): missing `claude`, missing `codex`, failed `claude mcp get codex`. Codex version/provider suitability and superpowers are warnings/notes only — never gates.
- `SKIP_CHECKS=1` bypasses the probes entirely (with an explicit notice); `DRY_RUN=1` runs the probes, labels failures advisory, still shows the preview, and exits 0. `DRY_RUN` and `SKIP_CHECKS` accept only `0` or `1`; anything else exits 1 before probes or filesystem changes.
- If `claude` is missing, the MCP check is reported as skipped — never as a second failure.
- Exact wording rules: aggregated failures open with `Nothing changed — required dependencies are unavailable:` (the repo's established voice); MCP nonzero is phrased as `could not be verified` (it may be missing registration or another CLI error); MCP success must state that live credentials were **not** tested; remediation mentions the README and `SKIP_CHECKS=1`.
- The preflight must not install anything, modify MCP registration, or probe credentials.
- All probes run inside guarded conditionals — `set -euo pipefail` stays, and a failing probe must not kill collection.
- Bash 3.2 compatible; no new dependencies (bash + coreutils only). Possibly-empty arrays expand only inside length-check guards.
- Tests: sanitized `PATH="$SHIMBIN:/usr/bin:/bin"` for preflight cases so real `claude`/`codex` are never consulted; existing fixtures switch to `SKIP_CHECKS=1`; all 93 existing checks (53 install/uninstall + 40 contract) must keep passing; no fixture touches the real `~/.claude`.
- `uninstall.sh` and `managed-files.sh` are untouched.
- Run suites as: `bash tests/uninstall-test.sh </dev/null` (redirect matters) and `bash tests/prompt-contract-test.sh`.
- Read each target file before editing; Edit anchors below must match actual wrapping.

---

### Task 1: Harness prep — SKIP_CHECKS in fixtures + shim seam

**Files:**
- Modify: `tests/uninstall-test.sh` (the `install_f` helper; new shim helpers after `snapshot`)
- Test: the suite itself — all 53 existing checks must pass unchanged

**Interfaces:**
- Consumes: existing helpers `fixture`, `check`, `test_fails`, `snapshot`, `$TMP`, `$FREPO`, `$FHOME`.
- Produces (Task 2 relies on these exact names): `SHIMBIN` (per-fixture shim dir), `shim_dir <name>`, `shim_claude <mcp-exit>`, `shim_codex [version]` (each shim also drops a `<name>.called` marker beside itself when invoked), and `preflight_install [VAR=val ...]` which runs install.sh under `PATH="$SHIMBIN:/usr/bin:/bin"` with `CLAUDE_HOME="$FHOME"` and any extra env pairs.

- [ ] **Step 1: Switch existing fixtures to SKIP_CHECKS=1**

In `tests/uninstall-test.sh`, change:

```bash
install_f()   { CLAUDE_HOME="$FHOME" bash "$FREPO/install.sh" "$@"; }
```

to:

```bash
# SKIP_CHECKS: these fixtures test linking/backup mechanics, not the
# dependency preflight (which has its own shim-based cases below), and must
# not depend on what's installed on the developer machine.
install_f()   { CLAUDE_HOME="$FHOME" SKIP_CHECKS=1 bash "$FREPO/install.sh" "$@"; }
```

(Today's install.sh ignores `SKIP_CHECKS` — this is forward-compatible prep, harmless now, load-bearing after Task 2.)

- [ ] **Step 2: Add the shim helpers**

Insert after the `snapshot()` function:

```bash
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
```

- [ ] **Step 3: Run the suite to prove nothing regressed**

Run: `bash tests/uninstall-test.sh </dev/null`
Expected: `53 passed, 0 failed` — identical to before. Also `bash -n tests/uninstall-test.sh` silent.

- [ ] **Step 4: Commit**

```bash
git add tests/uninstall-test.sh
git commit -m "Test harness: shim seam and SKIP_CHECKS for machine-independent installs

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: install.sh — flag validation + aggregated preflight

**Files:**
- Modify: `install.sh` (insert between `source "$REPO/managed-files.sh"` and the `link()` function)
- Test: `tests/uninstall-test.sh` (new preflight block above `# ---- summary`)

**Interfaces:**
- Consumes: Task 1's `shim_dir`/`shim_claude`/`shim_codex`/`preflight_install`/`SHIMBIN`; existing `fixture`/`check`/`test_fails`/`snapshot`/`present`.
- Produces: install.sh env contract — `SKIP_CHECKS` (0/1, default 0) alongside the existing `DRY_RUN`; preflight output lines prefixed `  found` / `  skip` / `  note`; failure report in the `Nothing changed —` voice. Task 3's README references `SKIP_CHECKS=1` and this behavior.

- [ ] **Step 1: Write the failing tests**

Insert above `# ---- summary` in `tests/uninstall-test.sh`:

```bash
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
```


- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/uninstall-test.sh </dev/null`
Expected: FAIL — current install.sh has no preflight, so `pf-none`/`pf-noclaude`/`pf-nocodex`/`pf-nomcp` install successfully where the tests demand exit 1, and the wording greps find nothing. Existing 53 checks still pass.

- [ ] **Step 3: Implement the preflight in install.sh**

In `install.sh`, add `SKIP_CHECKS="${SKIP_CHECKS:-0}"` directly under the `DRY_RUN="${DRY_RUN:-0}"` line. Then insert between `source "$REPO/managed-files.sh"` and the `link()` function:

```bash
for flag in DRY_RUN SKIP_CHECKS; do
  val="$(eval echo "\$$flag")"
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
    echo "  note     Azure providers require the 0.146.1 pin — see docs/azure-openai-codex.md"
  else
    missing+=("codex CLI not found in PATH — npm install -g @openai/codex@0.146.1")
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
```

(`eval echo "\$$flag"` instead of `${!flag}` keeps maximum bash 3.2 safety in the flag loop; both work on 3.2 — use the eval form as written. All probes sit in `if` conditions, so `set -e` cannot end collection early.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/uninstall-test.sh </dev/null && bash -n install.sh`
Expected: all checks pass — the 53 existing plus the new preflight block (existing fixtures are immune via Task 1's `SKIP_CHECKS=1`).

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/uninstall-test.sh
git commit -m "install.sh: aggregated dependency preflight before any mutation

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: README — Prerequisites up front, Requirements consolidated

**Files:**
- Modify: `README.md` (new section after the intro paragraph, one sentence in Install, rewritten Requirements)
- Test: `tests/prompt-contract-test.sh` + fence balance

**Interfaces:**
- Consumes: install.sh's `SKIP_CHECKS=1` behavior and preflight from Task 2; the MCP setup commands already in `docs/azure-openai-codex.md`.
- Produces: user-facing docs only.

- [ ] **Step 1: Insert the Prerequisites section**

The content below contains nested code fences, which break rendered views
of THIS plan — read the raw plan file. The section's content runs from
`## Prerequisites` through the line ending `troubleshooting: [docs/azure-openai-codex.md](docs/azure-openai-codex.md).`

Read `README.md`. Immediately after the intro paragraph (ending "...model boundaries, not just phase boundaries.") and before `## Install`, insert:

```markdown
## Prerequisites — install these BEFORE running install.sh

The pipeline drives GPT through the **Codex CLI** and its **MCP server**
registered in Claude Code. Without them, stage 1 and stage 3 cannot run —
so `install.sh` checks and refuses to link an unusable setup (bypass with
`SKIP_CHECKS=1` if you deliberately want the config files first).

1. **Claude Code** (`claude`) — verify: `claude --version`.
2. **Codex CLI** — Azure users MUST pin the version (0.147.0 fails every
   Azure request before inference):

   ```bash
   npm install -g @openai/codex@0.146.1
   ```

   Then point `~/.codex/config.toml` at exactly one provider —
   OpenAI-hosted (sign-in or API key) or Azure-hosted (the TOML block in
   [docs/azure-openai-codex.md](docs/azure-openai-codex.md)).
3. **Codex MCP server** registered in Claude Code — pick one shape (both
   detailed in the runbook):

   ```bash
   claude mcp add codex -s user -- zsh -c 'source ~/.zshrc >/dev/null 2>&1; exec codex mcp-server'
   ```

### Verify the chain

| Level | Command | Proves |
|---|---|---|
| Binaries | `claude --version && codex --version` | Both CLIs present (Azure: 0.146.1) |
| Registration | `claude mcp get codex` | MCP server registered — handshake only |
| Credentials | one trivial codex call from a Claude Code session (fully restart it first) | The whole chain, end to end |

`claude mcp get codex` saying "Connected" does **not** prove credentials —
the key is only checked at request time. Environment delivery, restart
gotchas, and troubleshooting: [docs/azure-openai-codex.md](docs/azure-openai-codex.md).
```

- [ ] **Step 2: Point the Install section at the preflight**

In the `## Install` section, after the sentence ending "Nothing is overwritten or deleted. Symlinks rather than copies, so editing either path edits the same file.", add:

```markdown
install.sh first checks the prerequisites above and stops — before touching
anything — if one is missing (`SKIP_CHECKS=1` bypasses; `DRY_RUN=1` reports
the same checks advisorily).
```

- [ ] **Step 3: Consolidate Requirements**

Replace the Requirements section's first paragraph block (from `The **codex MCP server** must be configured against exactly one provider` through the end of the Azure bullet, keeping the sentence that begins `The policy deliberately says`) with:

```markdown
Everything in [Prerequisites](#prerequisites--install-these-before-running-installsh)
above, working — that section is the single source for install commands and
verification. Azure specifics (the 0.146.1 pin, deployment-name model
values, the `gpt_model_alias:` registry) live in
[docs/azure-openai-codex.md](docs/azure-openai-codex.md).
```

Keep the "policy deliberately says to *stop and tell the user*" sentence and the superpowers paragraph; append to the superpowers paragraph: `The installer's preflight does not check plugins — verify superpowers appears after merging settings.json and restarting.`

- [ ] **Step 4: Verify**

Run:

```bash
bash tests/prompt-contract-test.sh
n=$(grep -c '```' README.md); echo "fences: $n"; test $((n % 2)) -eq 0
grep -c '0.146.1' README.md
```

Expected: contract suite all-pass; even fence count; `0.146.1` appears (at least twice: Prerequisites and the old pin warning now consolidated — final count depends on Step 3, must be ≥1).

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "README: prerequisites and layered verification up front

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Spec coverage map

| Spec requirement | Task |
|---|---|
| Existing fixtures run with SKIP_CHECKS=1; 53 checks preserved | 1 |
| PATH shims (claude with configurable mcp exit, codex with --version), sanitized PATH, no real binaries | 1 |
| Flag validation (DRY_RUN/SKIP_CHECKS 0/1 only, exit before probes) | 2 |
| Aggregated preflight, all failures at once, established voice, before any mutation | 2 |
| claude-missing ⇒ MCP "skip", not second failure; MCP nonzero ⇒ "could not be verified" | 2 |
| MCP success states credentials untested; version/superpowers as notes/warnings | 2 |
| SKIP_CHECKS bypass notice; DRY_RUN advisory + preview + exit 0 | 2 |
| Nine required test cases (pass/both/each/MCP-fail/dry/skip-with-probe-markers/invalid-flags/warning-not-gate/wording) | 2 |
| README Prerequisites before Install, compact commands, pin, superpowers guidance | 3 |
| Three-level verification table; handshake-vs-credentials honesty | 3 |
| Requirements consolidated, no duplicate/contradictory instructions | 3 |
| uninstall.sh / managed-files.sh untouched | Global Constraints |
| bash -n + both suites green | Tasks 2-3 verify steps |
