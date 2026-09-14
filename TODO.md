# Backlog

Repository-local backlog. NOT installed into ~/.claude (and must never be
added to managed-files.sh).

## Missing prompt variants

Recorded automatically by the GPT-dispatching roles when a resolved model has
no tuned overlay (see CLAUDE.md "GPT model routing"). Entry format, one per
role/model pair:

`- [ ] prompt-variant: role=<ideation|second-opinion|review> model=<exact-model-id>`

## Other

- [ ] install.sh: refuse to link a managed path whose parent directory is itself a symlink into this repo; today link() would move the real repo file aside and create a self-referential link (codex review 2026-09-14, MEDIUM, pre-existing)
