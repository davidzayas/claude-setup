## Cross-model pipeline policy

This project uses a three-stage, two-model pipeline:

1. **Brainstorming / requirements → GPT.** For any creative work (new
   features, components, functionality, behavior changes), use the
   `gpt-brainstorming` skill INSTEAD of `superpowers:brainstorming`. GPT is
   the ideator; Claude facilitates and scribes. Never run Claude-only
   brainstorming unless the user explicitly chooses it as a fallback.

2. **Planning / implementation → Claude.** writing-plans, subagent-driven
   development, coding, and testing run on Claude models as normal. Do not
   delegate implementation to the codex tool.

3. **Pre-completion review → GPT.** Before declaring any non-trivial
   implementation task complete, delegate a review to the codex-adversary
   subagent and adjudicate every finding: fix, or rebut explicitly. Do not
   silently drop findings. MEDIUM/LOW may be logged as accepted debt.

If the codex MCP server is unavailable at stage 1 or 3, stop and tell the
user rather than silently substituting Claude for GPT's role.

## GPT model routing

Per-role model defaults. Resolution order for every GPT call: an explicit
model named in the invocation wins, then the role's line below, then the
Codex CLI default from ~/.codex/config.toml. For the slash commands that
accept --model, that flag is the SOLE explicit-override mechanism —
free-text model mentions inside their arguments are not overrides. The
"named in the invocation" rule applies to skill invocations (e.g.
"brainstorm X with o3-pro" via the gpt-brainstorming skill).

gpt_brainstorm_model: gpt-6-astra
gpt_second_opinion_model: gpt-6-astra
gpt_review_model: gpt-6-astra

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
dispatch and report it rather than picking one. A line starting with
`gpt_model_alias:` that does not match the format exactly is likewise a
configuration error: stop and report it rather than treating the
deployment as unlisted.

Each GPT-facing role file owns a generic baseline prompt plus per-model
overlays, delimited by `gpt-baseline`/`gpt-overlay` HTML-comment markers.
Select an overlay by EXACT match against the overlay model (alias-resolved
as above) — never guess from a similar name. If no overlay exists for the
overlay model: warn the user before dispatch, use the generic baseline
alone, and record the missing variant — keyed by the overlay model, so one
family maps to one entry regardless of deployment naming — in the
claude-setup repo's TODO.md as
`- [ ] prompt-variant: role=<role> model=<exact-model-id>` (one entry per
role/model pair; skip if already present). Re-read TODO.md immediately
before appending, so concurrent sessions do not write duplicates.

TODO.md lives in the claude-setup source repo, never the active project.
Locate it by resolving the symlink target of `~/.claude/CLAUDE.md` and
verifying its parent contains `managed-files.sh`. If resolution fails and the
current repo is itself claude-setup (managed-files.sh plus all five managed
prompt paths present), write there; otherwise print the exact entry for
manual recording and continue.

If a role's default line is missing, warn and fall through to the Codex CLI
default with the generic baseline; if the effective model cannot be
determined exactly, do not record a model-specific TODO. If TODO.md is
found but cannot be written, warn, continue with the generic baseline, and
report that persistent tracking failed.

Overlays tune GPT-specific communication only. They may never weaken stage
boundaries, read-only review, the payload budgets (≤20KB working per codex
session, 30KB hard danger boundary), output contracts, or
stop-on-MCP-failure behavior. An overlay may emphasise a baseline rule only
when a recorded smoke or review failure names it, and must not restate the
rule's content — the contract test rejects any baseline sentence repeated
verbatim in an overlay.
