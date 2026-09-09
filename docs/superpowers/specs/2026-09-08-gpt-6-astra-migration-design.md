# gpt-6-astra migration — design

Ideation: gpt-6-astra via codex MCP · Facilitation: Claude

Provenance: Codex thread `01a0831c-5183-7611-a5bc-940ede800c1b`, dispatch
model `gpt-6-astra` (named in the invocation), sandbox read-only. No tuned
ideation overlay existed for `gpt-6-astra` at the time, so the generic
ideation baseline was sent alone and `TODO.md` gained
`- [ ] prompt-variant: role=ideation model=gpt-6-astra` per CLAUDE.md
"GPT model routing". Design text below is GPT's approved wording;
facilitator notes are marked `[Claude, codebase check]`.

Revision note: GPT's first full draft specified a quality-improvement
qualification (fresh two-model comparison, three repetitions, numerical
rubric, calibration/acceptance separation). After reading it the user
scaled the target down to a behavior-preserving migration; GPT redrafted
the five sections below accordingly. The heavier draft is preserved in git
history (`10cf5f8`).

## Pre-design validation (done before this session)

- An Azure deployment named exactly `gpt-6-astra` exists on
  `ai-foundry-claude-codex` and answers `POST /openai/v1/responses`
  (HTTP 200, `status: completed`), including with `reasoning.effort: high`.
  No `gpt_model_alias:` line is needed.
- CLI leg: `codex exec -s read-only -m gpt-6-astra` on codex 0.149.1
  returned the requested text. Single `codex` binary on PATH.
- MCP leg: `mcp__codex__codex` from Claude Code with `model: gpt-6-astra`,
  `sandbox: read-only` returned the requested text.
- `~/.codex/config.toml` already has `model = "gpt-6-astra"` and
  `model_reasoning_effort = "high"`; the pipeline ignores that default
  because CLAUDE.md's role lines take precedence.

## Decision ledger

| # | GPT question | User answer |
|---|---|---|
| 1 | Acceptance target: behavior-preserving swap, or quality-improvement migration? | B) Quality-improvement — **later revised to a behavior-preserving swap** ("it's just replacing one advanced model with another") |
| 2 | Improvement in each role, or overall with no regression? | B) Overall, none regresses — superseded by the revision |
| 3 | Rubric: quality only, or plus latency/cost? | A) Quality only — superseded by the revision |
| 4 | Approach | 2) Evidence-led overlay tuning — scaled down: keep GPT-authored seeds, drop calibration and comparison |

GPT's evidence caveat, confirmed against the repo: the 2026-08-10 smoke
report is context only — the review fixture's comment was corrected after
that run, the gpt-5.6-sol reviewer missed the real `last_n` defect
(`n > len(items)` truncates silently), and it filed a MEDIUM finding whose
impact field read "None". The new smoke run therefore expects both defects
explicitly (see the appendix).

## Architecture

Reframe this as a behavior-preserving model migration, not a demonstrated quality improvement. Keep the existing pipeline, baselines, routing, budgets, stage boundaries, and failure policy unchanged. Retain `gpt-5.6-sol` overlays for explicit overrides and deliberate rollback. Remove comparative scoring, improvement thresholds, repeated trials, and calibration/acceptance separation. Make no superiority claim.

## Components

Keep the three default changes, three new `gpt-6-astra` overlay blocks, retained old overlays, TODO cleanup, and one dated smoke report. Start with the already-approved GPT-authored overlay seeds; permit small, style-only adjustments based on smoke failures. Reuse the corrected review fixtures. Omit the separate calibration assets, comparison protocol, and formal answer-key files; put exact smoke inputs and brief expected outcomes directly in the report. No checker, alias, CLI-version, or general-documentation changes are needed.

Concretely:

1. **`CLAUDE.md`** — `gpt_brainstorm_model`, `gpt_second_opinion_model`,
   `gpt_review_model` → `gpt-6-astra`, flipped together at activation.
   Alias registry stays empty.
