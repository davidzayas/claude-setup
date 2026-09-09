# David's Claude Code setup

A three-stage, two-model development pipeline: **GPT ideates, Claude builds,
GPT reviews.** Plus the supporting agent, skill, and slash commands that make
it actually run.

The idea is that the model which designs a thing is the worst judge of whether
the design is sound, and the model which writes the code is the worst judge of
whether the code is correct. So the boundaries of the pipeline are model
boundaries, not just phase boundaries.

## Prerequisites — install these BEFORE running install.sh

The pipeline drives GPT through the **Codex CLI** and its **MCP server**
registered in Claude Code. Without them, stage 1 and stage 3 cannot run —
so `install.sh` checks and refuses to link an unusable setup (bypass with
`SKIP_CHECKS=1` if you deliberately want the config files first).

1. **Claude Code** (`claude`) — verify: `claude --version`.
2. **Codex CLI** — Azure users MUST use a verified version: 0.147.0–0.148.x
   fail every Azure request before inference; 0.149.1 is verified working
   (2026-08-26; see the runbook's version guidance):

   ```bash
   npm install -g @openai/codex@0.149.1
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
| Binaries | `claude --version && codex --version` | Both CLIs present (Azure: 0.149.1+) |
| Registration | `claude mcp get codex` | MCP server registered — handshake only |
| Credentials | one trivial codex call from a Claude Code session (fully restart it first) | The whole chain, end to end |

`claude mcp get codex` saying "Connected" does **not** prove credentials —
the key is only checked at request time. Environment delivery, restart
gotchas, and troubleshooting: [docs/azure-openai-codex.md](docs/azure-openai-codex.md).

## Install

```bash
git clone <this-repo> ~/playground/claude-setup
cd ~/playground/claude-setup
DRY_RUN=1 ./install.sh   # see what it would do
./install.sh
```

It symlinks into `~/.claude`, backing up anything already there as
`<name>.backup-<timestamp>`. Nothing is overwritten or deleted. Symlinks
rather than copies, so editing either path edits the same file.

install.sh first checks the prerequisites above and stops — before touching
anything — if one is missing (`SKIP_CHECKS=1` bypasses; `DRY_RUN=1` reports
the same checks advisorily).

`settings.json` is **not** linked — see below.

To undo an install:

```bash
DRY_RUN=1 ./uninstall.sh   # preflight + backup selection + exact plan, no changes
./uninstall.sh
```

It removes only symlinks that point into this repo, then restores the
`.backup-<timestamp>` files install.sh created. If anything at a managed
path is *not* owned by this repo — a plain file, someone else's symlink, a
missing path — it lists every conflict and exits without changing anything.
A file with several backups gets a numbered prompt (it refuses to guess,
and refuses to run non-interactively until you thin the backups out). A
path that had no backup is removed and left absent, because nothing was
there before install. Uninstalling twice is safe but the second run exits
nonzero: with no record of *why* the paths are gone, it reports them as
conflicts rather than claiming success.

## What's here

| File | What it does |
|---|---|
| `CLAUDE.md` | The pipeline policy. The core of the setup. |
| `agents/codex-adversary.md` | Subagent that dispatches a review to GPT via the codex MCP tool, quality-gates the response, and returns a structured report. Verifies findings against the code before passing them on — cross-model review only earns its keep if hallucinated findings die there. |
| `skills/gpt-brainstorming/SKILL.md` | Fork of `superpowers:brainstorming` where GPT generates and Claude facilitates, verifies against the codebase, and scribes. |
| `commands/adversarial-review.md` | `/adversarial-review` — stage 3 on demand. |
| `commands/gpt-brainstorm.md` | `/gpt-brainstorm` — stage 1 on demand. |
| `settings.json` | Plugins and UI prefs. Merge by hand. |
| `managed-files.sh` | The one list of managed paths both scripts source. |
| `uninstall.sh` | Removes the symlinks and restores the backups; conservative to a fault. See Install. |
| `tests/uninstall-test.sh` | Self-contained regression suite for both scripts (runs in a throwaway tmpdir). |
| `tests/prompt-contract-test.sh` | Static contract checks on the prompt files: markers, byte caps, required strings, TODO schema, and the overlay no-restatement guard. |
| `tests/prompt-contract-mutation-test.sh` | Negative tests for the checker: plants one defect per case in a temp copy and asserts the checker catches it on a FAIL line naming that guard (or, for false-positive probes, still passes); also checks the uninstall suite skips its pty tests cleanly when `script` cannot allocate one. Needs rsync and python3. |
| `docs/azure-openai-codex.md` | Azure OpenAI runbook: Codex config, version pin, env delivery, verification. |

## Requirements

Everything in [Prerequisites](#prerequisites--install-these-before-running-installsh)
above, working — that section is the single source for install commands and
verification. Azure specifics (version guidance, deployment-name model
values, the `gpt_model_alias:` registry) live in
[docs/azure-openai-codex.md](docs/azure-openai-codex.md).

The policy deliberately says to *stop and
tell the user* if the codex MCP server is unavailable rather than quietly substituting Claude —
a Claude review of Claude's code is not a second opinion, and silently
downgrading to one is worse than having no review, because you still believe
you got one.

The `superpowers` plugin provides the planning, TDD, and subagent-driven
development skills the policy leans on. It's listed in `settings.json`. The installer's preflight does not check plugins — verify superpowers appears after merging settings.json and restarting.

## Two things to read before adopting this

### settings.json omits two permission keys, on purpose

The original has:

```json
"permissions": { "defaultMode": "bypassPermissions" },
"skipDangerousModePermissionPrompt": true
```

Those disable permission prompts — the agent stops asking before running
destructive commands. That's a deliberate tradeoff on a machine where the
owner understands it, and a genuinely bad default to inherit from someone
else's dotfiles. Add them yourself if you want them, knowing what they do.

### Codex hangs silently on large payloads

Learned the hard way. A review carrying a ~90KB diff plus supporting sources
produced four consecutive ~30-minute timeouts with no response and no
progress. Scoped single-document reviews on the same day worked fine and
returned genuine high-severity findings.

The important subtlety: **chunking across `codex-reply` messages does not
help**, because those chunks accumulate in the same session's context. The
fix is separate, independently-scoped sessions — and never resending a
timed-out payload unchanged, which is how one 30-minute failure becomes two
hours.

Both `agents/codex-adversary.md` and `skills/gpt-brainstorming/SKILL.md`
encode this, each for its own failure shape: the review agent guards against
one oversized payload, the brainstorming skill against slow accumulation over
many turns.

## What's deliberately not here

- **Vendor skills** (Stripe, Railway) — install from their sources.
- **`plugins/`** — `settings.json` declares them; they reinstall themselves.
- **Everything else in `~/.claude`** — `projects/` alone is hundreds of MB of
  full session transcripts, and `history.jsonl`, `debug/`, and
  `shell-snapshots/` are similar. This is a separate repo rather than a
  `git init` in `~/.claude` precisely so that sharing is opt-in per file
  instead of one `git add -A` away from publishing all of it.
