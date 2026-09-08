# Backlog

Repository-local backlog. NOT installed into ~/.claude (and must never be
added to managed-files.sh).

## Missing prompt variants

Recorded automatically by the GPT-dispatching roles when a resolved model has
no tuned overlay (see CLAUDE.md "GPT model routing"). Entry format, one per
role/model pair:

`- [ ] prompt-variant: role=<ideation|second-opinion|review> model=<exact-model-id>`

- [ ] prompt-variant: role=ideation model=gpt-6-astra

## Follow-ups from final branch review (2026-08-10)

- [ ] test-hardening: guard 20KB/30KB + read-only strings in commands/gpt-brainstorm.md
- [ ] test-hardening: check overlay END markers exactly once (deleting one silently extracts to EOF)
- [ ] test-hardening: measure byte cap for every overlay present, not just the configured default
- [ ] test-hardening: TODO dupe check is exact-line only ("- [x]" variant escapes it)
- [ ] test-hardening: stop-on-MCP-failure string checked only in CLAUDE.md, not SKILL.md/codex-adversary.md
- [ ] prompt-tuning: align the ideation overlay's skip-clarification trigger with the baseline's required categories (purpose, constraints, success criteria, risky assumptions) and rerun the ideation smoke cases (adversarial-review finding, accepted debt)

## Version pins

- [x] unpin codex from 0.146.1 — done 2026-08-26: 0.149.1 passed both legs
      of the verification playbook against the Azure deployment (CLI request
      + MCP call). Upstream issues #37380/#37487/#37675 remain open and the
      fix may be partly Azure-side, so the playbook re-runs after any
      future codex upgrade.
- [ ] test-hardening: contract guard that agents/codex-adversary.md mentions "overlay model" (guards the caller/agent seam the 2026-08-14 final review caught)