2. **Overlay seeds (GPT-authored), one block per role file**, baselines and
   `gpt-5.6-sol` blocks preserved verbatim:
   - `skills/gpt-brainstorming/SKILL.md`, `<!-- gpt-overlay:ideation:gpt-6-astra:begin/end -->`:
     "The baseline is authoritative; this overlay only tunes communication. Make the highest-impact unresolved decision easy to answer, without recaps or process narration. When clarification is unnecessary, move directly to distinct approaches and concrete trade-offs. Prefer concise, decision-ready prose without omitting required content."
   - `commands/gpt-brainstorm.md`, `<!-- gpt-overlay:second-opinion:gpt-6-astra:begin/end -->`:
     "The baseline is authoritative; this overlay only tunes communication. State the position directly and connect each material trade-off to its practical consequence. Make the alternative meaningfully distinct. In rebuttal, express each new material disagreement precisely without repeating earlier analysis."
   - `agents/codex-adversary.md`, `<!-- gpt-overlay:review:gpt-6-astra:begin/end -->`:
     "The baseline is authoritative; this overlay only tunes communication. Present each supported finding as a settled, concrete failure sequence with an actionable correction. Consolidate findings sharing a root cause, and keep rejected suspicions out of severity findings. Prefer concise evidence over speculative breadth without omitting required reporting."
3. **`tests/smoke-fixtures/clean.py`, `defect.py`** — unchanged.
4. **`docs/prompt-smoke-<run-date>-gpt-6-astra.md`** — the smoke report.
5. **`TODO.md`** — retire `- [ ] prompt-variant: role=ideation model=gpt-6-astra`
   (and any interim second-opinion/review entries) once the corresponding
   overlay exists and passes structural validation.

`[Claude, codebase check]` The checker's cap is `MAX_FIXED_PROMPT_BYTES=12288`
per role for baseline+overlay; each seed is roughly 350–400 bytes, comparable
to the current overlays. Ticking a TODO entry is safe: `check_todo` validates
and de-duplicates only `- [ ]` lines.

## Data flow

Add all three candidate overlays while retaining the old defaults. Retire matching TODO entries once their overlays exist and pass structural validation. Run the checker from a scratch repo copy configured for `gpt-6-astra`, then smoke-test through explicit candidate overrides. Once those checks pass and Claude verifies human approval, switch all three defaults together, rerun the actual-repo checker, finalize the report, and reconcile any interim TODO entries.

`[Claude, codebase check]` `tests/prompt-contract-test.sh` derives `REPO`
from its own location and reads `CLAUDE.md` from there with no override, so
the pre-activation check is a scratch copy of the repo with the three lines
flipped. Smoke dispatches are direct `mcp__codex__codex` calls with
`model: gpt-6-astra`, composed as the runtime composes them (baseline body,
then overlay body, slots filled), exactly as the 2026-08-10 run did.

## Error handling

Structural failures, smoke-contract failures, or MCP failures block the switch. Preserve existing stop-on-MCP-failure behavior; never silently substitute Claude, another model, or the CLI leg. Smoke failures may lead to minimal overlay fixes and reruns of the affected role's cases—no independent holdout set or formal requalification procedure. Record failures and fixes rather than hiding them. Rollback restores all three old defaults deliberately; retained overlays make that possible.

## Testing

Run each of the five cases **once on the final applicable `gpt-6-astra` overlay**: ambiguous ideation, sufficiently specified ideation, two-phase JSON-versus-SQLite second-opinion, corrected seeded-defect review, and clean review. That is five sessions and six MCP calls when no fixes are needed, using CLI `0.149.1`, reasoning effort `high`, and read-only execution. Check the existing behavioral expectations, including both real seeded defects, rejection of the false `n == 0` claim, and no invented clean-fixture findings. Require the contract checker to pass, valid overlay markers, and the **12,288-byte per-role cap**. Record inputs, outputs, settings, prompt revision, pass/fail observations, and any fixes in `docs/prompt-smoke-<run-date>-gpt-6-astra.md`. No fresh old-model runs, numerical rubric, or statistical claims.

