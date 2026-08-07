# David's Claude Code setup

A three-stage, two-model development pipeline: **GPT ideates, Claude builds,
GPT reviews.** Plus the supporting agent, skill, and slash commands that make
it actually run.

The idea is that the model which designs a thing is the worst judge of whether
the design is sound, and the model which writes the code is the worst judge of
whether the code is correct. So the boundaries of the pipeline are model
boundaries, not just phase boundaries.

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

`settings.json` is **not** linked — see below.

## What's here

| File | What it does |
|---|---|
| `CLAUDE.md` | The pipeline policy. The core of the setup. |
| `agents/codex-adversary.md` | Subagent that dispatches a review to GPT via the codex MCP tool, quality-gates the response, and returns a structured report. Verifies findings against the code before passing them on — cross-model review only earns its keep if hallucinated findings die there. |
| `skills/gpt-brainstorming/SKILL.md` | Fork of `superpowers:brainstorming` where GPT generates and Claude facilitates, verifies against the codebase, and scribes. |
| `commands/adversarial-review.md` | `/adversarial-review` — stage 3 on demand. |
| `commands/gpt-brainstorm.md` | `/gpt-brainstorm` — stage 1 on demand. |
| `settings.json` | Plugins and UI prefs. Merge by hand. |

## Requirements

The **codex MCP server** must be configured, and GPT credits available. Both
stage 1 and stage 3 depend on it. The policy deliberately says to *stop and
tell the user* if it's unavailable rather than quietly substituting Claude —
a Claude review of Claude's code is not a second opinion, and silently
downgrading to one is worse than having no review, because you still believe
you got one.

The `superpowers` plugin provides the planning, TDD, and subagent-driven
development skills the policy leans on. It's listed in `settings.json`.

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
