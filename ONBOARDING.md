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
2. **Codex CLI** — Azure users MUST pin the version (0.147.0 fails every
   Azure request before inference):

   ```bash
   npm install -g @openai/codex@0.146.1
   ```

   Point `~/.codex/config.toml` at exactly one provider — OpenAI-hosted
   (sign-in or API key) or Azure-hosted (full TOML in the repo's
   `docs/azure-openai-codex.md`; note the model value is your Azure
   DEPLOYMENT NAME, and the `gpt_model_alias:` registry in CLAUDE.md maps
   it to a prompt-overlay family if the names differ).
3. **Codex MCP server** registered in Claude Code:

   ```bash
   claude mcp add codex -s user -- zsh -c 'source ~/.zshrc >/dev/null 2>&1; exec codex mcp-server'
   ```

### Verify the chain

| Level | Command | Proves |
|---|---|---|
| Binaries | `claude --version && codex --version` | Both CLIs present (Azure: 0.146.1) |
| Registration | `claude mcp get codex` | MCP server registered — handshake only |
| Credentials | one trivial codex call from a Claude Code session (fully restart it first) | The whole chain, end to end |

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
- If the codex MCP server is down, the pipeline **stops and tells you**
  rather than quietly substituting Claude for GPT's role — a Claude review
  of Claude's code is not a second opinion.

## 4. When something breaks

Failure signatures and fixes live in `docs/azure-openai-codex.md`
(missing env var, the 0.147.0 pre-inference 400, deployment-name 404s,
429 quota, and the MCP-works-but-CLI-doesn't binary split-brain). Rule of
thumb: none of those are payload-size problems — report and fix the
config; don't retry.
