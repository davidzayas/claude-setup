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
Codex CLI default from ~/.codex/config.toml.

gpt_brainstorm_model: gpt-5.6-sol
gpt_second_opinion_model: gpt-5.6-sol
gpt_review_model: gpt-5.6-sol

Each GPT-facing role file owns a generic baseline prompt plus per-model
overlays, delimited by `gpt-baseline`/`gpt-overlay` HTML-comment markers.
Select an overlay by EXACT model-id match only — never guess from a similar
name. If no overlay exists for the resolved model: warn the user before
dispatch, use the generic baseline alone, and record the missing variant in
the claude-setup repo's TODO.md as
`- [ ] prompt-variant: role=<role> model=<exact-model-id>` (one entry per
role/model pair; skip if already present).

TODO.md lives in the claude-setup source repo, never the active project.
Locate it by resolving the symlink target of `~/.claude/CLAUDE.md` and
verifying its parent contains `managed-files.sh`. If resolution fails and the
current repo is itself claude-setup (managed-files.sh plus all five managed
prompt paths present), write there; otherwise print the exact entry for
manual recording and continue.

Overlays tune GPT-specific communication only. They may never weaken stage
boundaries, read-only review, the payload budgets (≤20KB working per codex
session, 30KB hard danger boundary), output contracts, or
stop-on-MCP-failure behavior.
