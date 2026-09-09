# Backlog

Repository-local backlog. NOT installed into ~/.claude (and must never be
added to managed-files.sh).

## Missing prompt variants

Recorded automatically by the GPT-dispatching roles when a resolved model has
no tuned overlay (see CLAUDE.md "GPT model routing"). Entry format, one per
role/model pair:

`- [ ] prompt-variant: role=<ideation|second-opinion|review> model=<exact-model-id>`

- [x] prompt-variant: role=ideation model=gpt-6-astra — done 2026-09-08: overlay added (this plan, Task 1)

## Follow-ups from final branch review (2026-08-10)

- [ ] test-hardening: guard 20KB/30KB + read-only strings in commands/gpt-brainstorm.md
- [ ] test-hardening: check overlay END markers exactly once (deleting one silently extracts to EOF)
- [ ] test-hardening: measure byte cap for every overlay present, not just the configured default
- [ ] test-hardening: TODO dupe check is exact-line only ("- [x]" variant escapes it)
- [ ] test-hardening: stop-on-MCP-failure string checked only in CLAUDE.md, not SKILL.md/codex-adversary.md
- [x] prompt-tuning: align the ideation overlay's skip-clarification trigger with the baseline's required categories (purpose, constraints, success criteria, risky assumptions) and rerun the ideation smoke cases (adversarial-review finding, accepted debt) — done for `gpt-6-astra` (2026-09-08, this migration, smoke round 2); won't-fix for the retained `gpt-5.6-sol` overlay (2026-09-09: rollback-only variant, nothing dispatches to it by default; a rollback restores the known weakness — see docs/prompt-smoke-2026-09-08-gpt-6-astra.md's Activation note, which records the weakness; the won't-fix decision is this branch's (2026-09-09))

## Version pins

- [x] unpin codex from 0.146.1 — done 2026-08-26: 0.149.1 passed both legs
      of the verification playbook against the Azure deployment (CLI request
      + MCP call). Upstream issues #37380/#37487/#37675 remain open and the
      fix may be partly Azure-side, so the playbook re-runs after any
      future codex upgrade.
- [ ] test-hardening: contract guard that agents/codex-adversary.md mentions "overlay model" (guards the caller/agent seam the 2026-08-14 final review caught)

## Follow-ups from final branch review (2026-09-09)

- [ ] fixture: correct the L2 case-inventory row in tests/smoke-fixtures/ideation-gpt-6-astra-cases.md ("all five design sections" → ends after data flow) at the next campaign's freeze; the file is hash-frozen for campaign 2
- [ ] smoke-budget: per-section response allowances (1.5–2KB) were exceeded in 5/6 round-1 and 5/6 campaign-2 L2 responses; size allowances from observed gpt-6-astra output (≈2–3KB per section) at the next freeze
- [ ] smoke-scope: a five-section live journey does not fit the 20KB working budget for an L2-sized idea; split into two journeys or raise the reserve; error-handling and testing gates currently have no live-history coverage
- [ ] rubric: add an Evaluation Term for the implicit stop-for-verification (a response that ends after one section with no advancement satisfies "stops for verification"); applied de facto at L2-COMP-R, L2-FLOW, H3
- [ ] rubric: add an Evaluation Term for the components/error-handling boundary (interface payloads and state ownership are components content; failure outcomes and adapter guarantees are error-handling content); both campaigns' H3 verdicts turned on it
- [ ] overlay-guardrail: an overlay may emphasise a baseline rule only when a recorded failure names it and must not restate the rule's content; consider a contract-test assertion that the ideation overlay does not repeat the baseline's section-order list
