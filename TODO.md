# Backlog

Repository-local backlog. NOT installed into ~/.claude (and must never be
added to managed-files.sh).

## Missing prompt variants

Recorded automatically by the GPT-dispatching roles when a resolved model has
no tuned overlay (see CLAUDE.md "GPT model routing"). Entry format, one per
role/model pair:

`- [ ] prompt-variant: role=<ideation|second-opinion|review> model=<exact-model-id>`

(none yet)

## Follow-ups from final branch review (2026-08-10)

- [ ] test-hardening: guard 20KB/30KB + read-only strings in commands/gpt-brainstorm.md
- [ ] test-hardening: check overlay END markers exactly once (deleting one silently extracts to EOF)
- [ ] test-hardening: measure byte cap for every overlay present, not just the configured default
- [ ] test-hardening: TODO dupe check is exact-line only ("- [x]" variant escapes it)
- [ ] test-hardening: stop-on-MCP-failure string checked only in CLAUDE.md, not SKILL.md/codex-adversary.md
