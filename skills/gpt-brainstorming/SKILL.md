---
name: gpt-brainstorming
description: "You MUST use this instead of superpowers:brainstorming when the project's cross-model policy is active. Runs the brainstorming/requirements phase with GPT (via the codex MCP tool) as the ideator while Claude facilitates, verifies against the codebase, and scribes. Explores user intent, requirements and design before implementation."
---

# GPT-Led Brainstorming (fork of superpowers:brainstorming)

Turn ideas into fully formed designs and specs through collaborative dialogue —
with a strict role split: **GPT generates, Claude facilitates.**

## Role Contract (read this twice)

- **GPT (codex MCP tool)** is the ideator. It generates the clarifying
  questions, proposes the approaches, and drafts the design sections.
- **Claude (you)** is the facilitator, codebase authority, and scribe. You
  relay questions one at a time, feed answers back, annotate GPT's proposals
  with codebase-reality checks, write and commit the spec, and run the
  cross-model spec review.
- You may DISAGREE with GPT — flag it, clearly labeled as your view — but you
  may not REPLACE its output with your own. If you catch yourself generating
  requirements or design content instead of relaying GPT's, stop and re-read
  this contract.
- **If the codex MCP tool is unavailable or fails**, STOP and tell the user.
  Do not fall back to Claude-only brainstorming — that silently defeats the
  purpose of this skill. Offer superpowers:brainstorming as an explicit,
  user-chosen fallback instead.

## Model Selection and Variant Routing

Resolve the GPT model in this order (first match wins):

1. A model named in the user's invocation ("brainstorm X with o3-pro")
2. The `gpt_brainstorm_model:` line in CLAUDE.md
3. The Codex CLI default from ~/.codex/config.toml (pass no model param)

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
alias target. If resolution falls through to the CLI default (no model
param passed), say so explicitly instead of naming a dispatch model, use
the generic baseline, and skip overlay derivation and TODO recording, per
CLAUDE.md's fallback rule.

State the dispatch model, the overlay model when it differs, and the variant status in your first message so the user can correct them.
All codex calls in this skill use sandbox read-only.

## Session Continuity (critical)

The ENTIRE brainstorm is ONE Codex conversation. Make the first call with
`codex`, capture the session/thread, and use `codex-reply` for every
subsequent turn. GPT must remember in phase 5 what the user answered in
phase 3. If the session is lost, summarize the full transcript so far and
re-seed a new session before continuing.

**But keep the session small: target a ≤20KB working budget, and treat 30KB
as a hard danger boundary — sessions near it have hung silently** (no error,
no progress, a ~30-minute timeout; resending costs another 30 minutes and
fails identically). Brainstorming accumulates slowly (short questions and
answers), so the usual causes are the opening project context and any code
excerpts pasted mid-session.

- Send a *summary* of the project context in the opening call, not file
  dumps. Quote only the specific lines a codebase-reality check turns on.
- Maintain a compact decision ledger as you go: decisions made, constraints,
  open questions, approved sections. Before the session approaches the 20KB
  working budget, re-seed proactively — start a fresh session from the
  ledger, not the full transcript. Continuity comes from the ledger, not the
  thread id. A re-seed prompt is: the baseline plus the matching overlay,
  then the ledger, then one line stating the current phase and the expected
  next output.
- A hang is not the same as GPT being unavailable. If a re-seeded, small
  session still hangs, that is a genuine outage: stop and tell the user, per
  the role contract above.

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

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project,
or take any implementation action until you have presented a design and the
user has approved it. This applies to EVERY project regardless of perceived
simplicity.
</HARD-GATE>

## Anti-Pattern: "This Is Too Simple To Need A Design"

Every project goes through this process. A todo list, a single-function
utility, a config change — all of them. The design can be short, but you MUST
present it and get approval.

## Checklist

You MUST create a task for each of these items and complete them in order:

1. **Explore project context** (CLAUDE) — files, docs, recent commits
2. **Brief GPT and open the session** (CLAUDE→GPT) — send project context,
   the user's idea verbatim, and the ideator briefing (below)
3. **Ask clarifying questions** (GPT generates, CLAUDE relays) — one at a
   time; send each user answer back via codex-reply before relaying the next
4. **Propose 2-3 approaches** (GPT proposes, CLAUDE annotates) — present
   GPT's options with trade-offs and GPT's recommendation; append your
   codebase-reality notes, clearly labeled `[Claude, codebase check]`
5. **Present design** (GPT drafts, CLAUDE presents) — section by section,
   scaled to complexity; relay user feedback to GPT for revision; get user
   approval after each section
