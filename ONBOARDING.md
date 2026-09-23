# Onboarding: David's cross-model Claude Code setup

A three-stage, two-model development pipeline: **GPT ideates, Claude
builds, GPT reviews.** The model that designs a thing is the worst judge of
whether the design is sound — so the pipeline's boundaries are model
boundaries, not just phase boundaries.

Repo: https://github.com/davidzayas/claude-setup

## 1. Prerequisites — BEFORE running install.sh

The pipeline drives GPT through the **Codex CLI** and its **MCP server**
registered in Claude Code. install.sh checks these and refuses to link an
unusable setup (bypass with `SKIP_CHECKS=1` if you deliberately want the
config files first).

1. **Claude Code** (`claude`) — verify: `claude --version`.
2. **Codex CLI** — Azure users MUST use a verified version: 0.147.0–0.148.x
   fail every Azure request before inference; 0.149.1 is verified working
   (2026-08-26; see the repo runbook's version guidance):

   ```bash
   npm install -g @openai/codex@0.149.1
   ```

   Point `~/.codex/config.toml` at exactly one provider — OpenAI-hosted
   (sign-in or API key) or Azure-hosted (full TOML in the repo's
   `docs/azure-openai-codex.md`; note the model value is your Azure
   DEPLOYMENT NAME, and the `gpt_model_alias:` registry in CLAUDE.md maps
   it to a prompt-overlay family if the names differ). The pipeline's
   three GPT roles default to **`gpt-6-astra`** (CLAUDE.md "GPT model
   routing"), so an Azure resource needs a deployment with exactly that
   name — or an alias line mapping your deployment to `gpt-6-astra`.
3. **Codex MCP server** registered in Claude Code:

   ```bash
   claude mcp add codex -s user -- zsh -c 'source ~/.zshrc >/dev/null 2>&1; exec codex mcp-server'
   ```

### Verify the chain

| Level | Command | Proves |
|---|---|---|
| Binaries | `claude --version && codex --version` | Both CLIs present (Azure: 0.149.1+) |
| Registration | `claude mcp get codex` | MCP server registered — handshake only |
| Credentials | one trivial codex call from a Claude Code session (fully restart it first), `model: gpt-6-astra` | The whole chain, end to end, against the deployment the pipeline actually uses |

"Connected" does **not** prove credentials — the key is only checked at
request time. MCP servers inherit their environment from session start, so
fully restart Claude Code after any env change.

## 2. Install

```bash
git clone https://github.com/davidzayas/claude-setup.git ~/playground/claude-setup
cd ~/playground/claude-setup
DRY_RUN=1 ./install.sh   # preflight + preview, changes nothing
./install.sh
```

The preflight runs first: it reports every missing dependency at once and
exits before touching anything. A clean run symlinks five files into
`~/.claude`, backing up anything already there as
`<name>.backup-<timestamp>` — nothing overwritten or deleted, and
`./uninstall.sh` reverses it exactly (it refuses to touch anything the
repo doesn't own, and asks rather than guesses when a file has several
backups).

`settings.json` is NOT linked — merge it by hand (it declares the
superpowers plugin the pipeline depends on; the preflight does not check
plugins, so verify superpowers appears after merging and restarting).

### Optional: LSP code intelligence

The global CLAUDE.md tells every session to use the built-in `LSP` tool
(definitions, references, call hierarchy) before grep/sed. Give it servers to
talk to with the hand-run kit in `lsp/`. It is not part of `install.sh`, and
`uninstall.sh` doesn't undo it:

```bash
lsp/install-lsp-binaries.sh        # nine language servers (5–15 min; may ask for your password)
source ~/.zprofile
lsp/install-claude-lsp-plugins.sh  # matching plugins, user scope, only where the server exists
```

Then start a new session. Details, scopes, and troubleshooting (C#/.NET 10,
nvm shadowing TypeScript, desktop-app PATH): `docs/lsp-setup.md`.

### Run the tests

Four self-contained suites, no dependencies beyond bash, grep, awk
(plus rsync and python3 for the third). Run them after cloning, and again
before opening any PR that touches a prompt file, CLAUDE.md, or the scripts:

```bash
bash tests/uninstall-test.sh              # install/uninstall in a throwaway tmpdir (~10s)
bash tests/prompt-contract-test.sh        # static contract on the prompt files (<1s)
bash tests/prompt-contract-mutation-test.sh   # negative tests for the checker (~30s)
bash tests/lsp-installers-test.sh        # LSP installers against a fake claude (<5s)
```

- `uninstall-test.sh` exercises `install.sh`/`uninstall.sh` end to end in a
  temp home — backups, restores, the interactive menu, the preflight. If it
  reports `skipped (no pseudo-terminal)`, the four menu tests could not get a
  pty on this machine; that is a skip, not a failure.
- `prompt-contract-test.sh` is the guard on the managed prompt files: every
  overlay's markers exactly once and in order, baseline+overlay under the
  12288-byte cap for every model present, the required budget / read-only /
  stop-on-MCP-failure strings, CLAUDE.md's routing lines and alias registry,
  TODO.md's `prompt-variant` schema, and the no-restatement rule (an overlay
  may emphasise a baseline rule but may not repeat a baseline clause
  verbatim). It reads only the repo; it never calls a model.
- `prompt-contract-mutation-test.sh` proves the checker still catches what it
  claims to: each case plants one defect in a temp copy and expects a FAIL
  line naming that guard. If you change the checker, this is the suite that
  tells you whether you weakened it.
- `lsp-installers-test.sh` runs the plugins installer against a fake
  `claude` on a PATH containing only shims: all nine binary→plugin pairs,
  missing binaries, marketplace absent or look-alike, scopes, a failed
  install. It also checks the binaries installer's TypeScript shadowing
  check. It never installs anything for real.

A green run of all four is what "the repo is healthy" means here; the live
credential check in §1 is separate and still needed once per machine.

### The backlog

`TODO.md` is the repo-local backlog and is deliberately empty as of
2026-09-09 — every item from the gpt-6-astra migration was either done or
closed as won't-fix, and the one piece of accepted debt (the 25-byte clause
floor in the no-restatement check) now lives as a comment beside the value
it describes in `tests/prompt-contract-test.sh`. The file is not installed
into `~/.claude` and must never be added to `managed-files.sh`; the contract
test enforces that.

