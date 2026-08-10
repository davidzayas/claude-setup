# Prompt Updates: Per-Model GPT Prompt Variants and Cross-Model Prompt Hardening

Ideation: gpt-5.6-sol via codex MCP · Facilitation: Claude

## Problem and goals

The five managed prompt files (`CLAUDE.md`, `skills/gpt-brainstorming/SKILL.md`,
`agents/codex-adversary.md`, `commands/adversarial-review.md`,
`commands/gpt-brainstorm.md`) drive a three-stage two-model pipeline. They work,
but the prompts should be hardened proactively for ambiguity, redundancy, and
drift, and the efficiency/reliability lessons already paid for (the ~30KB codex
MCP payload hang) should be operationalized rather than left as prose warnings.

Decisions from the brainstorm (human-confirmed):

- **Primary tie-breaker:** reliable role compliance — preserve model
  independence, stage boundaries, and stop-on-failure behavior first; optimize
  tokens/latency second.
- **Motivation:** proactive hardening + efficiency/reliability. No known role
  failures beyond the documented payload hangs.
- **Payload budget:** target **≤20KB working budget** per codex session; treat
  **30KB as a hard danger boundary**. Split/re-seed proactively.
- **Change scope:** behavior-preserving hardening. Commands, three-stage flow,
  report shapes, and human approval gates stay stable.
- **Prompt targeting:** **per-model prompt variants**. `gpt-5.6-sol` gets
  prompts tuned for it per GPT role. Unknown models get a warning, the generic
  baseline, and a repo TODO recording the missing variant.
- **Fallback on missing variant:** warn + generic baseline (never stop, never
  ask each time).
- **Model config:** per-role defaults — separate settings for full ideation,
  lightweight brainstorming, and adversarial review, each overridable at
  invocation.
- **Variant shape:** baseline + small model overlay. The shared role contract
  and output schema stay authoritative; overlays add only proven tuning
  directives.
- **Validation bar:** static checks plus a small live smoke matrix against
  `gpt-5.6-sol`, documented. No eval framework.

Division of labor for implementation, per the human's request: GPT (via codex)
is the authority informing the GPT-facing prompt segments; Claude (Fable)
analyzes and proposes changes to the Claude-facing scaffolding.

## 1. Architecture

Approach chosen: **role-local prompt packs** (over a central registry or
template generation — both rejected as adding failure modes or tooling
disproportionate to one tuned model and three roles).

The five installed Markdown files remain self-contained and keep their current
responsibilities:

- **`CLAUDE.md` is the control plane.** It defines the three-stage policy,
  shared invariants, and three per-role defaults:
  - `gpt_brainstorm_model` — full requirements/design sessions (retained for
    compatibility)
  - `gpt_second_opinion_model` — lightweight `/gpt-brainstorm`
  - `gpt_review_model` — adversarial code review

  All initially default to `gpt-5.6-sol`.

- `skills/gpt-brainstorming/SKILL.md` owns the generic ideation baseline and
  its model overlays.
- `commands/gpt-brainstorm.md` owns the generic independent-second-opinion
  baseline and overlays.
- `agents/codex-adversary.md` owns the generic adversarial-review baseline and
  overlays.
- `commands/adversarial-review.md` remains a thin entry point: it gathers
  intent and target information, forwards an optional model override, and
  delegates. It does not duplicate review prompts or variant logic.

Each GPT-dispatching role implements the same short **routing contract**:

1. Resolve the model from an explicit invocation override, then its per-role
   default, then the Codex default if configuration is absent.
2. Select an **exact** model overlay; do not guess based on a similar model
   name.
3. Compose the authoritative generic baseline with that small overlay.
4. If no overlay exists, warn before dispatch, use the generic baseline, and
   emit a deduplicated repository TODO for the missing variant.
5. Keep the working session at or below 20KB and treat 30KB as a hard danger
   boundary. Split review work into independent sessions; re-seed long
   brainstorming threads with a compact continuity summary.
6. Use Codex read-only. If the MCP service is unavailable, stop. Never
   substitute Claude or retry an unchanged timed-out payload.

