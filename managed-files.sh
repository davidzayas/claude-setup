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
  skills/capex-opex-report/SKILL.md
  skills/capex-opex-report/README.md
  skills/capex-opex-report/scripts/scan_sessions.py
  skills/capex-opex-report/scripts/grep_session.py
  skills/capex-opex-report/scripts/render_report.py
  skills/capex-opex-report/templates/report.html
  skills/capex-opex-report/examples/classification-2026-09.json
)
