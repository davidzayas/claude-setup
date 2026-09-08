# gpt-6-astra migration — design

Ideation: gpt-6-astra via codex MCP · Facilitation: Claude

Provenance: Codex thread `01a0831c-5183-7611-a5bc-940ede800c1b`, dispatch
model `gpt-6-astra` (named in the invocation), sandbox read-only. No tuned
ideation overlay existed for `gpt-6-astra` at the time, so the generic
ideation baseline was sent alone and `TODO.md` gained
`- [ ] prompt-variant: role=ideation model=gpt-6-astra` per CLAUDE.md
"GPT model routing". The design sections below are GPT's approved text
verbatim; facilitator notes are marked `[Claude, codebase check]`.

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

## Decision ledger (clarification phase)

| # | GPT question | User answer |
|---|---|---|
| 1 | Acceptance target: behavior-preserving swap, or quality-improvement migration with side-by-side comparison? | **B) Quality-improvement migration** |
| 2 | Improvement required in each role, or overall with ties allowed and no regression? | **B) Overall, none regresses** |
| 3 | Rubric: output quality only, or quality plus latency/cost limits? | **A) Output quality only** |

## Approaches considered

GPT proposed three; the user selected **2**.

1. **Copy forward, then qualify** — add `gpt-6-astra` blocks containing the
   existing overlay text unchanged, then compare both models on identical
   inputs. Smallest change; directly tests whether the model swap alone
   improves quality; may preserve wording that helps the old model but is
   unnecessary or counterproductive for the new one.
2. **Evidence-led overlay tuning (recommended, selected)** — GPT drafts
   conservative, style-only overlays, refines them against separate
   calibration examples, then freezes them before the comparative
   five-case acceptance run. Evaluates the intended deliverable (new model
   together with its role-specific prompts); requires separating
   calibration from acceptance to avoid tuning to the test cases.
3. **Three-arm comparison** — old model/current overlays, new model/copied
   overlays, new model/tuned overlays. Distinguishes model gains from
   overlay gains; adds evaluation and adjudication work beyond what is
   necessary to qualify the migration.

GPT's evidence caveat, confirmed by Claude against the repo: the 2026-08-10
smoke report is context, not a comparison baseline — the review fixture's
comment was corrected after that run, the gpt-5.6-sol reviewer missed the
real `last_n` defect (`n > len(items)` truncates silently), and it filed a
MEDIUM finding whose impact field read "None". Both models must be re-run
fresh.

`[Claude, codebase check]` Calibration inputs do not exist yet: the repo has
exactly two review fixtures (`tests/smoke-fixtures/clean.py`, 527 bytes;
`defect.py`, 568 bytes) and the ideation/second-opinion inputs exist only as
prose in the old report. Full model-blinding is not achievable because
Claude dispatches the calls; the substitute is a written answer key fixed
before any run. Keeping the `gpt-5.6-sol` overlays is safe with the contract
test, which checks only the configured model's overlay.

## Architecture

**Purpose and selected approach.** Use evidence-led, style-only overlay tuning to migrate all three GPT roles to `gpt-6-astra`, demonstrating better overall output quality without regression in any role. This is a prompt/configuration migration, not a pipeline redesign.

**Runtime architecture stays unchanged.** GPT ideates and reviews; Claude facilitates, plans, implements, and verifies human approval. Preserve model-resolution precedence, exact overlay selection, stage boundaries, read-only review, payload budgets, output contracts, and existing failure behavior. Keep Codex CLI `0.149.1`; add no alias or automatic model fallback.

**Maintain two prompt variants.**
- **Control:** `gpt-5.6-sol` with its existing, unchanged overlays.
- **Candidate:** `gpt-6-astra` with new GPT-authored overlays that tune communication only.

Both use the unchanged generic baselines. Retain the control overlays for fresh comparison, explicit overrides, and rollback. Their coexistence is compatible with the configured-model contract check.

**Separate development from qualification.** Create new calibration inputs distinct from the five acceptance cases. Separately, materialize reproducible acceptance inputs—including the currently prose-only scenarios—and independently verify their answer keys before any evaluation runs. Both models must run fresh against identical acceptance inputs, including the corrected review fixtures. Historical outputs are context, not the control measurement.

Freeze candidate overlays, acceptance inputs, answer keys, and scoring rules before comparative qualification. Acceptance results cannot become an unrestricted overlay-tuning loop.

