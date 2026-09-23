# LSP setup kit + global code-intelligence policy — design

Ideation: gpt-6-astra via codex MCP · Facilitation: Claude

Provenance: Codex thread `01a0cfad-9b77-7e80-88df-fa81d1099a38`, dispatch
model `gpt-6-astra` (CLAUDE.md default; no alias), tuned ideation overlay
present. Source material: the user's `claude-code-lsp-setup.zip`
(`README.md`, `install-lsp-binaries.sh`, `install-claude-lsp-plugins.sh`).
Design text is GPT's approved wording; facilitator notes are marked
`[Claude, codebase check]`.

## Decision ledger

| # | Step | Decision |
|---|---|---|
| 1 | Tool policy | **Built-in `LSP` only**; Serena stays out of the global policy (user overrode GPT's task-split recommendation) |
| 2 | Install flow | **Separate scripts**; `install.sh`, preflight, `uninstall.sh` unchanged (GPT's recommendation) |
| 3 | LSP failure | **Fall back transparently** with a one-line explanation (GPT's recommendation) |
| 4 | Approach | **1) Standalone setup bundle with inline global policy** (GPT's recommendation) |
| 5 | Architecture | approved as drafted |
| 6 | `settings.json` | repo `settings.json` does **not** list the nine `*-lsp` plugins; the binary-gated plugin installer is the only path (Claude-raised) |
| 7 | Components | approved with two Claude-raised policy lines: reference-first renames (no multi-file regex/sed), and explicit built-in-LSP-over-Serena precedence |
| 8 | Data flow, Error handling | approved as drafted |
| 9 | Testing | approved with Claude correction: shim-only PATH (host has real `/usr/bin/clangd`, `/usr/bin/sourcekit-lsp`) |

## Purpose, constraints, criteria, assumptions (GPT)

**Purpose:** Make the nine-language LSP setup reproducible from this repo and
give every Claude session an explicit, built-in-LSP-first policy for suitable
code-understanding tasks.

**Constraints**
- Leave `install.sh`, its preflight, the managed symlink inventory, and
  `uninstall.sh` unchanged.
- LSP provisioning runs only through explicitly invoked standalone scripts;
  its machine-level changes are not reversed by repo uninstall.
- Serena is excluded from use by the global policy (see ledger #7 for the one
  precedence line that names it).
- Preserve the cross-model pipeline, routing strings, and
  stop-on-Codex-MCP-failure rule.
- Preserve manual settings merging; do not link `settings.json`.
- Native LSP is for semantic queries, not editing. Text tools remain allowed
  for discovery, literal searches, edits, non-code, and unsupported
  operations.
- On LSP failure or unavailability, explain the limitation briefly and use
  targeted alternatives.

**Measurable success criteria**
- Both installers retain all nine language targets and the plugin
  installer's `user|project|local` scopes.
- Setup instructions cover installation order, PATH verification, plugin
  verification, and the nvm-shadowing pitfall.
- The global policy covers navigation, references, symbols, hover,
  implementations, call hierarchy, 1-based positions, reference-first
  refactoring, and post-edit diagnostics.
- Existing tests pass; added checks protect the new policy and installer
  behavior without changing the real machine.
- Documentation distinguishes installed/enabled components from a
  successfully exercised LSP operation.

**Risky assumptions**
- The supplied scripts' idempotence, wrapper ownership, and shell-profile
  changes needed inspection before incorporation (done: see Error handling).
- Binary availability and enabled plugins do not alone establish working
  language-server sessions.
- The nvm-resolved TypeScript binary is diagnosed, not automatically removed
  or replaced.
- Plugin diagnostics supplement — not replace — project tests and build
  checks.

**Approaches considered:** (1) standalone bundle with inline policy —
selected; (2) manifest-driven subsystem with a shared nine-language inventory
and a new verify command — rejected as disproportionate for a fixed-inventory
personal repo.

## Architecture

Three responsibilities, kept separate:

- **Machine provisioning:** a new, non-managed `lsp/` directory contains the
  two standalone installers. They run only when explicitly invoked, retain
  the supplied nine-language coverage and plugin scope options, and remain
  compatible with macOS Bash 3.2. They are not added to `managed-files.sh`
  or invoked by `install.sh`.
- **Session behavior:** the existing managed `CLAUDE.md` contains the
  complete tool-selection policy — not a pointer to optional documentation.
  Native `LSP` handles suitable semantic queries; ordinary editing tools
  remain responsible for changes. Claude's plugins own language-server
  integration; the repo adds no background service or runtime bootstrap.
- **Operator documentation:** `docs/lsp-setup.md` holds installation,
  verification, and troubleshooting, with discovery links from README and
  ONBOARDING. Operational detail stays out of the globally loaded prompt.

**Compatibility boundaries**
- `install.sh`, its preflight, `uninstall.sh`, and the managed-path inventory
  are unchanged. LSP availability is not a prerequisite for installing the
  repo's configuration.
- `settings.json` stays unlinked and manually merged, and does not gain the
  nine `*-lsp` entries. Explicitly running the plugin installer changes
  plugin configuration at the selected scope.
- Repo uninstall does not remove provisioned binaries, plugins, wrappers, or
  shell-profile changes.
- The new policy supplements — not replaces or reorders — the existing
  cross-model pipeline and model routing.
- No shared manifest, new managed skill, or orchestration layer.

Existing installations inherit the policy through the current `CLAUDE.md`
symlink without reprovisioning; provisioning remains a separate operator
action. `[Claude, codebase check]` the contract test imposes no byte cap on
`CLAUDE.md` (caps apply to GPT prompt role files); concision is required
because it loads every session.

## Components

- **`lsp/install-lsp-binaries.sh`** — the supplied nine-server installer,
  including the .NET 10 C# wrapper and the `~/.zprofile` PATH entry.
  Idempotent, Bash 3.2 compatible. Only change: the TypeScript shadowing
  warning (see Error handling).
- **`lsp/install-claude-lsp-plugins.sh`** — retains `[user|project|local]`,
  adds the official marketplace when needed, and gates each plugin on its
  binary being on PATH. The sole plugin-installation path the repo
  documents.
- **`docs/lsp-setup.md`** — the supplied README adapted into the canonical
  runbook: prerequisites, provisioning side effects, commands, scope
  selection, verification, troubleshooting (including nvm PATH shadowing and
  desktop-app PATH, uninstalling). README and ONBOARDING link here rather
  than duplicate it; README's "What's here" table lists `lsp/` and the new
  doc, and its "What's deliberately not here" note on `plugins/` is qualified
  so it no longer implies `settings.json` declares every plugin.
- **`CLAUDE.md`** — gains this section, appended after the existing GPT model
  routing section; existing pipeline and routing text is untouched:

```markdown
## Code intelligence
- Prefer built-in `LSP` for supported semantic code queries over text-search approximations.
- Prefer built-in LSP over Serena's symbol tools; do not invoke Serena, including `initial_instructions`, unless the user explicitly asks.
- Use `documentSymbol` for file structure and `workspaceSymbol` to discover project symbols.
- Use `goToDefinition` and `goToImplementation` to locate declarations and implementations; use `hover` for types and documentation.
- Use `findReferences` to investigate usages and assess change impact.
- Before renames or signature changes, use `findReferences` to enumerate every usage site, then edit the declaration and each usage with ordinary editing tools—no multi-file regex/sed rewrites.
- Use `prepareCallHierarchy`, then `incomingCalls` or `outgoingCalls`, to investigate call relationships.
- Use file discovery or scoped text search to locate a starting file or symbol when needed; then use LSP for semantic queries.
- LSP line and character positions are 1-based; derive them from current file content.
- Use ordinary editing tools for changes; built-in LSP does not edit or rename code.
- Use text tools directly for literal searches, documentation/configuration, and unsupported languages or operations.
- After edits, inspect available plugin diagnostics and address issues introduced by your changes; diagnostics do not replace project checks.
- If LSP is unavailable, fails, or is inconclusive, briefly explain the limitation and use targeted text alternatives; empty results alone do not prove absence.
- These preferences and fallbacks do not change the cross-model pipeline or its mandatory stop-on-Codex-MCP-failure rule.
```

## Data flow

**Provisioning**
1. The operator runs `lsp/install-lsp-binaries.sh`; it provisions the
   servers, dependencies, C# wrapper, and shell-profile entry.
2. The operator refreshes the shell and checks binary resolution, including
   TypeScript's possible nvm shadowing.
3. The operator runs `lsp/install-claude-lsp-plugins.sh [scope]` (`user` for
   global setup). It ensures the marketplace exists, checks each binary on
   the current PATH, and installs only the corresponding plugins.
4. Plugin configuration is written through the `claude` CLI at the selected
   scope; `project`/`local` target the directory it is run from. Repo
   `settings.json` is neither source nor destination.

**Session use**
1. A new session loads the policy through `~/.claude/CLAUDE.md`.
2. Enabled plugins connect supported source files to their language servers.
3. Claude selects a native LSP operation; file discovery or scoped text
   search supplies the starting location when needed, and current file
   content supplies 1-based coordinates.
4. LSP results guide understanding and subsequent edits. Serena receives no
   calls unless explicitly requested.

**Change cycle**
- Renames/signature changes: `findReferences` → usage-site inventory →
  ordinary edits to the declaration and each usage.
- Edits → plugin diagnostics → correction of introduced issues.

## Error handling

- **TypeScript PATH shadowing:** the binaries script's final verification
  warns when the resolved `typescript-language-server` is not the Homebrew
  copy, showing both paths and pointing to the runbook. Reported as "found,
  with PATH warning", not an unqualified ✓. The warning fires only when the
  Homebrew copy exists and the resolved path differs from it. It removes nothing, does not
  reorder PATH, and does not by itself fail provisioning.
  `[Claude, codebase check]` implement as a comparison of
  `command -v typescript-language-server` against
  `$BREW_BIN/typescript-language-server`; on this machine the resolved path
  is `~/.nvm/versions/node/v22.23.1/bin/…`, which the kit's check reports as
  success today.
- **Discovery vs runtime health:** `command -v` proves only that the invoking
  shell finds a binary. Binary-gated plugin installation and explicit
  missing-binary skips are preserved. `claude plugin list` shows scope and
  enabled status; it does not prove the server works.
- **Desktop-session PATH:** for "Executable not found in $PATH", the runbook
  directs the operator to `/plugin` → Errors in the affected session, and
  explains that re-sourcing `~/.zprofile` in a terminal may not fix a
  desktop-launched session: correct that launcher's PATH, restart, verify
  there. Reinstalling an already-installed plugin is not the default remedy.
- **Provisioning behavior preserved:** the kit's Homebrew bootstrap stays,
  and the runbook states prominently that it may download and run Homebrew's
  installer. No retry, rollback, or dependency framework. Partial
  provisioning may remain after failure and is not covered by repo
  uninstall.
- **Session fallback:** unavailable, failed, or inconclusive LSP queries get
  a brief explanation, then targeted text alternatives. Empty results do not
  establish absence. Refactor fallback still accounts for usage sites
  without multi-file regex/sed rewrites. Codex MCP failures keep their
  mandatory stop.

Spec review (Claude, cross-model): three clarifications made inline —
policy placement in `CLAUDE.md`, README table/"not here" updates, and the
TypeScript warning's firing condition. No substantive changes.

`[Claude, codebase check]` both scripts pass `/bin/bash -n` under 3.2, and
their empty-array uses (`${A[*]:-none}`, `${#A[@]}`) are safe under `set -u`;
no speculative compatibility edits.

## Testing

**Automated (lightweight)**
- `/bin/bash -n` on both installers and any new shell test.
- All three existing suites pass unchanged in behavior.
- `tests/prompt-contract-test.sh` gains `contains` checks on `CLAUDE.md` for:
  native-LSP preference, the operation names, 1-based coordinates,
  reference-first refactoring, the multi-file regex/sed prohibition,
  Serena's explicit opt-in, and transparent fallback — without weakening the
  Codex stop rule assertion.
- `tests/prompt-contract-mutation-test.sh` gains three cases: remove the
  native-LSP preference, corrupt Serena's opt-in restriction, remove the
  multi-file rewrite prohibition. These check wording, not model obedience.
- New `tests/lsp-plugins-test.sh` (implemented as `tests/lsp-installers-test.sh`,
  since it also covers the binaries script; see the plan): temp fixtures, fake `claude`, fake server
  binaries, temp HOME/project dirs; never touches live plugin config. Covers
  all nine binary→plugin mappings, partial and zero binary availability,
  marketplace present/absent, and scope forwarding (plus invalid scope).
  `[Claude, codebase check]` runs with a **shim-only PATH** (symlinking just
  the utilities the script needs into the shim dir), not
  `"$SHIMBIN:/usr/bin:/bin"`, because this host has real `/usr/bin/clangd`
  and `/usr/bin/sourcekit-lsp` that would leak into missing-binary cases.
- The diff leaves `install.sh`, `uninstall.sh`, `managed-files.sh`, and repo
  `settings.json` unchanged.

**Targeted manual verification**
- Check the TypeScript warning condition against this machine's nvm-resolved
  and Homebrew paths by read-only inspection, without rerunning provisioning.
- In a real Claude session: plugin scope/enabled status, `/plugin` Errors,
  one definition/reference query on a disposable TypeScript fixture, and one
  edit that exercises diagnostics. Terminal PATH checks alone do not satisfy
  this.

**Explicitly deferred**
- A full binary-installer harness (shimming Homebrew, Apple tooling, dotnet,
  rustup, `uname`, HOME) — disproportionate to this import.
- Fresh-machine provisioning and a nine-language runtime matrix.

**Acceptance:** lightweight checks pass; the manual smoke check is recorded
as passed or explicitly not performed. Deferred coverage is disclosed, not
implied.
