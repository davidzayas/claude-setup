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

## Model Selection

Resolve the GPT model in this order (first match wins):

1. A model named in the user's invocation ("brainstorm X with o3-pro")
2. A `gpt_brainstorm_model:` line in the project's CLAUDE.md
3. The Codex CLI default from ~/.codex/config.toml (pass no model param)

Pass the resolved model via the codex tool's model parameter. State which
model you're using in your first message so the user can correct it. All
codex calls in this skill use sandbox read-only.

## Session Continuity (critical)

The ENTIRE brainstorm is ONE Codex conversation. Make the first call with
`codex`, capture the session/thread, and use `codex-reply` for every
subsequent turn. GPT must remember in phase 5 what the user answered in
phase 3. If the session is lost, summarize the full transcript so far and
re-seed a new session before continuing.

**But keep the session small, because the server hangs silently when one
gets too big.** A session carrying roughly 30KB or more has been observed to
stop responding entirely — no error, no progress, a ~30-minute timeout — and
resending costs another 30 minutes and fails identically. Brainstorming
accumulates slowly (short questions and answers), so the usual causes are
the opening project context and any code excerpts pasted mid-session.

- Send a *summary* of the project context in the opening call, not file
  dumps. Quote only the specific lines a codebase-reality check turns on.
- If the thread does grow large, re-seed proactively using the same
  mechanism above — summarize and start a fresh session — rather than
  waiting for it to hang. Continuity comes from the summary, not from the
  thread id.
- A hang is not the same as GPT being unavailable. If a re-seeded, small
  session still hangs, that is a genuine outage: stop and tell the user, per
  the role contract above.

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

> You are the lead ideator in a requirements brainstorm. A facilitator will
> relay your questions to a human product/engineering leader one at a time
> and return their answers. Your job across this session: (1) ask sharp
> clarifying questions — one per turn, multiple-choice when possible —
> covering purpose, constraints, success criteria, and the assumptions most
> likely to be wrong; (2) when understanding is sufficient, propose 2-3
> distinct approaches with trade-offs and a recommendation; (3) draft the
> design section by section on request: architecture, components, data flow,
> error handling, testing. Apply YAGNI ruthlessly. If the project spans
> multiple independent subsystems, say so immediately and propose a
> decomposition instead of refining details. Project context follows.
> {project context} · The idea, verbatim: {idea}

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