It is not only a notepad. The three GPT-facing roles append a
`- [ ] prompt-variant: role=<role> model=<model>` line automatically when a
call resolves to a model that has no tuned overlay (CLAUDE.md "GPT model
routing"). So an entry appearing there is a signal — someone dispatched to a
model the prompts are not tuned for — not clutter. Resolve it by adding an
overlay for that role and model and ticking the line; the contract test
rejects malformed or duplicate entries.

## 3. How the pipeline works day to day

- **New feature or behavior change?** The `gpt-brainstorming` skill runs
  the requirements phase with GPT as ideator; Claude facilitates, checks
  proposals against the codebase, and writes the spec. Design approval
  gates implementation.
- **Implementation** is Claude-native (writing-plans, TDD,
  subagent-driven development from the superpowers plugin).
- **Before anything ships**, the `codex-adversary` agent gets an
  independent GPT review; every finding is fixed or explicitly rebutted —
  never silently dropped. `/adversarial-review` runs it on demand;
  `/gpt-brainstorm` gives you a two-model second opinion on anything.
- **Month end.** Ask for "the capex/opex report for the last 30 days" (or
  `/capex-opex-report`). The skill scans your local transcripts, classifies
  each session by whether the product was in service, and publishes a
  finance-ready artifact. Name any personal repos to exclude.
- **Reading or refactoring code.** Sessions reach for the built-in `LSP`
  tool first (CLAUDE.md "Code intelligence"). Renames start from
  `findReferences` and are edited site by site, never with a multi-file sed.
  If a language has no server, or the server fails, the session says so in
  a line and falls back to targeted text search.
- If the codex MCP server is down, the pipeline **stops and tells you**
  rather than quietly substituting Claude for GPT's role — a Claude review
  of Claude's code is not a second opinion.
- **Which GPT model.** All three roles run on `gpt-6-astra` since
  2026-09-08, each with a tuned prompt overlay validated by a five-case
  smoke run (`docs/prompt-smoke-2026-09-08-gpt-6-astra.md`). The previous
  `gpt-5.6-sol` overlays are kept: pass `--model gpt-5.6-sol` to
  `/gpt-brainstorm` or `/adversarial-review` to use it for one call, or
  restore the three `gpt_*_model:` lines in CLAUDE.md together to roll
  back. Switching to a new model means adding an overlay per role and
  rerunning the smoke cases — the 2026-09-08 spec and plan under
  `docs/superpowers/` are the template.

## 4. When something breaks

Failure signatures and fixes live in `docs/azure-openai-codex.md`
(missing env var, the 0.147.0 pre-inference 400, deployment-name 404s,
429 quota, and the MCP-works-but-CLI-doesn't binary split-brain). Rule of
thumb: none of those are payload-size problems — report and fix the
config; don't retry.

LSP problems (plugin shows `Executable not found in $PATH`, C# won't
start, TypeScript breaks after a Node switch) live in `docs/lsp-setup.md`
→ Troubleshooting.
