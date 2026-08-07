#!/usr/bin/env bash
#
# The one list both install.sh and uninstall.sh source, so they can never
# disagree about which paths this repo owns. Data only — no side effects.

MANAGED_FILES=(
  CLAUDE.md
  agents/codex-adversary.md
  commands/adversarial-review.md
  commands/gpt-brainstorm.md
  skills/gpt-brainstorming/SKILL.md
)
