---
description: Brainstorm or pressure-test requirements with GPT (via Codex MCP), then synthesize both models' views. Args: the topic or a path to a requirements/design doc. Optional --model <exact-id> anywhere in the args.
disable-model-invocation: true
---

Run a structured two-model brainstorm on: $ARGUMENTS
(Strip an optional `--model <exact-id>` pair out of the arguments first; the
rest is the subject. If the subject is a file path, read the file and treat
its contents as the subject. Reject an empty or repeated --model value: show
the accepted syntax and stop rather than guessing.)

Model routing: use the `--model` value if given, else
`gpt_second_opinion_model:` from CLAUDE.md, else the Codex CLI default. If no
overlay below matches the resolved model exactly, warn the user ("no tuned
variant for <model>; using the generic baseline"), use the baseline alone,
and record the missing variant (role=second-opinion) in the claude-setup
repo's TODO.md per the "GPT model routing" rules in CLAUDE.md.

Protocol — keep the two perspectives genuinely independent:

1. **Your position first, privately.** Draft your own analysis/approach but
   do NOT show it to the user yet and do NOT include it in the prompt to
   Codex (no anchoring).
2. **Get GPT's independent take.** Call `mcp__codex__codex` with sandbox
   read-only and the resolved model. The prompt is the baseline below (plus
   the matching overlay), with `{topic}` filled with the raw inputs you
   received — nothing more. Omit the `{claude_position}` line and everything
   after "REBUTTAL PHASE" from this first call; the baseline text tells GPT a
   rebuttal phase is coming.
3. **Structured disagreement.** Via `mcp__codex__codex-reply`, send the
   REBUTTAL PHASE portion with `{claude_position}` filled with your draft
   position (now that GPT has committed to its own).
4. **Synthesize for the user:**
   - `## Where we agree` — convergent recommendations (highest confidence)
   - `## Where we diverge` — each disagreement with both positions and your
     adjudication, clearly labeled as yours
   - `## Open questions` — the combined list of questions that must be
     answered before implementation
   - `## Recommended next step`

Keep the synthesis under a page. Divergence points are the valuable output —
never average the two views into mush. Keep the session small: ≤20KB working
budget, 30KB hard boundary.

<!-- gpt-baseline:second-opinion:begin -->
You are a skeptical principal engineer and product architect providing an independent second opinion on {topic}. This conversation has two phases.

FIRST RESPONSE — before Claude's position is disclosed:
1. Give one clear recommendation and its rationale.
2. Identify only the top material risks.
3. Ask only forcing questions whose answers could change the recommendation.
4. Present one serious, genuinely distinct alternative and state when it would win.

Commit to your position independently. Do not infer, solicit, or speculate about Claude's view.

REBUTTAL PHASE — after Claude's position is disclosed as:
{claude_position}

Attack that position constructively. Return only substantive disagreements, missing evidence, optimistic assumptions, and concrete failure scenarios that add material information beyond your first response. Label each concern as either BLOCKER or TRADE-OFF and explain its consequence. Do not repeat prior points or manufacture disagreement. If none exist, return exactly: No substantive disagreement.
<!-- gpt-baseline:second-opinion:end -->

<!-- gpt-overlay:second-opinion:gpt-5.6-sol:begin -->
The baseline is authoritative; this overlay only tunes communication. Commit to a position before seeing Claude's. Keep the alternative genuinely distinct. During rebuttal, return only NEW material disagreements and their concrete consequences. Preserve all phase boundaries, contracts, and stop conditions.
<!-- gpt-overlay:second-opinion:gpt-5.6-sol:end -->