**Overlay constraint:** overlays may tune GPT-specific communication behavior —
brevity, response structure, initiative, or instruction interpretation — but
may not weaken the baseline's role boundary, output contract, safety rules,
payload budgets, or stop conditions. Model tuning stays subordinate to
reliable role compliance.

Missing-variant TODOs are repository-local (this repo's root `TODO.md`), not
part of the installed prompt payload — one normalized entry per role/model
pair.

*[Claude, codebase check — accepted into the design]:* install.sh symlinks the
five files from this repo into `~/.claude`, so overlays deploy with zero
installer/manifest change, and the claude-setup repo is reachable from any
project by resolving the symlink target of `~/.claude/CLAUDE.md`.

## 2. Components

### `CLAUDE.md`

Expand the global policy without embedding GPT prompts:

- Retain `gpt_brainstorm_model`; add `gpt_second_opinion_model` and
  `gpt_review_model`. Initially set all three to `gpt-5.6-sol`.
- Define the shared routing priorities and generic-fallback rule.
- State that an overlay cannot override stage boundaries, read-only review,
  payload limits, or stop-on-MCP-failure behavior.
- Pin missing-variant tracking to the source `claude-setup/TODO.md`, never the
  active project.

### `skills/gpt-brainstorming/SKILL.md`

Rewrite the embedded Ideator Briefing into a compact outcome-first contract:

- **Role:** independent requirements ideator; Claude facilitates and verifies.
- **Goal:** produce an approved, implementation-ready design.
- **Success criteria:** purpose, constraints, success measures, risky
  assumptions, selected approach, and approved design sections are explicit.
- **Turn contract:** during clarification, return exactly one decision-focused
  question and nothing else. Do not recap settled answers.
- **Phase transition:** stop questioning once remaining uncertainty would not
  materially change the design; then propose 2–3 genuinely distinct
  approaches.
- **Scope rule:** request decomposition only for independently useful or
  independently implementable subsystems.
- **Output contract:** architecture, components, data flow, error handling,
  and testing are drafted one section at a time.
- **Stop rules:** no implementation, no Claude substitution, and proactive
  re-seeding before the session exceeds its working budget.

This removes repeated exhortations while preserving the hard role contract and
approval gates.

### `commands/gpt-brainstorm.md`

Retain the independent-analysis protocol; give GPT explicit phase-specific
outputs.

First call:

- One recommendation with rationale.
- Top **material** risks, not a generic risk inventory.
- Forcing questions whose answers could change the recommendation.
- One serious alternative and when it would win.
- No knowledge of Claude's private position.

Follow-up call:

- Attack Claude's disclosed position.
- Report only substantive disagreements, missing evidence, optimistic
  assumptions, and concrete failure scenarios.
- Distinguish blockers from ordinary trade-offs.
- Do not repeat points already made or manufacture disagreement.

Add optional `--model <exact-id>` parsing while preserving the existing
topic/path argument behavior.

### `agents/codex-adversary.md`

Replace "hostile" with **adversarial and evidence-bound**. The baseline keeps
the existing target areas but raises the finding threshold:

- A finding must identify a plausible failure supported by the supplied code.
- Every finding retains severity, `file:line`, concrete event sequence, and
  minimal fix.
- Severity reflects impact and likelihood, not rhetorical emphasis.
- Style preferences, diff restatements, unsupported speculation, and duplicate
  root causes are excluded.
- Required severity headings remain present, including explicit "none found."
- The reviewer stops after covering the supplied scope; it does not request
  unrelated files merely to broaden the review.

The Sonnet subagent remains read-only and continues quality-gating GPT's
response. Model selection and overlay choice remain simple, explicit blocks
within this file.

### `commands/adversarial-review.md`

Keep this wrapper thin but make it the **side-effect owner**:

- Parse optional `--model <exact-id>` separately from the review target.
- Resolve the review model before delegation.
- Warn and record the TODO when the model lacks an overlay.
- Pass the resolved model and selected variant status to the subagent.
- Preserve intent drafting, adjudication rules, report shape, and the one-loop
  maximum.

This keeps `codex-adversary` read-only while allowing the main Claude workflow
to update `TODO.md`.

### `gpt-5.6-sol` overlays

Each overlay is a short delta, not a second prompt:

- **Ideation:** ask the highest-impact unresolved question first; omit recaps
  and phase narration; transition promptly once answers are sufficient;
  preserve every required design section despite concise output.
- **Second opinion:** commit to a position before seeing Claude's; keep the
  alternative genuinely distinct; on rebuttal, return only new material
  disagreements and their consequences.
- **Review:** favor fewer evidence-backed findings over speculative coverage;
  preserve concrete failure sequences and required severity reporting despite
  compressed prose; consolidate findings with the same root cause.

Overlays do not change reasoning effort, permissions, tools, schemas, or
safety rules. **They are initial tuning hypotheses and must pass the
`gpt-5.6-sol` smoke matrix** (GPT noted it could not reach OpenAI's live
prompting guidance from the read-only session; the deltas are based on bundled
guidance and are explicitly eval-gated).

### Root `TODO.md`

A repository-local, non-installed backlog file. Normalized entry:

```text
- [ ] prompt-variant: role=<ideation|second-opinion|review> model=<exact-model-id>
```

At runtime:

1. Resolve the canonical target of `~/.claude/CLAUDE.md`.
2. Verify its parent contains the expected `claude-setup` prompt paths.
3. Append the normalized entry only if that role/model pair is absent.
4. If symlink resolution fails, the current repo may be used only after
   verifying it is claude-setup itself (`managed-files.sh` and all five
   managed prompt paths present) — this covers running inside a fresh clone
   before `install.sh` has run.
5. If resolution and the current-repo check both fail, warn and return the
   exact entry for manual recording. Never write a TODO into any other
   project as a fallback.

## 3. Data flow

### Shared routing

Every GPT call follows the same sequence:

1. Parse an explicit model override, otherwise read the role's default from
   `CLAUDE.md`; use the Codex default only when neither is available.
2. Match the exact model identifier to a role-local overlay.
3. If unmatched, warn, select the generic baseline, and record the normalized
   role/model entry in `claude-setup/TODO.md`.
4. Assemble baseline + overlay + minimum task context.
5. Measure the outgoing payload and current session total.
6. Dispatch read-only to Codex, preserving the role's existing continuation
   rules.

### Full ideation

```text
User request
  → Claude selects gpt-brainstorming
  → resolve model and prompt variant
  → send project summary + idea + baseline + overlay
  → GPT returns one question
  → Claude performs codebase check and relays it
  → user answers
  → Claude sends answer through codex-reply
  → repeat until approaches and design are approved
  → Claude writes and cross-reviews the specification
```

Claude maintains a compact **decision ledger** (decisions, constraints, open
questions, approved sections). Before the session approaches 20KB, it starts a
fresh Codex thread seeded with that ledger rather than the full transcript.

### Lightweight brainstorm

```text
Topic/path + optional model
  → Claude privately drafts its position
  → GPT receives only the raw input and commits to an independent position
  → Claude sends its private position through codex-reply
  → GPT returns material attacks and disagreements
  → Claude synthesizes both positions
```

The first GPT response must remain unanchored. The follow-up uses the same
small session so GPT can compare positions directly.

### Adversarial review

```text
Target + optional model
  → main Claude resolves model, variant, and TODO side effects
  → main Claude writes the intent paragraph
  → codex-adversary assembles and measures focused review payloads
  → GPT reviews each independent scope
  → Sonnet verifies and deduplicates findings
  → main Claude adjudicates every surviving finding
  → optional single re-review after fixes
```

Payloads over the working budget are split by module, file, or concern into
separate Codex sessions. Each receives its own intent and enough local context
to stand alone. The final report names the scopes reviewed and any
cross-cutting behavior no single session could evaluate.

## 4. Error handling

- **Unknown model variant:** warn without blocking, use the generic baseline,
  and add the exact role/model pair to the source repo's `TODO.md`.
- **Missing role default:** warn and use the Codex default with the generic
  baseline. If the exact effective model cannot be determined, do not invent a
  model-specific TODO.
- **Invalid `--model`:** reject an empty or duplicate option and show the
  accepted syntax; do not guess which value was intended.
- **Source-repo resolution failure:** never write into the current project.
  Return the exact normalized TODO entry for manual recording.
- **Duplicate TODO:** perform an exact role/model check before adding. Do not
  create another entry or rewrite unrelated backlog content.
- **Unwritable `TODO.md`:** continue with the generic prompt after warning;
  report that persistent tracking failed.
- **Payload above 20KB:** do not dispatch as assembled. Compact/re-seed
  brainstorming or split review work.
- **Payload at or above 30KB:** treat it as unsendable.
- **Timeout:** never resend the same payload unchanged. A long brainstorm may
  re-seed once with a smaller decision ledger; a review may split into smaller
  independent scopes. If an already-small request still times out, report an
  MCP outage and stop.
- **MCP authentication, availability, or credit failure:** stop the
  GPT-dependent stage. Never substitute Claude.
- **Malformed GPT response:** make at most one bounded repair request if it
  remains within budget. An incomplete review must be reported as incomplete,
  never converted into a clean verdict.
- **Unsplittable cross-cutting review:** review the safe scopes, identify the
  uncovered interaction explicitly, and do not claim whole-change coverage.
- **Overlay/default drift:** use the baseline and surface the missing pair;
  static tests should normally catch this before runtime.

## 5. Testing

### Static contract checks

Add a small, dependency-free `tests/prompt-contract-test.sh` (alongside the
existing `tests/uninstall-test.sh`), not a general eval framework. It verifies:

- All three model defaults exist exactly once in `CLAUDE.md`.
- Each configured default has an exact overlay in its corresponding GPT-facing
  file.
- Every GPT role contains a generic baseline.
- Overlays remain small deltas rather than duplicated full prompts (enforced
  via the byte allowance below).
- The 20KB working budget, 30KB danger boundary, read-only rule,
  stop-on-MCP-failure rule, and unchanged-timeout prohibition remain present
  where required.
- The adversarial report headings and one-loop limit remain unchanged.
- Both slash commands document and parse the additive `--model <exact-id>`
  form.
- `TODO.md` entries match the normalized schema and contain no duplicate
  role/model pairs.
- `TODO.md` is not added to `managed-files.sh`.
- Each composed baseline-plus-overlay prompt (measured per role/model
  composition, not in aggregate) stays below `MAX_FIXED_PROMPT_BYTES=12288`,
  defined at the top of `tests/prompt-contract-test.sh`. This leaves roughly
  8KB per session for task context and accumulated turns within the 20KB
  working budget.

Run the existing installer/uninstaller regression suite as well, confirming
the five-file symlink manifest and install behavior remain unchanged.

### Live `gpt-5.6-sol` smoke matrix

A small manual matrix against the actual model:

| Role | Scenario | Required evidence |
|---|---|---|
| Ideation | Ambiguous, single-system feature | Exactly one high-impact question; no recap or premature design |
| Ideation | Nearly complete requirements | Prompt transition to 2–3 distinct approaches without needless questioning |
| Second opinion | Raw proposal followed by a materially different Claude position | Independent initial recommendation; follow-up identifies concrete disagreements without repetition |
| Review | Small fixture containing one real boundary/error-path defect plus style distractions | Finds the defect with severity, line, event sequence, and minimal fix; ignores style bait |
| Review | Small clean fixture | No invented defects; explicit empty severity levels and clean coverage statement |

For every scenario, record: model and role; prompt revision or commit; input
and output byte counts; pass/fail for each required contract; unexpected
verbosity, omissions, role drift, or false positives; and the smallest prompt
adjustment justified by a failure.

Store a compact result document at `docs/prompt-smoke-<YYYY-MM-DD>-<model>.md`
(one file per smoke run); do not commit full transcripts
or build scoring infrastructure. If a case fails, make one surgical prompt
change and rerun that same case before broadening the overlay.

## Implementation division of labor

Per the human's direction and the cross-model policy:

- **GPT-facing prompt segments** (ideation baseline + overlay, second-opinion
  baseline + overlay, adversarial-review baseline + overlay): drafted/informed
  by GPT via codex; validated by the smoke matrix.
- **Claude-facing scaffolding** (facilitation protocol, routing contract
  wording, side-effect handling, adjudication rules, CLAUDE.md policy text):
  analyzed and proposed by Claude (Fable), reviewed cross-model per policy.
- Implementation itself is Claude-native (stage 2), with the codex-adversary
  review closing the loop (stage 3).
