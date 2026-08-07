## Cross-model pipeline policy

This project uses a three-stage, two-model pipeline:

1. **Brainstorming / requirements → GPT.** For any creative work (new
   features, components, functionality, behavior changes), use the
   `gpt-brainstorming` skill INSTEAD of `superpowers:brainstorming`. GPT is
   the ideator; Claude facilitates and scribes. Never run Claude-only
   brainstorming unless the user explicitly chooses it as a fallback.

   gpt_brainstorm_model: gpt-5.6-sol   # <- set your preferred model; invocation
                                   #    ("brainstorm X with o3") overrides this

2. **Planning / implementation → Claude.** writing-plans, subagent-driven
   development, coding, and testing run on Claude models as normal. Do not
   delegate implementation to the codex tool.

3. **Pre-completion review → GPT.** Before declaring any non-trivial
   implementation task complete, delegate a review to the codex-adversary
   subagent and adjudicate every finding: fix, or rebut explicitly. Do not
   silently drop findings. MEDIUM/LOW may be logged as accepted debt.

If the codex MCP server is unavailable at stage 1 or 3, stop and tell the
user rather than silently substituting Claude for GPT's role.
