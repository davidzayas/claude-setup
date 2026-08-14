# Azure-Hosted GPT Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved spec at `docs/superpowers/specs/2026-08-14-azure-codex-support-design.md` — alias registry routing, failure classification, Azure runbook, and the contract-test guard — so the pipeline works with Azure OpenAI deployments whose names differ from model-family ids.

**Architecture:** Documentation and policy-prose changes only, plus one bash test guard. Two identities are introduced everywhere: the **dispatch model** (resolved by existing precedence, sent to Codex verbatim; under Azure it is the deployment name) and the **overlay model** (derived from `gpt_model_alias:` lines in CLAUDE.md via exact single-hop lookup; used only for overlay selection and TODO identity). No runtime code, no installer changes, no prompt-overlay edits.

**Tech Stack:** Markdown policy files, plain bash (the existing dependency-free `tests/prompt-contract-test.sh` style: bash + grep + awk + wc).

## Global Constraints

- Alias line format, exactly: `gpt_model_alias: <deployment>=<family>` — one space after the colon, no spaces around `=`, both sides non-empty and free of spaces/`=`. Exact, single-hop, non-transitive. Zero alias lines is a valid registry.
- Two conflicting alias lines (same left side) are a configuration error: callers stop the GPT dispatch and report; they never guess.
- The dispatch model is what the codex `model` parameter receives, always; the overlay model never crosses the transport boundary.
- Use the exact terms **"dispatch model"** and **"overlay model"** in all prose so the files stay mutually consistent.
- Missing-variant TODO entries are keyed by the overlay model (alias-resolved), preserving the existing schema `- [ ] prompt-variant: role=<role> model=<exact-model-id>`.
- All existing `gpt-baseline`/`gpt-overlay` marker blocks must remain **byte-for-byte unchanged** (Task 5 verifies mechanically).
- Failure policy wording: missing env var, pre-inference 400/404, and 429 are stop-and-report — never split-and-retry; splitting remains reserved for oversized-payload timeouts; the 20KB working / 30KB hard-boundary text and the "Never retry a timed-out payload unchanged" rule must survive verbatim (the contract test greps them).
- No secrets, keys, or live endpoint URLs in tracked files — the runbook uses `<your-resource>` placeholders only.
- `install.sh`, `uninstall.sh`, `managed-files.sh` are untouched.
- Run the contract suite as `bash tests/prompt-contract-test.sh` and the installer suite as `bash tests/uninstall-test.sh </dev/null` (the redirect matters — one test needs non-tty stdin).
- Read each target file before editing: these are prose files and the Edit anchors below must match the file's actual wrapping.

---

### Task 1: Alias registry in CLAUDE.md + contract-test guard

**Files:**
- Modify: `CLAUDE.md` (the "GPT model routing" section)
- Test: `tests/prompt-contract-test.sh` (new `check_alias_registry` guard)

**Interfaces:**
- Consumes: nothing (first task).
- Produces: the `gpt_model_alias:` line format and the dispatch-model/overlay-model vocabulary that Tasks 2–4 reference; the guard function `check_alias_registry` wired into `main()`.

- [ ] **Step 1: Write the failing guard**

In `tests/prompt-contract-test.sh`, add after the `check_todo()` function:

```bash
check_alias_registry() {
  # Zero alias lines is valid; every present line must match the schema
  # exactly (see CLAUDE.md "GPT model routing"): one deployment, '=', one
  # family, no spaces in either.
  local bad dupes
  bad="$(grep -En '^gpt_model_alias:' "$REPO/CLAUDE.md" \
    | grep -Ev '^[0-9]+:gpt_model_alias: [^ =]+=[^ =]+$' || true)"
  if [[ -z "$bad" ]]; then
    pass "CLAUDE.md: all gpt_model_alias lines match the schema"
  else
    fail "CLAUDE.md: malformed gpt_model_alias lines: $bad"
  fi

  dupes="$(grep -E '^gpt_model_alias:' "$REPO/CLAUDE.md" \
    | awk -F'[ =]' '{print $2}' | sort | uniq -d)"
  if [[ -z "$dupes" ]]; then
    pass "CLAUDE.md: no conflicting alias left sides"
  else
    fail "CLAUDE.md: conflicting aliases for: $dupes"
  fi
}
```