**Use transparent, answer-key-based adjudication.** Claude dispatches calls and therefore knows model identity; do not claim blinding. Fixed written answer keys and evidence-linked judgments constrain discretion, with the human approving acceptance. Qualification requires candidate contract compliance, no role-level quality regression, and demonstrated improvement in at least one role. All-tie or inconclusive results do not qualify; latency and cost are excluded.

**Release as one coordinated change.** Activate the three new defaults together only after qualification and approval. Preserve comparison evidence in `docs/`.

**Risk boundary.** Availability of both deployments is assumed. Five cases provide bounded qualification evidence, not proof of universal superiority.

`[Claude, codebase check]` Materialized ideation/second-opinion inputs live
under `tests/smoke-fixtures/` alongside the two existing `.py` fixtures.

## Components

**1. Role configuration — `CLAUDE.md`.** Change only the three role defaults to `gpt-6-astra` when qualification permits activation. Leave the alias registry empty and routing policy unchanged.

**2. Candidate overlays — the three existing role files.** Add exactly one correctly marked `gpt-6-astra` block per role; preserve existing baselines and `gpt-5.6-sol` blocks verbatim. Use these GPT-authored seeds, subject to evidence-led calibration rather than assumptions about the new model:

- **Ideation — `skills/gpt-brainstorming/SKILL.md`:**
  "The baseline is authoritative; this overlay only tunes communication. Make the highest-impact unresolved decision easy to answer, without recaps or process narration. When clarification is unnecessary, move directly to distinct approaches and concrete trade-offs. Prefer concise, decision-ready prose without omitting required content."
- **Second-opinion — `commands/gpt-brainstorm.md`:**
  "The baseline is authoritative; this overlay only tunes communication. State the position directly and connect each material trade-off to its practical consequence. Make the alternative meaningfully distinct. In rebuttal, express each new material disagreement precisely without repeating earlier analysis."
- **Review — `agents/codex-adversary.md`:**
  "The baseline is authoritative; this overlay only tunes communication. Present each supported finding as a settled, concrete failure sequence with an actionable correction. Consolidate findings sharing a root cause, and keep rejected suspicions out of severity findings. Prefer concise evidence over speculative breadth without omitting required reporting."

These are starting candidates, not validated final wording. Calibration may revise only communication style.

**3. Acceptance assets — `tests/smoke-fixtures/`.**
- Keep the corrected `clean.py` and `defect.py` unchanged.
- Add `acceptance-cases.md` containing exact inputs for all five cases, including both second-opinion phases and a fixed phase-two Claude position. Review prompts identify the corresponding Python fixture.
- Add `acceptance-answer-keys.md` containing case-specific expected behavior, supported findings, prohibited findings, and quality anchors. Explicitly cover the real `last_n` boundary defect and reject an impact-free comment correction as a severity finding.
- Add `comparison-protocol.md` defining composition, settings, repetition, scoring, aggregation, and acceptance rules. Its detailed rules belong in the testing section.

**4. Calibration assets — `tests/smoke-fixtures/calibration/`.** Add separate cases and expected outcomes covering the same role modes but using different concrete tasks and review code—not paraphrases of acceptance inputs. Keep calibration inputs and results identifiable separately from qualification evidence.

**5. Existing contract checker — `tests/prompt-contract-test.sh`.** Retain its structural and byte-cap requirements without weakening them. Validate the final candidate configuration; retaining inactive control overlays requires no checker change. Prompt-quality adjudication remains separate from this structural test.

**6. Evidence record — `docs/`.** Add `prompt-smoke-<actual-run-date>-gpt-6-astra.md`, with companion artifacts as needed for complete outputs. Record both models' fresh runs, fixture/prompt revisions, settings, calibration changes and unsuccessful attempts, qualification judgments, and approval status. Preserve the historical report unchanged. General documentation remains model-agnostic.