Composition per role (unchanged runtime rules; never send HTML markers or
the expected outcomes):

| Role | Initial request | Continuation |
|---|---|---|
| Ideation | Baseline body with context/idea substituted, followed by the overlay body | None |
| Second-opinion | Baseline's first-response portion (everything before "REBUTTAL PHASE") with the topic in a labeled, fenced data block, followed by the overlay | Rebuttal portion with the fixed Claude position, via `codex-reply` on the same thread |
| Review | Baseline body with intent and the full fixture substituted, followed by the overlay | None |

## Appendix — smoke case inputs and expected outcomes

GPT-authored; the implementer copies these into the report as the run's
inputs and checks. They do not claim byte-for-byte reproduction of the
2026-08-10 prompts.

**Case 1 — Ideation: ambiguous caching feature**

Context: "A CLI repository scans local project files and fetches remote metadata. It has an installer and a test suite. No performance measurements or freshness requirements have been established."

Idea: "Add some kind of caching to make the tool faster."

Expected: exactly one decision-focused question, with no recap, approaches, design section, implementation, or approval claim; no invented bottleneck or premature storage choice. A good question resolves the intended cache target or the slow operation that motivates caching and is answerable without first deciding several other questions. Questions about TTL, eviction, or database selection before identifying the workload are weak. One question mark containing several independent decisions does not satisfy the one-question contract.

**Case 2 — Ideation: sufficiently specified version flag**

Context: "A Bash CLI named repo-tool has an existing argument dispatcher and shell tests. Its installation root is already available to the dispatcher. A VERSION file at that root contains one version line. Other CLI behavior must remain unchanged."

Idea: "Add repo-tool --version as a sole-argument invocation. Read VERSION at invocation time, print its version line followed by one newline, and exit 0. If VERSION is missing, print a diagnostic to stderr, print nothing to stdout, and exit 1. Add tests for both outcomes and retain existing argument-behavior tests. No network access or cached version value is wanted. Internal organization is an implementation choice, not an unresolved product decision."

Expected: proceed directly to 2–3 genuinely distinct, viable approaches with trade-offs and a recommendation; no further clarification question, no implementation, no assumed approval. Purpose, stated constraints, measurable outcomes, and a relevant risky assumption (e.g. continued packaging of `VERSION`) made explicit. Alternatives proportionate (e.g. flag handled in the dispatcher vs a dedicated helper). Runtime file reading and missing-file behavior preserved — an embedded build-time version is not compliant. Different sound recommendations are acceptable.

**Case 3 — Second-opinion: JSON versus SQLite, two phases**

Phase-one topic: "A local-first CLI stores settings for fewer than 1,000 users, with at most 64 KiB per user. Settings are currently one JSON file per user. Two CLI processes may update different keys for the same user concurrently; completed updates must not silently lose unrelated key changes. Everything runs on one machine using local storage, must work offline, and must not require an always-running service. Cross-user queries and transactions are not currently required. Compare retaining JSON files with migrating to a single SQLite database. Update frequency and the importance of direct human editing are not yet established."

Fixed phase-two Claude position: "I choose SQLite. Migration tooling is effectively free. At startup, create the database and commit migration_complete=true before importing users. Import each JSON file in a separate transaction; log and skip files that cannot be parsed. Future startups seeing the marker never inspect JSON files again. After the import loop finishes, delete the legacy JSON directory. Existing CLI processes are stopped during migration."

Expected, phase one: one clear recommendation and rationale, material risks, forcing questions, one serious alternative with the conditions under which it wins; no inferring or soliciting Claude's position. Either JSON or SQLite is acceptable if the recommendation addresses concurrency and crash behavior (JSON needs a credible coordinated read-modify-write strategy — atomic replacement alone is not enough; SQLite must not be credited as eliminating migration risk automatically).