And in `main()`, add `check_alias_registry` on its own line directly after `check_claude_md`.

- [ ] **Step 2: Run to verify the guard passes on the empty registry, then prove it can fail**

Run: `bash tests/prompt-contract-test.sh`
Expected: all checks pass including the two new ones (zero aliases is valid).

Negative proof (the guard must actually reject garbage):

```bash
echo 'gpt_model_alias: bad line=with spaces' >> CLAUDE.md
bash tests/prompt-contract-test.sh; echo "exit: $?"
git checkout -- CLAUDE.md
```

Expected: FAIL on "malformed gpt_model_alias lines", exit 1. After the checkout, rerun and expect all-pass.

- [ ] **Step 3: Add the registry rule to CLAUDE.md**

Read `CLAUDE.md`. In the "GPT model routing" section, insert the following block immediately after the `gpt_review_model: gpt-5.6-sol` line (keeping one blank line on each side):

```markdown
When the Codex provider is Azure OpenAI, every model value above — and any
explicit override — is the Azure DEPLOYMENT NAME, because that is what the
wire call requires. Two identities are in play. The dispatch model is the
resolved value, passed to the codex model parameter verbatim. The overlay
model is used only for overlay selection and missing-variant TODO identity,
and is derived through the alias registry below: zero or more lines, one
per deployment, format exactly

`gpt_model_alias: <deployment>=<family>`

(The backticks on that format line matter: the contract test counts every
line starting with `gpt_model_alias:` as a live entry, same convention as
TODO.md's backticked schema line.)

Lookup is exact and single-hop: if the dispatch model equals a line's left
side, the right side becomes the overlay model; otherwise overlay model =
dispatch model. Never chain aliases, never guess a family for an unlisted
deployment, and never send an alias target to Codex as the model. Two alias
lines with the same left side are a configuration error: stop the GPT
dispatch and report it rather than picking one.
```

Then update the two existing sentences that alias resolution changes:

1. Replace: `Select an overlay by EXACT model-id match only — never guess from a similar name.`
   With: `Select an overlay by EXACT match against the overlay model (alias-resolved as above) — never guess from a similar name.`

2. In the TODO-recording sentence, replace: `record the missing variant in the claude-setup repo's TODO.md as`
   With: `record the missing variant — keyed by the overlay model, so one family maps to one entry regardless of deployment naming — in the claude-setup repo's TODO.md as`

- [ ] **Step 4: Run tests to verify everything passes**

Run: `bash tests/prompt-contract-test.sh`
Expected: all pass — the new prose must not break `exactly_once` checks on the `gpt_*_model:` lines (the alias block adds no line starting with those keys) and the guard passes with zero alias lines present.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md tests/prompt-contract-test.sh
git commit -m "Routing: alias registry separates dispatch model from overlay model

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Alias-aware callers — skill and both commands

**Files:**
- Modify: `skills/gpt-brainstorming/SKILL.md` ("Model Selection and Variant Routing" section + one new failure paragraph)
- Modify: `commands/gpt-brainstorm.md` (the "Model routing:" paragraph)
- Modify: `commands/adversarial-review.md` (instruction 1)
- Test: `tests/prompt-contract-test.sh` (existing suite must stay green)

**Interfaces:**
- Consumes: the `gpt_model_alias:` registry and dispatch/overlay vocabulary from Task 1.
- Produces: caller-side routing prose Task 3's agent prose must not contradict (the agent receives the dispatch model from these callers and does no resolution of its own).

- [ ] **Step 1: Update SKILL.md variant routing**