**7. `TODO.md` (added at user's direction).** The entry
`- [ ] prompt-variant: role=ideation model=gpt-6-astra` recorded at the start
of this session must be retired (ticked or removed) once the `gpt-6-astra`
ideation overlay exists and passes structural validation; the same applies
to any second-opinion/review entries created by interim dispatches.

`[Claude, codebase check]` The checker's cap is `MAX_FIXED_PROMPT_BYTES=12288`
per role for baseline+overlay; each seed above is roughly 350–400 bytes,
comparable to the current overlays.

## Data flow

**1. Prepare reproducible inputs.** Claude materializes the acceptance cases, independently verifies their answer keys, and fixes the comparison protocol before any evaluation runs. Record the corrected fixture contents and unchanged baseline/control-overlay revisions. Prepare distinct calibration inputs and expected outcomes separately.

**2. Make candidate variants available without changing defaults.** Claude adds all three approved seed overlays before starting candidate dispatches. Check marker integrity and the **12,288-byte baseline-plus-overlay cap per role**, using a non-active candidate-configured copy for the configured-model contract checker.

Once the corresponding overlay exists and passes structural validation, re-read `TODO.md` and tick its outstanding `prompt-variant` entry. This includes the existing ideation entry and any second-opinion/review entries created by interim dispatches. Completion means *the variant exists*, not *the migration has qualified*. Preserve unrelated entries.

**3. Calibrate through explicit candidate routing.** Keep the installed defaults on `gpt-5.6-sol`. For calibration, explicitly select `gpt-6-astra` through the invocation's supported override mechanism. Dispatch that exact deployment name; with no alias, select the identically named overlay.

Compose each request using the existing runtime procedure: unchanged role baseline, selected overlay, and supplied task inputs. Preserve role-specific phase boundaries, read-only constraints, and cumulative session payload budgets. GPT proposes any style revisions; Claude checks their scope and applies them. Record each calibration attempt and revision.

**4. Freeze the qualification candidate.** After calibration, freeze the exact candidate overlay text alongside the previously fixed acceptance inputs, answer keys, and protocol. Structural validation must pass again. Acceptance outputs must not feed further tuning of this same acceptance set; a failed qualification cannot be converted into a pass by repeatedly optimizing against its answers.

**5. Run fresh paired acceptance trials.** Explicitly dispatch both models against the frozen acceptance inputs, using equivalent settings and the same runtime composition rules. Start a fresh session for each model/case/trial. For second-opinion, retain each model's own phase-one thread for phase two and supply the same fixed Claude position to both. Capture complete outputs and execution metadata without substituting historical results.

**6. Adjudicate before activation.** Claude evaluates outputs against the fixed answer keys and scoring rules, records evidence for each judgment, and relays the result for human approval. Do not claim model blinding. The candidate must satisfy every contract gate, regress in no role, and improve in at least one role; ties or inconclusive evidence leave the old defaults active.

**7. Activate and reconcile.** After qualification and human approval, change all three defaults together and verify the actual resulting configuration. Finalize the evidence report and re-read `TODO.md` to retire any remaining entries for the three now-present candidate overlays. Before each controlled candidate dispatch, verify that its overlay exists rather than intentionally exercising baseline-only fallback. This prevents new missing-variant entries from the migration's own runs; final reconciliation catches entries from intervening sessions.

`[Claude, codebase check]` Step 2's "non-active candidate-configured copy":
`tests/prompt-contract-test.sh` derives `REPO` from its own file location and
reads `CLAUDE.md` from there with no override, so the check is realized by
running the script from a scratch copy of the repo whose `CLAUDE.md` names
`gpt-6-astra`. No checker change.

## Error handling

**Configuration or structural failure.** Missing, duplicate, mismatched, or malformed candidate overlay markers—or a baseline-plus-overlay size above **12,288 bytes**—block candidate evaluation. Run the existing checker from a scratch repo copy whose own `CLAUDE.md` selects `gpt-6-astra`; do not modify the checker. A scratch-copy setup failure is a validation failure, not permission to skip the check.

**Missing-overlay behavior.** Preserve the runtime's existing warning, baseline-only fallback, and missing-variant TODO policy. However, a migration evaluation that unexpectedly uses baseline alone is not a valid candidate-overlay trial. Record the configuration failure, stop that evaluation, and restore the intended composition before proceeding. Never borrow the old model's overlay implicitly.

**MCP or deployment failure.** On timeout, authentication failure, unavailable deployment, rejected settings, or unusable MCP transport response, stop and report the failure. Do not substitute Claude, another model, or the CLI leg for the required MCP evaluation. Preserve the failed attempt. Any explicitly authorized retry uses the same frozen configuration and restarts the complete affected case in a fresh session, including both second-opinion phases where applicable.

**Payload-budget failure.** Check the cumulative session budget, including second-opinion continuation context. Do not exceed the 20KB working budget or approach the 30KB hard danger boundary by truncating contracts, fixtures, or required evidence. Stop before dispatch when the budget cannot be respected. Any necessary input/protocol revision must be fixed before a fresh comparison and applied equally to both models.

**Behavioral or quality failure.** A readable response that violates a stage boundary, output contract, or other baseline obligation is a genuine model result—not a transport error eligible for replacement. Preserve and score it without silent repair or selective reruns. Record control failures as well, but never use them to waive candidate requirements. Candidate contract failure, role regression, all ties, or inconclusive improvement blocks activation.

**Compromised qualification evidence.** If an answer key proves incorrect, frozen artifacts change, or acceptance outputs influence further tuning, mark the affected qualification evidence invalid and retain its history. Do not retroactively adjust scoring to secure a pass. Renewed qualification requires an explicitly approved revised protocol; renewed tuning also requires independent held-out inputs for the improvement claim, while retaining the required five smoke scenarios as regression checks.

**TODO and concurrent-edit failures.** Re-read before updating `TODO.md`; retire only entries whose corresponding candidate overlays now exist and pass structural validation. If writing fails, report the unresolved tracking work rather than claiming cleanup succeeded. Preserve unrelated edits. Unresolved required cleanup blocks migration completion, though it does not erase valid comparison evidence.

**Activation failure.** Verify that the live files still match the qualified artifacts before changing defaults. If post-activation validation fails, stop and report the incomplete migration; request explicit approval to restore all three old defaults together. Retained control overlays support that deliberate rollback—not automatic fallback during a failed GPT request.

## Testing

**1. Structural and provenance gates**

Before calibration, and again after the final overlay revision:

- Run `bash tests/prompt-contract-test.sh` from two scratch copies of the candidate repo: one configured with all three `gpt-5.6-sol` defaults, the other with all three `gpt-6-astra` defaults. The checker resolves its root from its own location; no override or checker modification is needed.
- Separately verify exactly one begin/end marker pair, correct ordering, and a nonempty body for each of the six retained/new overlays. The existing checker does not independently establish every closing-marker invariant.
- Require each role's baseline plus selected overlay to remain at or below **12,288 bytes**.
- Verify that generic baselines, old overlays, routing rules, and behavioral safeguards are unchanged.
- Verify exactly one flush-left default line per role, no live alias entries, and no unrelated model-name changes.
- Verify no outstanding `gpt-6-astra` missing-variant entry remains for an existing, structurally valid overlay. Preserve unrelated TODO entries.
- Record content hashes for baselines, overlays, acceptance inputs, answer keys, protocol, and Python fixtures. A source revision alone is insufficient when testing uncommitted changes.

Structural success permits evaluation; it does not establish output quality.

**2. Composition, settings, and repetition**

Use the existing runtime composition rules, without extra coaching or exposing the rubric:

| Role | Initial request | Continuation |
|---|---|---|
| Ideation | Baseline body with context/idea substituted, followed by the selected overlay body | None in these acceptance cases |
| Second-opinion | Baseline's first-response portion with the topic in a labeled, fenced data block, followed by the selected overlay | Send only the rebuttal portion with the fixed Claude position through `codex-reply` |
| Review | Baseline body with intent and full supplied fixture substituted, followed by the selected overlay | None |

Do not send HTML markers, answer keys, calibration transcripts, the other model's output, or Claude's evaluation. Score **raw GPT responses**, before review filtering or second-opinion synthesis.

Use:

- Codex CLI **`0.149.1`**, Azure provider, and the MCP leg.
- Explicit dispatch model `gpt-5.6-sol` or `gpt-6-astra`; no alias.
- Explicit reasoning effort **`high`**, using the verified MCP configuration mechanism.
- `read-only` sandbox and otherwise identical caller-controlled settings. Leave sampling settings unset consistently rather than inventing unsupported controls.
- The same neutral, input-only scratch working directory, not the source repository containing answer keys and reports. Capture relevant nonsecret configuration.
- Fresh sessions for every model/case/repetition. Only second-opinion phase two shares its own phase-one session.

Run **three repetitions per model per case**: **30 sessions and 36 planned MCP calls**, excluding calibration and any separately authorized transport retries.

Execute cases 1–5 within each repetition. Within a pair, run the control first when `case number + repetition number` is even; otherwise run the candidate first. Fix this order before starting. Do not add repetitions to break ties.

Count UTF-8 bytes for composed inputs, outputs, continuations, and any visible tool messages, cumulatively and without double-counting messages. Use **20,000 visible bytes** as the conservative working limit; record that this does not measure hidden provider context. Check before continuations and stop on a measured budget violation. Never use the 30KB danger boundary as an operating target.

**3. Calibration separation**

Create separate calibration examples covering ambiguous ideation, sufficiently specified ideation, two-phase second-opinion, defective review code, and clean review code. Their substantive tasks and code must differ from acceptance—not merely names or constants.

Record each candidate revision and its calibration results. After any revision, rerun the affected role's calibration examples. Before qualification, the final candidate must pass the complete calibration set and structural checks.

Freeze acceptance inputs, answer keys, and scoring rules before any evaluation; freeze candidate overlays after calibration. No acceptance output may guide further tuning under this qualification protocol.

**4. Five acceptance cases and answer keys**

These definitions make the fresh comparison reproducible; they do not claim byte-for-byte reproduction of the historical prompts. Store exact text in `acceptance-cases.md`, with the corresponding oracle in `acceptance-answer-keys.md`.

**Case 1 — Ideation: ambiguous caching feature**

Context:

> A CLI repository scans local project files and fetches remote metadata. It has an installer and a test suite. No performance measurements or freshness requirements have been established.

Idea:

> Add some kind of caching to make the tool faster.

Mandatory behavior:

- Exactly one decision-focused question, with no recap, approaches, design section, implementation, or approval claim.
- Do not invent a known bottleneck or choose a storage mechanism prematurely.

Full-quality anchors:

- The question resolves the intended cache target or the slow operation that motivates caching.
- It is answerable without first deciding several other questions.
- Multiple-choice options, if used, are meaningful alternatives rather than several independently required answers.

Questions about TTL, eviction algorithms, or database selection before identifying the workload receive lower usefulness scores. A single question mark containing several independent decisions does not satisfy the one-question contract.

**Case 2 — Ideation: sufficiently specified version flag**

Context:

> A Bash CLI named repo-tool has an existing argument dispatcher and shell tests. Its installation root is already available to the dispatcher. A VERSION file at that root contains one version line. Other CLI behavior must remain unchanged.

Idea:

> Add repo-tool --version as a sole-argument invocation. Read VERSION at invocation time, print its version line followed by one newline, and exit 0. If VERSION is missing, print a diagnostic to stderr, print nothing to stdout, and exit 1. Add tests for both outcomes and retain existing argument-behavior tests. No network access or cached version value is wanted. Internal organization is an implementation choice, not an unresolved product decision.

Mandatory behavior:

- Proceed directly to **2–3 genuinely distinct, viable approaches**, with trade-offs and a recommendation.
- Do not ask another clarification question, implement the feature, or assume approval.

Full-quality anchors:

- Make the purpose, stated constraints, measurable outcomes, and a relevant risky assumption explicit.
- Keep alternatives proportionate: for example, handling the flag in the dispatcher versus delegating version handling to a dedicated helper, with actual maintenance/testing trade-offs.
- Preserve runtime file reading and missing-file behavior. An embedded build-time version is not a compliant alternative.
- Identify a useful assumption to verify, such as continued packaging of `VERSION`, without treating a settled implementation detail as a new human decision.

The key must accept different sound recommendations; it must not require matching a preferred wording or helper layout.

**Case 3 — Second-opinion: JSON versus SQLite, two phases**

Phase-one topic:

> A local-first CLI stores settings for fewer than 1,000 users, with at most 64 KiB per user. Settings are currently one JSON file per user. Two CLI processes may update different keys for the same user concurrently; completed updates must not silently lose unrelated key changes. Everything runs on one machine using local storage, must work offline, and must not require an always-running service. Cross-user queries and transactions are not currently required. Compare retaining JSON files with migrating to a single SQLite database. Update frequency and the importance of direct human editing are not yet established.

Fixed phase-two Claude position:

> I choose SQLite. Migration tooling is effectively free. At startup, create the database and commit migration_complete=true before importing users. Import each JSON file in a separate transaction; log and skip files that cannot be parsed. Future startups seeing the marker never inspect JSON files again. After the import loop finishes, delete the legacy JSON directory. Existing CLI processes are stopped during migration.

Mandatory phase-one behavior:

- Give one clear recommendation and rationale, material risks, forcing questions, and one serious alternative with conditions under which it wins.
- Do not infer, solicit, or speculate about Claude's position.

The answer key accepts either JSON or SQLite when its recommendation addresses concurrency and crash behavior. JSON requires a credible coordinated read-modify-write strategy; atomic replacement alone does not establish protection against lost updates. SQLite must not be credited as eliminating migration or operational risks automatically.

Mandatory phase-two behavior:

- Use `BLOCKER` or `TRADE-OFF` labels for substantive concerns, with consequences.
- Add material information beyond phase one rather than repeating general migration warnings.
- Across the two phases, address both concrete hazards:
  - A crash after the early completion marker but before all imports leaves an incomplete database that subsequent startups treat as complete.
  - Skipped files followed by deletion of the source directory destroy data that was never successfully migrated.
- Do not invent concurrent legacy writers: the supplied position explicitly stops them.

If phase one already covered both specific hazards, phase two must discuss only genuinely new material, or return exactly `No substantive disagreement.` when nothing new remains. Merely agreeing on SQLite is not grounds to overlook the defective migration procedure.

**Case 4 — Review: corrected defective fixture**

Payload: the complete, unchanged `tests/smoke-fixtures/defect.py`, with its relative path and stable line numbering.

Stated intent:

> read_env reads small, readable local ASCII configuration files containing KEY=VALUE assignments. Blank or whitespace-only lines, trailing newlines, and an empty file are allowed. Whitespace around keys and values is stripped; duplicate keys use the last assignment. Nonblank malformed assignments and filesystem failures are outside this review's input contract. last_n accepts a list and a nonnegative integer and returns up to the last n items: zero returns an empty list, and an oversized n returns all available items. The stated intent governs where comments disagree.

**Oracle decision:** oversized `n` uses saturating behavior, not an exception. This removes ambiguity from the fixture comment without changing the fixture.

Require both primary defects in every candidate repetition:

- **Blank-line parsing:** `MODE=prod\n`, an internal blank line, or an empty file reaches the unpack at line 16 and raises `ValueError`. Consolidate these manifestations into one root cause. A minimal correction skips blank lines before splitting.
- **Oversized tail request:** `last_n([1,2,3], 4)` returns `[3]`, and `last_n([1,2,3], 5)` returns `[2,3]`, instead of `[1,2,3]`. Locate the faulty slice at line 7. A minimal correction must preserve `n == 0`; an unconditional `items[-n:]` is not sufficient.

For each finding, require file/line, failure, trigger sequence, impact/likelihood, and a minimal fix. Require all four severity sections in order and `None found.` in empty sections.

Do not require one exact severity: accept a defensible HIGH/MEDIUM classification for ordinary-input parser failure and MEDIUM/LOW for the bounded wrong-result defect. Unsupported catastrophic impact is not acceptable.

Reject:

- A claim that the existing `n == 0` case returns the whole list—it returns `[]`.
- Style-bait findings about `itertools` or type hints.
- A severity finding whose impact is "None," including a comment-only correction.
- A claimed resource leak based solely on the absence of a `with` statement, without a supported failure sequence.

Primary-defect recall and false findings must be recorded explicitly, not hidden in a total score.

**Case 5 — Review: clean fixture**

Payload: the complete, unchanged `tests/smoke-fixtures/clean.py`, with its relative path and stable line numbering.

Stated intent:

> clamp bounds finite, ordinary numeric values to the supplied interval and rejects low > high with ValueError. chunks accepts lists and integer sizes, yields consecutive chunks including a shorter final chunk, and rejects nonpositive sizes when iterated. Empty lists are valid. NaN, mixed incomparable types, and noninteger sizes are outside the input contract.

Mandatory result:

- No severity findings.
- CRITICAL, HIGH, MEDIUM, LOW sections in that order, each containing `None found.`

Oracle examples include clamping below/inside/above an interval, chunking five items by two, and yielding no chunks for an empty list. Deferred validation inside a generator is not a defect under this contract. Do not reward defensive-programming suggestions outside the stated domain.

**5. Scoring and aggregation**

Claude scores each completed case independently against the frozen key before calculating comparisons. For second-opinion, the two responses form one case.

Use three dimensions, each scored **0–4**:

| Dimension | What it measures |
|---|---|
| Correctness and precision | Supported reasoning, factual accuracy, and absence of invented concerns |
| Material usefulness | Discovery, trade-offs, or defect coverage relevant to the case's decision |
| Actionability and clarity | Answerable questions, concrete consequences, usable recommendations or fixes |

Apply these anchors to each dimension:

- **0:** absent, fundamentally incorrect, or unusable.
- **1:** major errors or omissions defeat the purpose.
- **2:** partially useful, but with a material gap.
- **3:** substantially meets the key, with only minor shortcomings.
- **4:** fully meets the relevant key with precise, directly usable communication.

A longer answer does not earn more points. Additional content earns credit only when relevant and supported. Record a short output-linked justification for every score. Contract results are recorded separately; still score readable control failures rather than discarding them.

Calculate without intermediate rounding:

- **Trial score:** sum of the three dimensions, **0–12**.
- **Case score:** mean of its three trial scores.
- **Role score:** mean of its case scores—cases 1–2 for ideation, case 3 for second-opinion, cases 4–5 for review.
- **Overall score:** mean of the three role scores, giving roles equal weight.

Also retain each case/dimension's three-trial mean to prevent aggregate scores from hiding narrower regressions.

**6. Exact qualification rules**

The candidate qualifies only if **all** conditions hold:

- All structural/provenance checks pass and the complete valid trial set exists.
- Every candidate response satisfies the applicable baseline contracts and mandatory case requirements.
- No candidate dimension score is below **2** in any trial.
- For every case/dimension combination, the candidate's mean is **at least** the control's mean. This conservative guard prevents a role average from hiding a regression in one scenario or quality dimension.
- At least one role improves by **at least 1.0 point on the 0–12 role scale**.
- That improving role also has a positive candidate-minus-control role score in **at least two of the three matched repetitions**.
- The human approves the evidence-backed adjudication through Claude.

These rules imply an overall improvement with no role regression. A smaller gain, all ties, unresolved scoring disagreement, missing evidence, or insufficient repeatability is **inconclusive and does not authorize activation**. A mandatory behavioral failure or measured regression is a **failure**. Neither outcome permits extra tie-breaking runs or selective replacement of readable outputs.

Three repetitions are a bounded operational qualification, not a statistical claim of general model superiority.

**7. Evidence and release verification**

The report and companion artifacts must include:

- Frozen inputs, keys, protocol, prompt hashes, nonsecret settings, and run order.
- Complete raw outputs with model/case/repetition identity, byte counts, and failed-attempt history.
- Calibration revisions and results, kept separate from acceptance.
- Per-response contract judgments, dimension scores with evidence, defect recall/false findings, and all aggregates.
- Explicit `PASS`, `FAIL`, or `INCONCLUSIVE`, with human approval recorded separately.

After an approved pass, verify that the activated defaults and overlays match the qualified artifacts, rerun the checker from the actual repo, and confirm TODO reconciliation. Configuration drift or a failed final check prevents declaring the migration complete.

`[Claude, codebase check]` Verified against the repo: `defect.py` unpacks at
line 16 and slices at line 7; `last_n([1,2,3],4)` → `[3]`, `last_n([1,2,3],5)`
→ `[2,3]`, `n == 0` → `[]`; `clean.py` defines `clamp` and `chunks` with
validation inside the generator. The second-opinion split matches
`commands/gpt-brainstorm.md` steps 2–3 (first call omits everything from
"REBUTTAL PHASE" on; `codex-reply` carries the rebuttal portion). `BLOCKER` /
`TRADE-OFF`, `No substantive disagreement.`, and `None found.` are the
baselines' exact strings. Reasoning effort: `~/.codex/config.toml` already
sets `model_reasoning_effort = "high"`; the MCP tool's `config` parameter can
carry it explicitly per call for provenance. Session count: 5 cases × 2
models × 3 repetitions = 30 sessions; case 3 adds one continuation each,
giving 36 calls.

## Cross-model spec review (Claude, 2026-09-08)

No substantive findings returned to GPT. Placeholder scan: only the
intentional `<actual-run-date>` slot in the report filename. Consistency:
freeze points (inputs/keys/scoring before any run; overlays after
calibration), the qualification rules, and the TODO handling agree across
sections. Scope: one implementation plan in phases (assets → overlays →
calibration → freeze → acceptance → adjudication → activation). Codebase
fit: ticking a `prompt-variant` entry is safe — `check_todo` in
`tests/prompt-contract-test.sh` validates and de-duplicates only `- [ ]`
lines — and the checker passes on the tree containing the ideation entry.
