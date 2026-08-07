---
description: Brainstorm or pressure-test requirements with GPT (via Codex MCP), then synthesize both models' views. Args: the topic or a path to a requirements/design doc.
disable-model-invocation: true
---

Run a structured two-model brainstorm on: $ARGUMENTS
(If $ARGUMENTS is a file path, read the file first and treat its contents as the subject.)

Protocol — keep the two perspectives genuinely independent:

1. **Your position first, privately.** Draft your own analysis/approach but do
   NOT show it to the user yet and do NOT include it in the prompt to Codex
   (no anchoring).
2. **Get GPT's independent take.** Call the `mcp__codex__codex` tool with
   sandbox read-only. Prompt it as a skeptical principal engineer / product
   architect: ask for its recommended approach, the top risks, the questions
   it would force the team to answer before building, and at least one
   alternative it would seriously consider. Give it the same raw inputs you
   received — nothing more.
3. **Structured disagreement.** Use `mcp__codex__codex-reply` to send it your
   draft position (now that it has committed to its own) and ask it to attack
   yours: what breaks, what's underspecified, where you're being optimistic.
4. **Synthesize for the user:**
   - `## Where we agree` — convergent recommendations (highest confidence)
   - `## Where we diverge` — each disagreement with both positions and your
     adjudication, clearly labeled as yours
   - `## Open questions` — the combined list of questions that must be
     answered before implementation
   - `## Recommended next step`

Keep the synthesis under a page. Divergence points are the valuable output —
never average the two views into mush.