Read `skills/gpt-brainstorming/SKILL.md`. Replace the paragraph beginning `Then select the prompt variant by EXACT model-id match against the overlay` (through `...CLAUDE.md ("GPT model routing").`) with:

```markdown
Then derive the overlay model: apply the `gpt_model_alias:` registry in
CLAUDE.md ("GPT model routing") to the resolved model — exact, single-hop;
no match means the overlay model is the resolved model itself. Select the
prompt variant by EXACT match of the overlay model against the overlay
blocks in this file. If an overlay exists, compose the briefing as baseline
+ overlay (baseline first). If not: WARN the user before dispatch ("no
tuned variant for <overlay model>; using the generic baseline"), send the
baseline alone, and record the missing variant — keyed by the overlay
model — per the TODO.md rules in CLAUDE.md ("GPT model routing"). The
resolved model is the dispatch model: it goes in the codex model parameter
verbatim (under an Azure provider it is the deployment name), never the
alias target.
```

Replace the sentence `State the resolved model and variant status in your first message so the user can correct it.` with `State the dispatch model, the overlay model when it differs, and the variant status in your first message so the user can correct them.`

- [ ] **Step 2: Add the failure-classification paragraph to SKILL.md**

Insert at the end of the "Session Continuity (critical)" section (after the bullet ending `stop and tell the user, per the role contract above.`), as a new paragraph:

```markdown
Classify failures before reacting. A request-time error naming a missing
environment variable (e.g. `Missing environment variable:
AZURE_OPENAI_API_KEY`), a pre-inference 400/404 (base URL missing
`/openai/v1`, a deployment not exposing `/v1/responses`, the Codex 0.147.0
empty-tool-description defect, or a family id sent where a deployment name
was required), or a 429 quota/TPM error is a configuration or service
failure: stop and tell the user the specific cause — do not re-seed,
shrink, or retry. Re-seeding and payload discipline apply to silent hangs
only. MCP "Connected" status proves the handshake, not credentials, and
MCP servers inherit their environment from session start — after any
environment change, Claude Code must be fully restarted.
```

- [ ] **Step 3: Update commands/gpt-brainstorm.md routing paragraph**

Replace the paragraph beginning `Model routing: use the` (through `..."GPT model routing" rules in CLAUDE.md.`) with:

```markdown
Model routing: the dispatch model is the `--model` value if given, else
`gpt_second_opinion_model:` from CLAUDE.md, else the Codex CLI default —
under an Azure provider these are deployment names, and the dispatch model
is what the codex model parameter receives verbatim. Derive the overlay
model via the `gpt_model_alias:` registry in CLAUDE.md (exact, single-hop;
no match = the dispatch model). If no overlay below matches the overlay
model exactly, warn the user ("no tuned variant for <overlay model>; using
the generic baseline"), use the baseline alone, and record the missing
variant (role=second-opinion, keyed by the overlay model) in the
claude-setup repo's TODO.md per the "GPT model routing" rules in CLAUDE.md.
```

- [ ] **Step 4: Update commands/adversarial-review.md instruction 1**

Replace instruction 1 (the block beginning `1. Resolve the review model:` through `never write it.`) with:

```markdown
1. Resolve the dispatch model: the `--model` value if given, else
   `gpt_review_model:` from CLAUDE.md, else the Codex CLI default — under
   an Azure provider these are deployment names. Derive the overlay model
   via the `gpt_model_alias:` registry in CLAUDE.md (exact, single-hop; no
   match = the dispatch model). Check whether `agents/codex-adversary.md`
   has a `gpt-overlay:review:<overlay model>` block. If not, warn the user
   ("no tuned variant for <overlay model>; using the generic baseline") and
   record the missing variant — keyed by the overlay model — in the
   claude-setup repo's TODO.md per the "GPT model routing" rules in
   CLAUDE.md; you own this side effect; the subagent is read-only and must
   never write it. Pass the dispatch model to the subagent for the wire
   call.
```

- [ ] **Step 5: Run tests and verify the edits landed**

Run:

```bash
bash tests/prompt-contract-test.sh
grep -c 'gpt_model_alias' skills/gpt-brainstorming/SKILL.md commands/gpt-brainstorm.md commands/adversarial-review.md
grep -c 'dispatch model' skills/gpt-brainstorming/SKILL.md commands/gpt-brainstorm.md commands/adversarial-review.md
```

Expected: contract suite all-pass (the `--model`, budget, and marker guards are untouched); every grep count ≥ 1 per file.

- [ ] **Step 6: Commit**

```bash
git add skills/gpt-brainstorming/SKILL.md commands/gpt-brainstorm.md commands/adversarial-review.md
git commit -m "Callers resolve aliases: overlay model for prompts, dispatch model on the wire

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Failure classification in codex-adversary

**Files:**
- Modify: `agents/codex-adversary.md` (the "Hard rules" section)
- Test: `tests/prompt-contract-test.sh`

**Interfaces:**
- Consumes: nothing new — the agent already receives the resolved (dispatch) model from callers; Task 2's prose keeps it that way.
- Produces: nothing later tasks rely on.

- [ ] **Step 1: Replace the single-line failure rule with the classification block**

Read `agents/codex-adversary.md`. In "Hard rules", replace the bullet:

```markdown
- If the `codex` tool fails (auth, timeout), report the failure and stop —
  do not substitute your own review, since same-model review defeats the
  purpose of this subagent.
```

with:

```markdown
- **Classify a failure before reacting — splitting is for size only, and on
  no failure do you substitute your own review (same-model review defeats
  the purpose of this subagent):**
  - A request-time error naming a missing environment variable (e.g.
    `Missing environment variable: AZURE_OPENAI_API_KEY`) is a
    configuration outage: report it and stop. The MCP server "connects"
    without credentials — this error fires only at request time, and after
    environment changes Claude Code must be fully restarted.
  - A pre-inference 400 or 404 is a configuration or version failure:
    report it and stop, naming the likely causes to check — the Codex
    0.147.0 empty-tool-description defect (pin 0.146.1), a base URL missing
    `/openai/v1`, a deployment not exposing `/v1/responses`, or a
    model-family id sent where an Azure deployment name was required. Never
    respond to these by splitting the payload.
  - A 429 (quota, TPM, credits) is a service limit: report it and stop. It
    is not a payload-size problem.
  - If MCP calls fail while the interactive `codex` CLI works, suspect a
    binary split-brain: the MCP wrapper's PATH can resolve a different
    codex version than the shell's (`type -a codex`, `codex --version` in
    both contexts). Report that diagnosis and stop.
```

Leave the `Never retry a timed-out payload unchanged` bullet and everything else in the section untouched.

- [ ] **Step 2: Run tests**

Run: `bash tests/prompt-contract-test.sh`
Expected: all pass — specifically the greps for `read-only`, `20KB`, `30KB`, `Never retry a timed-out payload unchanged`, the four report headings, and the review overlay markers.

- [ ] **Step 3: Commit**

```bash
git add agents/codex-adversary.md
git commit -m "codex-adversary: classify env/400/429/split-brain failures before any retry

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Azure runbook, README requirements, TODO debt entry

**Files:**
- Create: `docs/azure-openai-codex.md`
- Modify: `README.md` (Requirements section + "What's here" table)
- Modify: `TODO.md` (new section)
- Test: `tests/prompt-contract-test.sh` and `bash tests/uninstall-test.sh </dev/null`

