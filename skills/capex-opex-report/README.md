# capex-opex-report — Claude Code skill

Turns your local Claude Code session transcripts into a finance-ready
capex/opex report: one line per project, three weightings (by time, by
project, by session), published as a shareable Claude artifact.

Scripts do all the counting. Claude does the classification, following the
lifecycle-stage rule (ASC 350-40 internal-use software) written in SKILL.md.

## Requirements

- Claude Code (desktop app or CLI) with session transcripts in `~/.claude/projects`
- Python 3.9 or newer (macOS ships one; `python3 --version` to check)
- No third-party packages

## Install

From the claude-setup repo (the normal path): `install.sh` at the repo root
symlinks every file of this skill into `~/.claude/skills/capex-opex-report/`
along with the rest of the managed config. Nothing else to do.

Standalone, without the repo:

    mkdir -p ~/.claude/skills
    cp -R capex-opex-report ~/.claude/skills/

Then start a new Claude Code session. The skill is picked up automatically.

## Use

In any Claude Code session, ask in plain words:

    run the capex/opex report for the last 30 days, exclude my-side-project

or invoke it directly:

    /capex-opex-report last 30 days, exclude my-side-project

Claude will scan your transcripts, read the prompts per project, classify
each session, render the HTML, publish it as a private artifact, and give
you the link plus a summary in chat. Share the artifact from its share menu.

Tips:

- Name the period explicitly if you want something other than the last 30
  days ("August 15 to September 14").
- Name any repositories to leave out (personal projects, experiments).
- Ask Claude to explain any classification you disagree with; the
  classification JSON it wrote is the source of every number on the page.

## What's inside

    SKILL.md                    workflow + classification rules Claude follows
    scripts/scan_sessions.py    reads transcripts, computes active hours per session
    scripts/grep_session.py     digests one session: PR titles, lifecycle evidence
    scripts/render_report.py    classification.json -> report.html (all math here)
    templates/report.html       page design
    examples/classification-2026-09.json   a complete worked example

## How hours are counted

Active time is the sum of gaps between consecutive transcript events, each
gap capped at 10 minutes, so idle hours inside long-running sessions are not
counted. Subagent transcripts, duplicate (forked) transcripts, and automated
sandbox runs are handled so nothing is double counted. Hours are approximate
and derived from timestamps, not a timesheet; the report says so in its
footer.

## Privacy

Everything runs locally against your own `~/.claude/projects`. Nothing is
uploaded until Claude publishes the finished HTML as an artifact, and that
artifact is private until you share it.