6. **Write design doc** (CLAUDE scribes) — save GPT's approved design to
   `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` and commit. Add a
   header line: `Ideation: <gpt model> via codex MCP · Facilitation: Claude`
7. **Cross-model spec review** (CLAUDE reviews GPT's spec) — see below
8. **User reviews written spec** — ask user to review before proceeding
9. **Transition to implementation** (CLAUDE-NATIVE from here) — invoke the
   writing-plans skill. The Codex session for ideation ends here; GPT
   re-enters later only as the adversarial reviewer.

## The Ideator Briefing (send as the first codex call)

Compose the first codex prompt as: baseline (below), then the overlay for
the overlay model if one exists, then nothing else. Fill `{project context}`
with a compact summary (never file dumps) and `{idea}` with the user's idea
verbatim.

<!-- gpt-baseline:ideation:begin -->
You are an independent requirements ideator for:

Project context: {project context}
Idea: {idea}

Claude alone facilitates the discussion with the human and verifies approval. Your goal is an approved, implementation-ready design. Success requires the purpose, constraints, measurable success criteria, risky assumptions, selected approach, and every approved design section to be explicit.

During clarification, return exactly ONE decision-focused question and nothing else. Prefer multiple-choice options when practical. Ask only questions whose answers could materially change the design, and never recap settled answers.

Once remaining uncertainty would not materially change the design, stop questioning. Propose 2–3 genuinely distinct approaches, explain their trade-offs, and recommend one. Decompose the work only when the parts are independently useful and implementable.

After Claude relays the selected approach, draft exactly one design section per response, in this order: architecture, components, data flow, error handling, testing. Stop after each section for Claude's verification; revise it until approved before advancing.

Do not implement anything, assume human approval, or act as Claude's substitute.
<!-- gpt-baseline:ideation:end -->

<!-- gpt-overlay:ideation:gpt-5.6-sol:begin -->
The baseline is authoritative; this overlay only tunes communication. Ask the highest-impact unresolved question first. Omit recaps and phase narration. Transition promptly once the answers are sufficient; when the idea already states its behavior, failure handling, and test expectations, skip clarification and go straight to approaches. Keep responses concise while preserving every required design section, boundary, output contract, and stop condition.
<!-- gpt-overlay:ideation:gpt-5.6-sol:end -->

## Facilitation Rules

- **One question at a time.** GPT may batch questions; you relay exactly one
  per message. Queue the rest.
- **Relay faithfully.** Don't paraphrase GPT's questions or the user's
  answers in ways that change their meaning.
- **Codebase-reality checks are your lane.** When a GPT proposal conflicts
  with the actual codebase (pattern mismatch, dependency that isn't there,
  constraint it can't know about), verify with your tools, then send the
  correction back to GPT via codex-reply AND note it to the user. GPT revises;
  you don't overwrite.
- **Scope gate.** If GPT flags decomposition (or you spot it first), help the
  user split into sub-projects, then brainstorm the first one. Each
  sub-project gets its own spec → plan → implementation cycle.
- **Design for isolation and clarity** still applies: units with one clear
  purpose, well-defined interfaces, independently testable. If GPT's design
  has mushy boundaries, push back — via the session, on the record.

## Cross-Model Spec Review (step 7)

This replaces the original skill's self-review, and it's the free win of the
fork: the spec was authored by GPT, so YOU review it with fresh eyes as the
second model.

1. **Placeholder scan** — TBD/TODO/vague requirements? Fix.
2. **Internal consistency** — sections contradict? Architecture matches
   feature descriptions?
3. **Scope check** — single implementation plan, or needs decomposition?
4. **Ambiguity check** — any requirement interpretable two ways? Make it
   explicit.
5. **Codebase fit** — final pass: everything referenced actually exists or
   is planned; patterns match the repo.

Trivial fixes: make them inline and note them. Substantive changes: send back
to GPT via codex-reply for revision — you do not silently rewrite GPT's
requirements at the last step.

## User Review Gate

> "Spec written and committed to `<path>` (ideation by <model>, reviewed
> cross-model). Please review it and let me know if you want changes before
> we write the implementation plan."

Wait. If changes are requested, route substantive ones through GPT, re-run
the review, and ask again.

## Terminal State

Invoke **writing-plans**. Nothing else. Planning, implementation, and testing
are Claude-native. Remind yourself (not the user, unless asked): the
cross-model loop closes after implementation via the codex-adversary
subagent / /adversarial-review per the project's CLAUDE.md policy.

## Key Principles

- One question at a time · multiple choice preferred
- YAGNI ruthlessly
- GPT ideates, Claude verifies — never the reverse in this skill
- All disagreements on the record, clearly attributed
- Incremental validation — approval per section before moving on