**Interfaces:**
- Consumes: the alias vocabulary from Task 1 (the runbook links to CLAUDE.md's registry).
- Produces: the doc path `docs/azure-openai-codex.md` that README links to.

- [ ] **Step 1: Create docs/azure-openai-codex.md**

The content below contains its own nested code fences (a `toml` block and
others), which break rendered views of THIS plan — read the raw plan file.
The runbook's content runs from the `# Running the pipeline against Azure
OpenAI` heading through the final line `playbook applies only to silent
timeouts on oversized sessions.`

```markdown
# Running the pipeline against Azure OpenAI

The pipeline's GPT stages call the Codex MCP server, which talks to
whatever provider `~/.codex/config.toml` selects. This runbook is the
Azure-specific setup: config, credentials, the version pin, and how to
verify the whole chain. Nothing in this repo's installer touches
`~/.codex` — this configuration is yours to own.

## Codex configuration

```toml
model = "<your-deployment-name>"
model_provider = "azure"

[model_providers.azure]
name = "Azure OpenAI"
base_url = "https://<your-resource>.openai.azure.com/openai/v1"
env_key = "AZURE_OPENAI_API_KEY"
wire_api = "responses"
```

Four rules, each learned the hard way:

- `model` is the Azure **deployment name**, not the model-family name. The
  pipeline sends it verbatim on every call (the "dispatch model"). If your
  deployment name differs from the family id, add one
  `gpt_model_alias: <deployment>=<family>` line in CLAUDE.md ("GPT model
  routing") so prompt overlays still match.
- `model_provider = "azure"` must be set at the **top level**, not just the
  provider block defined — otherwise cached ChatGPT auth can win.
- `env_key` is the environment variable **NAME**. Pasting the key value
  produces `Missing environment variable: <the key string>`.
- `wire_api = "responses"` is the only supported protocol; the deployment
  must expose `/v1/responses` (the `/openai/v1` base path, no
  `api-version` query needed).

## Version pin — do not run 0.147.0 against Azure

Codex CLI 0.147.0 wraps a built-in tool with an empty `description`, which
Azure's Responses API schema rejects, so **every request fails before
inference** with `Invalid 'input[0].tools[0].description'`. Pin 0.146.1
(`npm install -g @openai/codex@0.146.1`) until the regression is fixed
upstream (openai/codex #37380, #37487, #37675). TODO.md tracks the unpin.

Watch for the duplicate-binary trap: `npm install -g` and the native
installer write to different places (e.g. `~/.local/bin/codex`), and the
MCP wrapper resolves whatever its own PATH finds. Check with `type -a
codex` and run `codex --version` from a shell AND confirm the version the
MCP wrapper's PATH resolves — a stale 0.147.0 there reproduces the Azure
bug only in MCP calls while the interactive CLI works.

## Getting the key into the environment

- Shell/CLI: `export AZURE_OPENAI_API_KEY="..."` in `~/.zshrc`. It must
  resolve in non-interactive shells: verify with
  `zsh -c 'source ~/.zshrc; echo ${AZURE_OPENAI_API_KEY:0:8}'`, and keep
  the export above any interactive-guard early return.
- GUI apps (Codex Desktop): `launchctl setenv AZURE_OPENAI_API_KEY "..."`,
  made persistent with a LaunchAgent. Fully quit and relaunch the app
  after setting.
- Hardening: keep the key in the macOS Keychain and export via
  `security find-generic-password -s AZURE_OPENAI_API_KEY -w` in
  `~/.zshrc`, so no plaintext key sits in dotfiles.

## Wiring the MCP server in Claude Code

Two working shapes:

- Shell wrapper (key stays in `~/.zshrc`):
  `claude mcp add codex -s user -- zsh -c 'source ~/.zshrc >/dev/null 2>&1; exec codex mcp-server'`
- `${VAR}` expansion in the MCP `env` block — Claude Code resolves it from
  its launch environment, keeping the key value out of `~/.claude.json`.

Two operational gotchas:

- **"Connected" proves the handshake only.** The server starts fine
  without the key; `Missing environment variable: AZURE_OPENAI_API_KEY`
  fires at request time.
- **MCP servers inherit the environment from session start.** After any
  env or config change, fully restart Claude Code (or `/mcp` → reconnect).

## Verification playbook

1. `echo $AZURE_OPENAI_API_KEY` in the launching shell;
   `launchctl getenv AZURE_OPENAI_API_KEY` for GUI apps.
2. `codex --version` → 0.146.1, and `type -a codex` shows one binary (or
   all copies at the pinned version).
3. In Codex: `/status` must show the Azure provider URL and your
   deployment name.
4. Negative test: `codex logout`, `unset OPENAI_API_KEY`, run a prompt — a
   response can only have come from Azure.
5. Ground truth: watch the Azure resource's metrics (request count,
   processed tokens) while sending one prompt from one surface at a time.
6. From a Claude Code session, invoke a trivial codex MCP call; success
   plus Azure metrics movement verifies the full chain.
7. Debugging: `RUST_LOG=debug codex "test" 2>~/codex-debug.log`, grep for
   your resource host.

## Failure signatures (what the pipeline's stop-and-report rules key on)

| Signature | Meaning | Fix |
|---|---|---|
| `Missing environment variable: AZURE_OPENAI_API_KEY` | Key not in the environment the failing surface inherited | Export/launchctl per above; restart Claude Code |
| `Invalid 'input[0].tools[0].description'` (400, pre-inference) | Codex 0.147.0 regression | Pin 0.146.1; check for duplicate binaries |
| 404 on the model | Family id sent where a deployment name was needed, or wrong deployment | Fix the model value / alias registry |
| 400 protocol/endpoint errors | Base URL missing `/openai/v1`, or deployment lacks `/v1/responses` | Fix base_url / deployment |
| 429 | Quota / TPM / credits exhausted | Service limit — not a payload problem; check Azure quotas |

None of these are payload-size problems: the pipeline's split-and-retry
playbook applies only to silent timeouts on oversized sessions.
```

- [ ] **Step 2: Update README Requirements**

Read `README.md`. Replace the sentence `The **codex MCP server** must be configured, and GPT credits available. Both stage 1 and stage 3 depend on it.` with:

```markdown
The **codex MCP server** must be configured against exactly one provider —
both stage 1 and stage 3 depend on it:

- **OpenAI-hosted:** GPT credits on the account Codex uses; works as-is.
- **Azure-hosted:** an Azure OpenAI deployment exposing the v1 Responses
  API, set up per [docs/azure-openai-codex.md](docs/azure-openai-codex.md).
  **Pin Codex CLI to 0.146.1** — 0.147.0 fails every Azure request before
  inference (upstream openai/codex #37380/#37487/#37675). Under Azure,
  model values are *deployment names*; the `gpt_model_alias:` registry in
  CLAUDE.md maps them to prompt-overlay families.
```

(The following sentence about stop-and-tell-the-user stays.)

In the "What's here" table, add:

```markdown
| `docs/azure-openai-codex.md` | Azure OpenAI runbook: Codex config, version pin, env delivery, verification. |
```

- [ ] **Step 3: Add the TODO debt entry**

Append to `TODO.md`:

```markdown

## Version pins

- [ ] unpin codex from 0.146.1 once the empty-tool-description regression
      (openai/codex #37380/#37487/#37675) is fixed upstream and a newer
      release passes the verification playbook in docs/azure-openai-codex.md
```

- [ ] **Step 4: Run tests**

Run:

```bash
bash tests/prompt-contract-test.sh
bash tests/uninstall-test.sh </dev/null
grep -c '```' docs/azure-openai-codex.md
```

Expected: both suites all-pass (TODO schema guard must accept the new non-prompt-variant section); the fence count is even (balanced fences — note the runbook nests a ```toml block, transcribe carefully).

- [ ] **Step 5: Commit**

```bash
git add docs/azure-openai-codex.md README.md TODO.md
git commit -m "Azure runbook, two-provider requirements, 0.146.1 unpin debt

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Whole-change verification — overlay immutability and the routing matrix

**Files:**
- Test only; no files modified. (Fix anything found, in the file that owns it.)

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces: the acceptance evidence the spec requires.

- [ ] **Step 1: Prove overlay/baseline blocks are byte-for-byte unchanged**

`BASE` is the commit that added this plan file (Tasks 1–4 never touch it, so the most recent commit touching it is the plan-add commit). Run:

```bash
BASE=$(git log -n1 --format=%H -- docs/superpowers/plans/2026-08-14-azure-codex-support.md)
for spec in ideation:skills/gpt-brainstorming/SKILL.md review:agents/codex-adversary.md second-opinion:commands/gpt-brainstorm.md; do
  role="${spec%%:*}"; file="${spec#*:}"
  for kind in baseline overlay; do
    git show "$BASE:$file" | sed -n "/gpt-${kind}:${role}/,/gpt-${kind}:${role}.*end/p" > "/tmp/claude-blocks-old-${role}-${kind}.txt"
    sed -n "/gpt-${kind}:${role}/,/gpt-${kind}:${role}.*end/p" "$file" > "/tmp/claude-blocks-new-${role}-${kind}.txt"
    diff "/tmp/claude-blocks-old-${role}-${kind}.txt" "/tmp/claude-blocks-new-${role}-${kind}.txt" && echo "OK ${role} ${kind} unchanged"
  done
done
```

Expected: `OK <role> <kind> unchanged` for all six pairs. Any diff output is a Task 1–4 regression — fix the offending edit, do not adjust the blocks.

- [ ] **Step 2: Walk the routing matrix against the policy text**

For each row, find the exact sentences in CLAUDE.md / SKILL.md / the commands that produce the expected result, and record file + quoted phrase:

| Scenario | Expected |
|---|---|
| OpenAI family id, no alias | Existing overlay selected (overlay model = dispatch model) |
| Azure deployment with alias | Family overlay selected; no spurious TODO |
| Azure deployment without alias | Baseline + TODO keyed by the deployment name |
| Azure `--model` override with alias | Deployment sent on the wire; family overlay used |
| Malformed/conflicting alias | Stop with configuration error before dispatch |

Every row must be unambiguous from the policy text alone. If any row requires inference, tighten the prose in the owning file and re-run Task 1/2 tests.

- [ ] **Step 3: Full suites one last time**

Run:

```bash
bash tests/prompt-contract-test.sh
bash tests/uninstall-test.sh </dev/null
bash -n install.sh uninstall.sh managed-files.sh tests/uninstall-test.sh tests/prompt-contract-test.sh
git diff --stat "$BASE"..HEAD -- install.sh uninstall.sh managed-files.sh
```

(`$BASE` from Step 1.)

Expected: both suites all-pass; `bash -n` silent; the final `git diff --stat` over the installer files is **empty** (untouched boundary).

- [ ] **Step 4: Commit (only if Step 1–2 forced fixes)**

```bash
git add -A
git commit -m "Verification fixes from routing-matrix walkthrough

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Spec coverage map

| Spec requirement | Task |
|---|---|
| Alias registry lines + single-hop exact lookup rule in CLAUDE.md | 1 |
| Overlay selection + TODO identity via overlay model; wording updates | 1 (CLAUDE.md), 2 (callers) |
| Contract-test guard: malformed alias rejected, empty registry valid, conflicts flagged | 1 |
| Skill: alias-aware variant reporting; env/400/429 stop-and-report | 2 |
| Commands: deployment-name `--model` warnings; alias-aware TODO recording | 2 |
| codex-adversary: failure classes replace timeout-only heuristic; split-brain diagnostic | 3 |
| README: two-provider prerequisites + 0.147.0 warning + guide link | 4 |
| docs/azure-openai-codex.md: sanitized TOML, protocol requirements, env delivery, restarts, version/PATH checks, verification | 4 |
| TODO.md: unpin-after-upstream-fix debt | 4 |
| Overlay blocks byte-for-byte unchanged; installer boundary untouched; both suites green; routing matrix unambiguous | 5 |
| No secrets in tracked files | Global Constraints (placeholders only, verified by review) |
| Optional credentialed smoke test on adopter machine | Out of CI scope per spec; owner runs the runbook playbook |
