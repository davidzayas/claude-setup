# Ideation rubric: two post-campaign Evaluation Terms — design

Ideation: gpt-6-astra via codex MCP · Facilitation: Claude

Provenance: Codex thread `01a086e1-b2f6-70b0-874a-351765b0d383`, dispatch
model `gpt-6-astra` (CLAUDE.md default; no alias), tuned ideation overlay
present (revision 1, 823 bytes). The idea was fully specified, so GPT went
straight to approaches — the behaviour the 2026-09-09 smoke campaign
validated. Design text is GPT's approved wording; facilitator notes are
marked `[Claude, codebase check]`.

Closes TODO.md items "rubric: implicit stop-for-verification" and "rubric:
components/error-handling boundary" to the extent possible without a fixture
freeze: the wording is recorded now; incorporation into the hash-frozen
fixture is deferred to the next campaign.

## Decision ledger

| # | Step | Decision |
|---|---|---|
| 1 | Approach | **1) Source-spec clarification now; fixture incorporation at the next freeze** (GPT's recommendation) |
| 2 | Architecture, Components | approved as drafted |
| 3 | Data flow, Error handling, Testing | approved together (docs-only change); `rg` in GPT's test commands transcribed as `grep -E` to keep the repo dependency-free |

## Purpose, constraints, criteria, assumptions (GPT)

**Purpose:** Make the two previously implicit judging rules explicit without changing campaign 2's frozen evidence or accepted verdicts.

**Constraints:** Preserve the entire cases fixture—including its revision note—and the campaign report unchanged. No smoke run, campaign scheduling, prompt changes, or unrelated backlog fixes.

**Measurable success criteria:**
- Both terms have exact, approved wording recorded now.
- The fixture retains campaign 2's recorded SHA-256, `6c961f502021418017738d78b79867c37f381087138f8826c1dfca4e92965502`.
- Documentation distinguishes retrospective rationale from rules incorporated into a future frozen fixture.
- A tracked next-freeze task specifies copying both terms into the fixture, updating its revision note, and recording its new identity in that campaign's report—not replacing campaign 2's hash.

**Risky assumptions:** These are clarifications of prior adjudication, not grounds for regrading historical responses. State ownership includes temporary-state lifetime but does not license a data-flow walkthrough. The boundary must preserve the existing allowance for references needed to explain the current section; merely mentioning failure must not automatically constitute developing error handling.

**Approaches**

1. **Source-spec clarification now; fixture incorporation at the next freeze — recommended.** Add a clearly labeled prospective subsection beside the existing Evaluation Terms in `docs/superpowers/specs/2026-09-09-ideation-smoke-breadth-design.md`. Preserve the original five definitions; record the two exact additions and their adjudication provenance separately, explicitly excluding them from the historical frozen rubric. Update the two rubric TODOs to distinguish completed documentation from pending fixture incorporation. **Trade-off:** Keeps wording beside its authoritative source without adding another document, but requires unmistakable historical-versus-prospective labeling.
2. **Standalone clarification addendum now; synchronize both locations at the next freeze.** Leave the source spec, fixture, and report untouched. Record the exact terms and provenance in a new rubric addendum, with the rubric TODOs pointing to it. At the next freeze, incorporate the terms into both the source spec and fixture. **Trade-off:** Preserves the historical spec intact, but introduces a temporary second authority and an additional synchronization obligation.

`[Claude, codebase check]` The spec's `### Evaluation Terms` heading is at
line 306 of the 2026-09-09 smoke-breadth spec. Nothing the contract checker
reads is affected by either approach. The deferral pattern matches the
existing "fixture row" TODO item.

## Architecture

Use the selected **source-spec clarification now; fixture incorporation at the next freeze** approach, separating prospective rubric guidance from frozen campaign evidence.

- **Source of truth:** Under `docs/superpowers/specs/2026-09-09-ideation-smoke-breadth-design.md:306`, retain the five existing Evaluation Terms verbatim and add a subordinate **"Post-campaign clarifications — pending next fixture freeze"** subsection. It holds the two exact terms and their adjudication provenance, explicitly labeled as prospective additions—not part of either campaign's frozen rubric or a retrospective change to its verdicts.
- **Frozen evidence:** Leave the entire cases fixture, including its revision note, and the campaign report unchanged. The spec and fixture intentionally differ until a future freeze.
- **Deferred obligation:** Update the two rubric items in `TODO.md` to record that wording is documented while fixture incorporation remains pending. Keep those obligations open; this change neither schedules nor requires another campaign.

## Components

**New spec subsection**, beneath the existing five Evaluation Terms:

```markdown
#### Post-campaign clarifications — pending next fixture freeze

These clarifications are prospective additions for the next fixture freeze; they are not part of either 2026-09-09 campaign's frozen rubric and do not revise either campaign's verdicts.

- **Implicit stop-for-verification:** A response that ends after developing only the current section, without advancing to a later section or claiming approval, satisfies "stops for verification" even without an explicit request for verification.

  Provenance: `docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md` — campaign 2 checkpoints L2-COMP-R, L2-FLOW, and H3 accepted implicit stops; campaign 1 H3 also accepted the absence of an explicit verification request.

- **Components/error-handling boundary:** Interface payloads and state ownership, including temporary-state lifetime, are components content; failure outcomes and adapter failure guarantees are error-handling content. References needed to explain the current section are allowed; separately developing a later section is not.

  Provenance: `docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md` — campaign 1 H3 distinguished failure guarantees from components content; campaign 2 H3 accepted interface payloads and state lifetime as components content. Both required review adjudication.
```

**Exact replacements for the two `TODO.md` rubric items:**

```markdown
- [ ] rubric: implicit stop-for-verification wording documented in docs/superpowers/specs/2026-09-09-ideation-smoke-breadth-design.md under "Post-campaign clarifications — pending next fixture freeze"; incorporate the term into tests/smoke-fixtures/ideation-gpt-6-astra-cases.md at the next campaign's freeze; the fixture remains hash-frozen for campaign 2
- [ ] rubric: components/error-handling boundary wording documented in docs/superpowers/specs/2026-09-09-ideation-smoke-breadth-design.md under "Post-campaign clarifications — pending next fixture freeze"; incorporate the term into tests/smoke-fixtures/ideation-gpt-6-astra-cases.md at the next campaign's freeze; the fixture remains hash-frozen for campaign 2
```

`[Claude, codebase check]` Provenance claims match the campaign report:
campaign-2 L2-COMP-R, L2-FLOW and H3 were judged as behavioural stops;
round-1 H3's FAIL rested on adapter-failure content, not on the absent
verification request; campaign-2 H3's PASS rested on the interface/state-
lifetime reading. `rubric:` lines are not validated by the contract checker.

## Data flow

1. **Capture the baseline.** Record the starting worktree status and run `shasum -a 256 tests/smoke-fixtures/ideation-gpt-6-astra-cases.md`. Require campaign 2's recorded value: `6c961f502021418017738d78b79867c37f381087138f8826c1dfca4e92965502`.
2. **Edit the spec.** Insert the approved subsection immediately after the five existing Evaluation Terms, leaving those definitions unchanged.
3. **Update the backlog.** Replace only the two rubric entries in `TODO.md` with the approved text. Both remain unchecked because fixture incorporation is deferred.
4. **Verify the task diff.** Check the edits against the approved text and confirm this work changes only the spec and those two TODO entries. Recompute the fixture SHA-256 and require the same recorded value; confirm no task changes to the fixture or campaign report, including the fixture's revision note.
5. **Commit the scoped changes.** Once implementation is authorized and verification passes, stage only this task's changes, inspect the staged diff, and commit. Exclude any pre-existing unrelated changes; neither a smoke run nor a future campaign freeze occurs in this flow.

## Error handling

- **Fixture hash differs at baseline:** Stop before editing and report the observed and recorded hashes to Claude. Do not restore the fixture, replace the report's hash, or silently adopt a different baseline.
- **Existing Evaluation Terms have drifted:** Compare the original five definitions, excluding the proposed prospective subsection. If the spec and fixture already differ, pause and show Claude the differences for an explicit disposition. Do not synchronize them automatically or modify frozen evidence.
- **TODO entries changed concurrently:** Re-read the two entries immediately before replacement. If either differs from the reviewed version, preserve the concurrent edits and ask Claude to resolve the overlap; do not overwrite them or mark the deferred work complete.
- **Contract checker fails after the TODO edit:** Capture the failure and determine whether it is task-introduced or pre-existing. Do not assume the fixture is implicated—the checker does not read it. Correct only task-introduced mistakes; changes to approved wording require renewed approval. Report unrelated failures without expanding scope or weakening the checker. Withhold the commit until the failure is resolved or proceeding is explicitly authorized through Claude, and never report a failing check as passed.

## Testing

These are verification steps for implementation, not checks already performed.

Before editing, capture comparison copies:

```bash
spec=docs/superpowers/specs/2026-09-09-ideation-smoke-breadth-design.md
fixture=tests/smoke-fixtures/ideation-gpt-6-astra-cases.md
before=$(mktemp -d)
cp "$spec" "$before/spec.md"
cp TODO.md "$before/TODO.md"
```

After editing:

- **Frozen fixture:** `shasum -a 256 "$fixture"` must return `6c961f502021418017738d78b79867c37f381087138f8826c1dfca4e92965502`.
- **Original five bullets:** Run the following comparison; expect exit `0` and no output:
  ```bash
  original_terms() {
    sed -n '/^### Evaluation Terms$/,$p' "$1" | grep -E -m 5 '^- \*\*'
  }
  cmp <(original_terms "$before/spec.md") <(original_terms "$spec")
  ```
- **New subsection:** `grep -En '^#### Post-campaign clarifications — pending next fixture freeze$|^- \*\*(Implicit stop-for-verification|Components/error-handling boundary):\*\*' "$spec"` must return exactly three lines: one heading and one bullet for each term. `diff -u "$before/spec.md" "$spec"` must show only the approved subsection insertion, including its preamble and both provenance lines.
- **TODO replacements:** `diff -U3 "$before/TODO.md" TODO.md` must show exactly two removed rubric lines and their two approved replacements, with unchanged surrounding lines and no other edits. Both entries remain unchecked. These two `diff` commands intentionally return `1` because approved differences exist.
- **Contract:** `bash tests/prompt-contract-test.sh` must exit `0`.
- **Scope:** `git diff --stat` must list only the spec and `TODO.md`. Inspect the staged diff before committing to confirm the same scope; unrelated pre-existing changes must not enter this commit.

**Acceptance statement, once these checks pass:** The two approved clarifications and their provenance are documented prospectively; the original five definitions and campaign 2's frozen fixture and report remain unchanged. Both fixture-incorporation tasks remain open for the next campaign's freeze. The contract checker passes; no smoke campaign was run or scheduled.

`[Claude, codebase check]` GPT wrote the two search commands with `rg`;
transcribed here as `grep -E` (`-m 5` and `-n` are supported by BSD grep)
because the repo's test tooling is deliberately bash + grep + awk only.

## Cross-model spec review (Claude, 2026-09-09)

No substantive findings returned to GPT. Placeholders: none. Consistency:
the architecture's "spec and fixture intentionally differ until a future
freeze" is carried through components (TODO text), data flow (hash invariant)
and testing (hash check). Scope: one small docs change. Ambiguity: the
boundary term keeps the existing "references … allowed" clause verbatim, so
it composes with the "One design section" term rather than competing with
it. Codebase fit: line 306 heading confirmed; `rg`→`grep -E` is the only
adjustment.
