# Prompt smoke run — gpt-5.6-sol

Prompt revision: `b891d35` for the first pass of all five cases; cases 1 and 2
were rerun on `b891d35` plus the one-line ideation-overlay fix recorded below
(committed immediately before this document).

Method: each prompt was composed exactly as the runtime composes it — baseline
block body, then the `gpt-5.6-sol` overlay block body, with the template slots
filled — and dispatched via `mcp__codex__codex` with `model: gpt-5.6-sol` and
`sandbox: read-only`. One separate session per scenario; scenario 3 used
`codex` then `codex-reply` in the same thread. Byte counts are the composed
prompt sent and the assistant text returned. Every payload was under 3KB, well
inside the 20KB working budget; no timeouts or hangs occurred.

| # | Role | Scenario | In/out bytes | Contract pass? | Notes |
|---|------|----------|--------------|----------------|-------|
| 1 | ideation | ambiguous feature | 1740 / 134 | yes | Exactly one multiple-choice question (which cache layer), no recap, no design content. Same behaviour before and after the overlay fix. |
| 2 | ideation | near-complete requirements | 1861 / 1479 | yes (after fix) | First pass failed: asked a clarifying question instead of transitioning. After the overlay fix it emitted purpose, constraints, 3 distinct approaches with trade-offs, measurable success criteria, the risky assumption, and a recommendation — no questioning. |
| 3 | second-opinion | JSON-vs-SQLite | 1503 / 2959 | yes | Phase 1 committed to SQLite with rationale, 3 material risks, 3 forcing questions, and a genuinely distinct alternative (managed PostgreSQL), and did not speculate about Claude's view. Phase 2 returned 1 BLOCKER + 1 TRADE-OFF, both new and concrete (interrupted-migration version split; silently skipped straggler files), no repetition of phase 1. |
| 4 | review | seeded defects | 2036 / 2084 | yes | HIGH on the unhandled blank-line/trailing-newline `ValueError` with file:line, event sequence, impact/likelihood, and a minimal fix; LOW on the unclosed file handle. Ignored both style-bait comments as findings. See the fixture note below regarding `last_n`. |
| 5 | review | clean fixture | 1974 / 91 | yes | No invented defects; explicit "None found." under all four severity sections. |

## Failures and adjustments

**Case 2 — ideation, near-complete requirements (first pass).**

- Observed deviation: given an idea that already stated behaviour, the failure
  mode, the exit code, and the test expectation, the model still opened with a
  clarifying question ("Which executable should support `--version`?") rather
  than transitioning to approaches. The baseline's stop condition ("Once
  remaining uncertainty would not materially change the design, stop
  questioning") was not enough to trigger the transition on turn one.
- Smallest overlay change (ideation overlay in
  `skills/gpt-brainstorming/SKILL.md`, one clause appended to an existing
  sentence): `Transition promptly once the answers are sufficient` →
  `Transition promptly once the answers are sufficient; when the idea already
  states its behavior, failure handling, and test expectations, skip
  clarification and go straight to approaches.`
- Rerun result: case 2 passes. Case 1 was rerun as a regression check because
  the same overlay governs it, and it still returns exactly one question —
  the added clause is correctly conditional on the idea already being
  specified.
- `tests/prompt-contract-test.sh` rerun after the edit: all checks pass;
  ideation baseline+overlay is 1230+458 = 1688 bytes against the 12288 cap.

No other case required an adjustment.

## Fixture note (not a prompt failure)

`tests/smoke-fixtures/defect.py` is committed with the exact contents the task
brief specified, including the inline comment claiming `n == 0` returns the
whole list. That comment is factually wrong: `items[len(items) - n:]` with
`n == 0` is `items[len(items):]`, which is `[]` (verified by executing the
fixture). The reviewer correctly rejected the claim rather than echoing it, so
the case still satisfies its "and/or" evidence contract via the blank-line
defect, and the wrong comment functions as additional bait that the model did
not take.

Two blemishes worth recording, neither contract-breaking:

- The model reported that rejection *as* a MEDIUM finding whose own impact
  field reads "None", and whose minimal fix is a comment edit. A non-failure
  and a comment cleanup do not belong under a severity section per the
  baseline's "report a finding only when the supplied code supports a
  plausible failure" and its style-exclusion rule; it belongs in prose.
- That finding's "Trigger" field contains visible self-correction ("Python
  interprets ... as expected only? Actually the code evaluates ...") instead
  of a settled event sequence.

The genuinely defective boundary in `last_n` is `n > len(items)`
(`last_n([1,2,3], 5)` returns `[2, 3]`, not `[1, 2, 3]`, because the index
goes negative). The reviewer did not find it. This is a gap in the fixture's
stated seeding, not a prompt regression, and is left as-is so the recorded run
matches the brief's fixture verbatim.
