---
name: capex-opex-report
description: Use when asked for a monthly (or any period) capex/opex breakdown of Claude Code work, an engineering time capitalization report for finance, or a summary of what sessions were spent on across projects.
---

# Capex/Opex Report

## Overview

Turn local Claude Code transcripts into a finance-ready capitalization report: one line per project, three weightings (time, project, session), published as an artifact. Scripts do the counting; you do the classification. Never type a total or a percentage by hand.

## Workflow

1. **Scan.** Default window is the last 30 days ending today. Exclusions are whatever the user names (personal or side projects, for example). Pass the current session id so the report session is not counted.
   ```bash
   python3 ~/.claude/skills/capex-opex-report/scripts/scan_sessions.py \
     --since YYYY-MM-DD --until YYYY-MM-DD --exclude a,b --exclude-session <this-session-id-prefix> --out <scratch>/scan
   ```
   Prints a per-project table; writes `sessions.json` and `prompts.md`. Slash commands appear as prompts (`/pr-review-pipeline:review 171 172 173`); a session whose prompts are mostly slash commands is a full workload, not a "pull latest" session.
2. **Read `prompts.md` in full.** It is often over 30 KB, so read it in slices (`sed -n '1,400p'`, then the next range) rather than one truncated read. For each project, determine the product's lifecycle stage and what the work delivered. For any session whose prompts alone do not say (bare PR numbers, "keep going", "approved"), run the digest:
   ```bash
   python3 ~/.claude/skills/capex-opex-report/scripts/grep_session.py <session-id-prefix> --since YYYY-MM-DD --until YYYY-MM-DD
   ```
   It lists PR titles (a superset of PRs reviewed; status tables name others) and stage-evidence lines. When the default evidence is thin, pass `--pattern` with words specific to that project (`"merged|deployed|PR #1[58]"`, `"0\.2[23]\.0|store"`).
3. **Classify per session** with the rule table below. Mixed session: split by tool calls per day (in `prompts.md`), then apply the haircut to the capex portion.
4. **Write `classification.json`** in the shape documented at the top of `scripts/render_report.py`. One entry per project; sessions nested with `hours` copied from the scan at two decimals (the project total may then differ from the scan by 0.01, which is fine) and `capex_share`. A project with sandbox runs gets a `sandbox` block: runs and hours from the scan's sandbox line, share equal to the parent session's share. `prepared_by` is the user's name (`git config user.name`). Summaries are one or two sentences naming concrete deliverables (PR numbers, feature names), not "various fixes". `examples/classification-2026-09.json` is a complete, verified example from a real month.
5. **Render and publish.**
   ```bash
   python3 ~/.claude/skills/capex-opex-report/scripts/render_report.py classification.json --out <scratch>/report.html
   ```
   It prints the per-project table and totals for the chat reply. Publish with the Artifact tool: `<title>` is already `Engineering Time Capitalization`, favicon `📒`, description names the period. A new month is a new artifact, not a redeploy of last month's URL.
6. **Reply in chat** with the three weightings, the per-project table in one line each, and the artifact link. State every judgment call that moved more than about 5% of hours.

## Classification rule

Lifecycle stage decides, not the shape of the task. This is the ASC 350-40 internal-use-software convention.

| Situation | Class |
|---|---|
| Product not yet in service (alpha, beta, TestFlight-only, unlisted or link-only store listing, behind a password, awaiting SSO): build, test, bug fix, hardening, release packaging, first deployment | Capex |
| Live product: new feature, new integration, new screen | Capex |
| Live product: bug fix, release packaging, redeploy, dependency upgrade | Opex |
| Fix on a feature branch before that feature merges, or acceptance-test fixes on a feature in its rollout window (same release, before users are on it) | Capex (feature completion) |
| Feature merged to main but not yet released to users (version pre-bumped, store submission pending): making it work | Capex (feature completion) |
| PR review of a colleague's PR | Same class as the PR being reviewed |
| Building a new internal tool from scratch (new repo, versioned releases), including installing it to test it | Capex |
| Maintaining or configuring existing developer tooling: model migrations, prompt tuning, Claude setup, plugin installs | Opex |
| Evaluating or exploring a codebase, running tests to assess it | Opex |
| Config-only, docs-only, "pull latest" | Opex (usually minutes) |

**Haircut, applied to a capex session's share:**

| Chores in the session | Share |
|---|---|
| None, or a single pull-latest at the start | 1.00 |
| A few chore prompts (memory updates, model switch, pull-latest mid-session) | 0.95 |
| Config-only or docs-only PRs reviewed or written, or chores on several days | 0.90 |

Give the finance reader the evidence for each stage call in `capex_rationale` and `opex_rationale`.

## Common mistakes

- **Classifying by task shape.** Calling every fix and every review "opex" undercounted capex by 16 points on a pre-release portfolio. Ask "is this product in service?" first. Two dry runs both got ai-command-center wrong this way until the digest showed the fixes were on an unmerged feature branch.
- **Counting subagent transcripts as sessions.** Only top-level `<project>/<id>.jsonl` files are sessions; the script already skips `subagents/`.
- **Trusting file mtimes.** The desktop app appends metadata to old transcripts, so `find -mtime` includes sessions with no activity in the window. The script filters on event timestamps.
- **Double counting.** A resumed session can fork into two transcripts with a shared prefix; the script unions them into one. Sandbox scratchpad runs are automated tests of the parent project and are folded, never listed as projects.
- **Wall-clock time.** Multi-week sessions have days of idle. Active time is gap-capped at 10 minutes; say so in the report.