Expected, phase two: `BLOCKER` / `TRADE-OFF` labels with consequences; material information beyond phase one, not generic migration warnings. Across the two phases, both hazards in the position must surface: (a) a crash after the early completion marker but before all imports leaves an incomplete database that later startups treat as complete; (b) skipped unparseable files followed by deletion of the source directory destroy never-migrated data. Must not invent concurrent legacy writers (the position stops them). If nothing new remains, exactly `No substantive disagreement.`

**Case 4 — Review: corrected defective fixture**

Payload: the complete, unchanged `tests/smoke-fixtures/defect.py`, with its relative path and stable line numbering.

Stated intent: "read_env reads small, readable local ASCII configuration files containing KEY=VALUE assignments. Blank or whitespace-only lines, trailing newlines, and an empty file are allowed. Whitespace around keys and values is stripped; duplicate keys use the last assignment. Nonblank malformed assignments and filesystem failures are outside this review's input contract. last_n accepts a list and a nonnegative integer and returns up to the last n items: zero returns an empty list, and an oversized n returns all available items. The stated intent governs where comments disagree."

Expected — both defects found:
- Blank-line parsing: `MODE=prod\n`, an internal blank line, or an empty file reaches the unpack at line 16 and raises `ValueError`; one consolidated root cause; minimal fix skips blank lines before splitting.
- Oversized tail request: `last_n([1,2,3], 4)` returns `[3]` and `last_n([1,2,3], 5)` returns `[2,3]` instead of `[1,2,3]`; faulty slice at line 7; minimal fix must preserve `n == 0` (an unconditional `items[-n:]` is not sufficient).

Each finding carries file:line, the failure, trigger sequence, impact/likelihood, and a minimal fix. All four severity sections in order, `None found.` where empty. Severity is not fixed: HIGH or MEDIUM is defensible for the parser failure, MEDIUM or LOW for the bounded wrong-result defect; unsupported catastrophic impact is not.

Rejected as findings: a claim that `n == 0` returns the whole list (it returns `[]`); style bait about `itertools` or type hints; any finding whose impact is "None", including a comment-only correction; a resource-leak claim based solely on the missing `with` statement without a supported failure sequence.

**Case 5 — Review: clean fixture**

Payload: the complete, unchanged `tests/smoke-fixtures/clean.py`, with its relative path and stable line numbering.

Stated intent: "clamp bounds finite, ordinary numeric values to the supplied interval and rejects low > high with ValueError. chunks accepts lists and integer sizes, yields consecutive chunks including a shorter final chunk, and rejects nonpositive sizes when iterated. Empty lists are valid. NaN, mixed incomparable types, and noninteger sizes are outside the input contract."

Expected: no severity findings; CRITICAL, HIGH, MEDIUM, LOW in that order, each `None found.` Deferred validation inside the generator is not a defect. Defensive-programming suggestions outside the stated domain earn nothing.

`[Claude, codebase check]` Verified against the repo: `defect.py` unpacks at
line 16 and slices at line 7; `last_n([1,2,3],4)` → `[3]`, `last_n([1,2,3],5)`
→ `[2,3]`, `n == 0` → `[]`; `clean.py` defines `clamp` and `chunks` with
validation inside the generator. `BLOCKER` / `TRADE-OFF`,
`No substantive disagreement.`, and `None found.` are the baselines' exact
strings. The second-opinion split matches `commands/gpt-brainstorm.md`
steps 2–3.

## Cross-model spec review (Claude, 2026-09-08, after the scale-down)

No substantive findings returned to GPT. Placeholders: only the intentional
`<run-date>` slot. Consistency: the revised sections all describe the same
sequence (overlays in → TODO retired → scratch-copy checker → five smoke
cases via explicit override → approval → flip defaults → real-repo checker →
report). Scope: one implementation plan. Codebase fit: confirmed as noted
inline; the contract test passes on the committed tree containing the
ideation TODO entry.
