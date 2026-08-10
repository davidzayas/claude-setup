# Prompt Updates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each GPT-facing role (ideation, second-opinion, review) a generic baseline prompt plus a `gpt-5.6-sol` overlay, per-role model defaults in CLAUDE.md, TODO.md missing-variant tracking, and a static contract test — per `docs/superpowers/specs/2026-08-10-prompt-updates-design.md`.

**Architecture:** Role-local prompt packs. All prompt content lives inside the five already-managed Markdown files (zero installer/manifest changes). Baseline and overlay blocks are delimited by HTML-comment markers so a dependency-free bash test can extract and measure them. `commands/adversarial-review.md` owns TODO side effects so the codex-adversary subagent stays read-only.

**Tech Stack:** Markdown prompt files, bash (test script), codex MCP (live smoke matrix only).

## Global Constraints

- **Provenance:** All text inside `gpt-baseline`/`gpt-overlay` markers is GPT-authored final copy (session `019fec4d-64d1-76b1-8c6b-19fc1a7da6bc`, model gpt-5.6-sol). Copy it VERBATIM from this plan — do not edit, reflow, or "improve" it. Claude-facing scaffolding outside markers may be adjusted for flow.
- **Marker grammar (exact):** `<!-- gpt-baseline:ROLE:begin -->` / `<!-- gpt-baseline:ROLE:end -->` and `<!-- gpt-overlay:ROLE:MODEL:begin -->` / `<!-- gpt-overlay:ROLE:MODEL:end -->`, where ROLE ∈ `ideation | second-opinion | review` and MODEL is an exact model id (initially `gpt-5.6-sol`). Markers sit alone on their own line.
- **Byte budget:** each composed baseline+overlay ≤ `MAX_FIXED_PROMPT_BYTES=12288` (defined in `tests/prompt-contract-test.sh`).
- **Session budgets (must appear in prompt-file prose):** ≤20KB working budget per codex session; 30KB hard danger boundary.
- **CLAUDE.md model keys (flush-left, exactly once each):** `gpt_brainstorm_model:`, `gpt_second_opinion_model:`, `gpt_review_model:` — all initially `gpt-5.6-sol`.
- **TODO entry schema (exact):** `- [ ] prompt-variant: role=<ideation|second-opinion|review> model=<exact-model-id>` — one entry per role/model pair, deduplicated.
- **Behavior-preserving:** command names, three-stage flow, report headings (`## Verdict`, `## Findings`, `## Discarded`, `## Reviewer disagreements`), the one-re-review-loop maximum, read-only codex, and stop-on-MCP-failure all stay intact.
- **Never add TODO.md to `managed-files.sh`.**
- Run all commands from the repo root on branch `feature/prompt-updates`.

---

### Task 1: Contract-test harness + CLAUDE.md control plane

**Files:**
- Create: `tests/prompt-contract-test.sh`
- Modify: `CLAUDE.md` (whole file — small)

**Interfaces:**
- Produces: `tests/prompt-contract-test.sh` with helpers `pass`, `fail`, `exactly_once <file> <regex> <label>`, `extract <file> <begin-marker> <end-marker>`, `model_for <brainstorm|second_opinion|review>`, and `MAX_FIXED_PROMPT_BYTES=12288`. Later tasks append `check_*` functions and register them in the `main` list. Exit code 0 = all pass, 1 = any failure.
- Produces: CLAUDE.md keys `gpt_brainstorm_model`, `gpt_second_opinion_model`, `gpt_review_model` that Tasks 2–5 read.

- [ ] **Step 1: Write the test harness with CLAUDE.md checks (failing first)**

Create `tests/prompt-contract-test.sh` with exactly:

```bash
#!/usr/bin/env bash
#
# Static contract checks for the GPT prompt files (see
# docs/superpowers/specs/2026-08-10-prompt-updates-design.md §5).
# Dependency-free: bash + grep + awk + wc only.

set -u

MAX_FIXED_PROMPT_BYTES=12288

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

pass() { echo "  ok       $1"; }
fail() { echo "  FAIL     $1"; FAIL=1; }

# exactly_once <file> <extended-regex> <label>
exactly_once() {
  local n
  n="$(grep -Ec "$2" "$REPO/$1" 2>/dev/null || true)"
  if [[ "$n" == "1" ]]; then pass "$3"; else fail "$3 (found $n, want 1)"; fi
}

# contains <file> <fixed-string> <label>
# (-e guards fixed strings that start with a dash, e.g. "--model")
contains() {
  if grep -qF -e "$2" "$REPO/$1" 2>/dev/null; then pass "$3"; else fail "$3"; fi
}

# extract <file> <begin-marker> <end-marker> — prints block body (exclusive)
extract() {
  awk -v b="$2" -v e="$3" '
    index($0, e) { f = 0 }
    f            { print }
    index($0, b) { f = 1 }
  ' "$REPO/$1"
}

# model_for <brainstorm|second_opinion|review> — prints configured default
model_for() {
  grep -E "^gpt_${1}_model:" "$REPO/CLAUDE.md" | awk '{print $2}' | head -n1
}

check_claude_md() {
  exactly_once CLAUDE.md '^gpt_brainstorm_model:' \
    "CLAUDE.md: gpt_brainstorm_model exactly once"
  exactly_once CLAUDE.md '^gpt_second_opinion_model:' \
    "CLAUDE.md: gpt_second_opinion_model exactly once"
  exactly_once CLAUDE.md '^gpt_review_model:' \
    "CLAUDE.md: gpt_review_model exactly once"
  contains CLAUDE.md '20KB' "CLAUDE.md: states 20KB working budget"
  contains CLAUDE.md '30KB' "CLAUDE.md: states 30KB hard boundary"
  contains CLAUDE.md 'TODO.md' "CLAUDE.md: pins missing-variant tracking to TODO.md"
  contains CLAUDE.md 'unavailable at stage 1 or 3, stop' \
    "CLAUDE.md: stop-on-MCP-failure rule present"
}

main() {
  echo "prompt-contract-test: $REPO"
  check_claude_md
  exit "$FAIL"
}

main
```

- [ ] **Step 2: Make it executable and verify it FAILS (CLAUDE.md not yet updated)**

```bash
chmod +x tests/prompt-contract-test.sh && tests/prompt-contract-test.sh
```

Expected: FAIL lines for `gpt_second_opinion_model` and `gpt_review_model` (found 0), exit code 1. (`gpt_brainstorm_model` also fails: the current line is indented, so `^gpt_` won't match.)

- [ ] **Step 3: Rewrite CLAUDE.md**

Replace the entire contents of `CLAUDE.md` with:

```markdown
## Cross-model pipeline policy

This project uses a three-stage, two-model pipeline:

1. **Brainstorming / requirements → GPT.** For any creative work (new
   features, components, functionality, behavior changes), use the
   `gpt-brainstorming` skill INSTEAD of `superpowers:brainstorming`. GPT is
   the ideator; Claude facilitates and scribes. Never run Claude-only
   brainstorming unless the user explicitly chooses it as a fallback.

2. **Planning / implementation → Claude.** writing-plans, subagent-driven
   development, coding, and testing run on Claude models as normal. Do not
   delegate implementation to the codex tool.

3. **Pre-completion review → GPT.** Before declaring any non-trivial
   implementation task complete, delegate a review to the codex-adversary
   subagent and adjudicate every finding: fix, or rebut explicitly. Do not
   silently drop findings. MEDIUM/LOW may be logged as accepted debt.

If the codex MCP server is unavailable at stage 1 or 3, stop and tell the
user rather than silently substituting Claude for GPT's role.

## GPT model routing

Per-role model defaults. Resolution order for every GPT call: an explicit
model named in the invocation wins, then the role's line below, then the
Codex CLI default from ~/.codex/config.toml.

gpt_brainstorm_model: gpt-5.6-sol
gpt_second_opinion_model: gpt-5.6-sol
gpt_review_model: gpt-5.6-sol

Each GPT-facing role file owns a generic baseline prompt plus per-model
overlays, delimited by `gpt-baseline`/`gpt-overlay` HTML-comment markers.
Select an overlay by EXACT model-id match only — never guess from a similar
name. If no overlay exists for the resolved model: warn the user before
dispatch, use the generic baseline alone, and record the missing variant in
the claude-setup repo's TODO.md as
`- [ ] prompt-variant: role=<role> model=<exact-model-id>` (one entry per
role/model pair; skip if already present).

TODO.md lives in the claude-setup source repo, never the active project.
Locate it by resolving the symlink target of `~/.claude/CLAUDE.md` and
verifying its parent contains `managed-files.sh`. If resolution fails and the
current repo is itself claude-setup (managed-files.sh plus all five managed
prompt paths present), write there; otherwise print the exact entry for
manual recording and continue.

Overlays tune GPT-specific communication only. They may never weaken stage
boundaries, read-only review, the payload budgets (≤20KB working per codex
session, 30KB hard danger boundary), output contracts, or
stop-on-MCP-failure behavior.
```

- [ ] **Step 4: Run the test and verify it PASSES**

```bash
tests/prompt-contract-test.sh
```

Expected: 7 `ok` lines, exit 0 (`echo $?` → 0).

- [ ] **Step 5: Commit**

```bash
git add tests/prompt-contract-test.sh CLAUDE.md
git commit -m "Add prompt contract test harness; per-role GPT model defaults in CLAUDE.md"
```

---

### Task 2: Ideation prompt pack in gpt-brainstorming SKILL.md

**Files:**
- Modify: `skills/gpt-brainstorming/SKILL.md`
- Modify: `tests/prompt-contract-test.sh`

**Interfaces:**
- Consumes: `extract`, `model_for brainstorm`, `MAX_FIXED_PROMPT_BYTES`, marker grammar from Task 1.
- Produces: `check_role_pack <role> <file> <config-key>` — a generic check later tasks reuse for the other two roles; ideation baseline/overlay blocks in SKILL.md.

- [ ] **Step 1: Add the reusable role-pack check to the test (failing first)**

In `tests/prompt-contract-test.sh`, insert above `check_claude_md`:

```bash
# check_role_pack <role> <file> <config-key>
# Verifies: baseline markers present exactly once, an overlay exists for the
# configured default model, and composed baseline+overlay fits the byte cap.
check_role_pack() {
  local role="$1" file="$2" key="$3"
  local model bb eb bytes_b bytes_o

  exactly_once "$file" "<!-- gpt-baseline:${role}:begin -->" \
    "$file: ${role} baseline begin marker exactly once"
  exactly_once "$file" "<!-- gpt-baseline:${role}:end -->" \
    "$file: ${role} baseline end marker exactly once"

  model="$(model_for "$key")"
  if [[ -z "$model" ]]; then
    fail "$file: cannot resolve model for ${key}"
    return
  fi

  bb="<!-- gpt-overlay:${role}:${model}:begin -->"
  eb="<!-- gpt-overlay:${role}:${model}:end -->"
  exactly_once "$file" "$bb" "$file: overlay for ${model} present"

  bytes_b="$(extract "$file" "<!-- gpt-baseline:${role}:begin -->" \
    "<!-- gpt-baseline:${role}:end -->" | wc -c | tr -d ' ')"
  bytes_o="$(extract "$file" "$bb" "$eb" | wc -c | tr -d ' ')"

  if [[ "$bytes_b" -eq 0 ]]; then
    fail "$file: ${role} baseline body is empty"
  fi
  if (( bytes_b + bytes_o <= MAX_FIXED_PROMPT_BYTES )); then
    pass "$file: ${role} baseline+overlay ${bytes_b}+${bytes_o} bytes within ${MAX_FIXED_PROMPT_BYTES}"
  else
    fail "$file: ${role} baseline+overlay ${bytes_b}+${bytes_o} bytes exceeds ${MAX_FIXED_PROMPT_BYTES}"
  fi
}

check_ideation() {
  check_role_pack ideation skills/gpt-brainstorming/SKILL.md brainstorm
  contains skills/gpt-brainstorming/SKILL.md '20KB' \
    "SKILL.md: states 20KB working budget"
  contains skills/gpt-brainstorming/SKILL.md '30KB' \
    "SKILL.md: states 30KB hard boundary"
  contains skills/gpt-brainstorming/SKILL.md 'read-only' \
    "SKILL.md: read-only codex rule present"
}
```

And in `main`, add `check_ideation` after `check_claude_md`.

- [ ] **Step 2: Run and verify the new checks FAIL**

```bash
tests/prompt-contract-test.sh
```

Expected: FAILs for the ideation markers (found 0); exit 1.

- [ ] **Step 3: Update SKILL.md — model selection section**

In `skills/gpt-brainstorming/SKILL.md`, replace the entire `## Model Selection` section (heading and body, up to but not including `## Session Continuity (critical)`) with:

```markdown
## Model Selection and Variant Routing

Resolve the GPT model in this order (first match wins):

1. A model named in the user's invocation ("brainstorm X with o3-pro")
2. The `gpt_brainstorm_model:` line in CLAUDE.md
3. The Codex CLI default from ~/.codex/config.toml (pass no model param)

Then select the prompt variant by EXACT model-id match against the overlay
blocks in this file. If an overlay exists for the resolved model, compose the
briefing as baseline + overlay (baseline first). If not: WARN the user before
dispatch ("no tuned variant for <model>; using the generic baseline"), send
the baseline alone, and record the missing variant per the TODO.md rules in
CLAUDE.md ("GPT model routing").

State the resolved model and variant status in your first message so the
user can correct it. All codex calls in this skill use sandbox read-only.
```

- [ ] **Step 4: Update SKILL.md — session budget wording**

In the `## Session Continuity (critical)` section, replace the sentence beginning `**But keep the session small,` and the following sentence (ending `...fails identically.`) with:

```markdown
**But keep the session small: target a ≤20KB working budget, and treat 30KB
as a hard danger boundary — sessions near it have hung silently** (no error,
no progress, a ~30-minute timeout; resending costs another 30 minutes and
fails identically).
```

Then replace the second bullet (`- If the thread does grow large, ...waiting for it to hang.`) with:

```markdown
- Maintain a compact decision ledger as you go: decisions made, constraints,
  open questions, approved sections. Before the session approaches the 20KB
  working budget, re-seed proactively — start a fresh session from the
  ledger, not the full transcript. Continuity comes from the ledger, not the
  thread id.
```

- [ ] **Step 5: Update SKILL.md — replace the Ideator Briefing**

Replace the entire `## The Ideator Briefing (send as the first codex call)` section (heading and the blockquote) with:

```markdown
## The Ideator Briefing (send as the first codex call)

Compose the first codex prompt as: baseline (below), then the overlay for
the resolved model if one exists, then nothing else. Fill `{project context}`
with a compact summary (never file dumps) and `{idea}` with the user's idea
verbatim.

<!-- gpt-baseline:ideation:begin -->
You are an independent requirements ideator for:

Project context: {project context}
Idea: {idea}

Claude alone facilitates the discussion with the human and verifies approval. Your goal is an approved, implementation-ready design. Success requires the purpose, constraints, measurable success criteria, risky assumptions, selected approach, and every approved design section to be explicit.

During clarification, return exactly ONE decision-focused question and nothing else. Prefer multiple-choice options when practical. Ask only questions whose answers could materially change the design, and never recap settled answers.

Once remaining uncertainty would not materially change the design, stop questioning. Propose 2–3 genuinely distinct approaches, explain their trade-offs, and recommend one. Decompose the work only when the parts are independently useful and implementable.

After Claude relays the selected approach, draft exactly one design section per response, in this order: architecture, components, data flow, error handling, testing. Stop after each section for Claude's verification; revise it until approved before advancing.

Do not implement anything, assume human approval, or act as Claude's substitute.
<!-- gpt-baseline:ideation:end -->

<!-- gpt-overlay:ideation:gpt-5.6-sol:begin -->
The baseline is authoritative; this overlay only tunes communication. Ask the highest-impact unresolved question first. Omit recaps and phase narration. Transition promptly once the answers are sufficient. Keep responses concise while preserving every required design section, boundary, output contract, and stop condition.
<!-- gpt-overlay:ideation:gpt-5.6-sol:end -->
```

- [ ] **Step 6: Run the test and verify it PASSES**

```bash
tests/prompt-contract-test.sh
```

Expected: all `ok`, exit 0. The byte line should report roughly `1200+330` bytes — far under 12288.

- [ ] **Step 7: Commit**

```bash
git add tests/prompt-contract-test.sh skills/gpt-brainstorming/SKILL.md
git commit -m "Ideation prompt pack: GPT-authored baseline + gpt-5.6-sol overlay, 20KB budget"
```

---

### Task 3: Review prompt pack in codex-adversary.md

**Files:**
- Modify: `agents/codex-adversary.md`
- Modify: `tests/prompt-contract-test.sh`

**Interfaces:**
- Consumes: `check_role_pack` from Task 2; `model_for review`.
- Produces: review baseline/overlay blocks; the subagent's expectation that its caller passes `resolved model` and `variant status` (Task 4 produces them).

- [ ] **Step 1: Add review checks to the test (failing first)**

In `tests/prompt-contract-test.sh`, insert after `check_ideation`:

```bash
check_review_agent() {
  check_role_pack review agents/codex-adversary.md review
  contains agents/codex-adversary.md '20KB' \
    "codex-adversary: states 20KB working budget"
  contains agents/codex-adversary.md '30KB' \
    "codex-adversary: states 30KB hard boundary"
  contains agents/codex-adversary.md 'read-only' \
    "codex-adversary: read-only rule present"
  contains agents/codex-adversary.md 'Never retry a timed-out payload unchanged' \
    "codex-adversary: unchanged-timeout prohibition present"
  contains agents/codex-adversary.md '## Verdict' \
    "codex-adversary: Verdict heading present"
  contains agents/codex-adversary.md '## Findings' \
    "codex-adversary: Findings heading present"
  contains agents/codex-adversary.md '## Discarded' \
    "codex-adversary: Discarded heading present"
  contains agents/codex-adversary.md '## Reviewer disagreements' \
    "codex-adversary: Reviewer disagreements heading present"
}
```

Add `check_review_agent` to `main` after `check_ideation`.

- [ ] **Step 2: Run and verify the new checks FAIL**

```bash
tests/prompt-contract-test.sh
```

Expected: FAILs for review markers and `20KB` (the file currently says only ~30KB); exit 1.

- [ ] **Step 3: Update codex-adversary.md — dispatch step and payload budget**

In `agents/codex-adversary.md`, replace step 2's opening line and the size-discipline paragraph. The line

```
2. **Dispatch to Codex.** Call the `codex` MCP tool with:
   - sandbox set to **read-only** (the reviewer must never write)
   - a prompt built from the template below
   - the diff/files and context you assembled
```

becomes:

```
2. **Dispatch to Codex.** Your caller passes the resolved model and its
   variant status (tuned overlay or generic baseline) — model resolution and
   TODO side effects are the caller's job, not yours. Call the `codex` MCP
   tool with:
   - sandbox set to **read-only** (the reviewer must never write)
   - the model you were given, via the model parameter
   - a prompt composed from the baseline below plus the overlay matching the
     resolved model if one exists in this file (baseline first; exact
     model-id match only)
   - the diff/files and context you assembled
```

And replace the sentence `- **Keep any one session under ~30KB of payload total.**` with:

```
   - **Keep any one session at or below a 20KB working budget; 30KB is the
     hard danger boundary at which a payload is unsendable.** Not per
     message — per session.
```

- [ ] **Step 4: Update codex-adversary.md — replace the prompt template (step 3)**

Replace the entire step `3. **Adversarial framing — use this prompt template:**` (including its blockquote) with:

```markdown
3. **Adversarial framing — compose baseline + overlay:**

<!-- gpt-baseline:review:begin -->
You are an evidence-bound, adversarial pre-merge code reviewer.

Stated intent:
{intent}

Supplied review scope:
{payload}

Review only the supplied scope. Do not request unrelated files. Look for race conditions and concurrency faults; unhandled errors and missing null/undefined checks; boundary failures involving empty or maximum values, Unicode, time zones, or offline behavior; injection, authorization gaps, exposed secrets, or unsafe deserialization; resource leaks; and violations of the stated intent.

Report a finding only when the supplied code supports a plausible failure. Assign CRITICAL, HIGH, MEDIUM, or LOW according to both impact and likelihood. Consolidate findings with the same root cause.

For every finding provide:
- file:line
- the concrete failure
- the event sequence that triggers it
- impact and likelihood
- the minimal fix

Output sections in this order: CRITICAL, HIGH, MEDIUM, LOW. Under every empty severity section, write "None found."

Exclude style preferences, diff restatements, duplicate root causes, and unsupported speculation.
<!-- gpt-baseline:review:end -->

<!-- gpt-overlay:review:gpt-5.6-sol:begin -->
The baseline is authoritative; this overlay only tunes communication. Favor fewer evidence-backed findings over speculative coverage. Preserve concrete failure sequences and the required reporting for every severity level despite compressed prose. Consolidate all findings sharing a root cause.
<!-- gpt-overlay:review:gpt-5.6-sol:end -->
```

- [ ] **Step 5: Run the test and verify it PASSES**

```bash
tests/prompt-contract-test.sh
```

Expected: all `ok`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add tests/prompt-contract-test.sh agents/codex-adversary.md
git commit -m "Review prompt pack: evidence-bound baseline + gpt-5.6-sol overlay, 20KB budget"
```

---

### Task 4: adversarial-review.md becomes the side-effect owner

**Files:**
- Modify: `commands/adversarial-review.md`
- Modify: `tests/prompt-contract-test.sh`

**Interfaces:**
- Consumes: CLAUDE.md routing rules (Task 1); codex-adversary's expectation of `resolved model` + `variant status` (Task 3).
- Produces: `--model <exact-id>` syntax shared with Task 5; the TODO-write procedure both commands reference via CLAUDE.md.

- [ ] **Step 1: Add the command checks to the test (failing first)**

In `tests/prompt-contract-test.sh`, insert after `check_review_agent`:

```bash
check_review_command() {
  contains commands/adversarial-review.md '--model' \
    "adversarial-review: documents --model option"
  contains commands/adversarial-review.md 'do not auto-loop more than once' \
    "adversarial-review: one-loop maximum preserved"
  contains commands/adversarial-review.md 'TODO.md' \
    "adversarial-review: owns missing-variant TODO side effect"
}
```

Add `check_review_command` to `main`. (The `contains` helper already uses `grep -qF -e`, so the leading dashes in `--model` are safe.)

- [ ] **Step 2: Run and verify the new checks FAIL**

```bash
tests/prompt-contract-test.sh
```

Expected: FAILs for `--model` and `TODO.md`; exit 1.

- [ ] **Step 3: Rewrite commands/adversarial-review.md**

Replace the entire file contents with:

```markdown
---
description: Cross-model adversarial code review via Codex (GPT). Args: nothing (reviews uncommitted changes), file paths, or a git range like HEAD~3..HEAD. Optional --model <exact-id> anywhere in the args.
disable-model-invocation: true
---

Delegate an adversarial review to the **codex-adversary** subagent.

Review target: $ARGUMENTS
(Strip an optional `--model <exact-id>` pair out of the arguments first; the
rest is the target. If no target remains, review all uncommitted changes:
`git diff HEAD` plus untracked files that are part of the current task.
Reject an empty or repeated --model value: show the accepted syntax and stop
rather than guessing.)

Instructions for this run:

1. Resolve the review model: the `--model` value if given, else
   `gpt_review_model:` from CLAUDE.md, else the Codex CLI default. Check
   whether `agents/codex-adversary.md` has a `gpt-overlay:review:<model>`
   block for it. If not, warn the user ("no tuned variant for <model>;
   using the generic baseline") and record the missing variant in the
   claude-setup repo's TODO.md per the "GPT model routing" rules in
   CLAUDE.md — you own this side effect; the subagent is read-only and must
   never write it.
2. Write a one-paragraph statement of intent for the code under review —
   what it is supposed to do and any constraints from the current task. Do
   not skip this; the reviewer needs intent to catch spec violations.
3. Delegate to codex-adversary, passing the intent, the resolved model, and
   its variant status (tuned overlay or generic baseline). Wait for its
   structured report.
4. Adjudicate the findings yourself:
   - Fix everything you agree with at CRITICAL/HIGH.
   - For findings you disagree with, state the rebuttal explicitly in your
     response — do not silently drop them.
   - MEDIUM/LOW: fix if cheap, otherwise list as accepted debt.
5. If you made fixes, offer to run /adversarial-review once more on the
   fixed diff (do not auto-loop more than once).

Present the final outcome as: verdict, what was fixed, what was rebutted and
why, and what remains as accepted debt.
```

- [ ] **Step 4: Run the test and verify it PASSES**

```bash
tests/prompt-contract-test.sh
```

Expected: all `ok`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/prompt-contract-test.sh commands/adversarial-review.md
git commit -m "adversarial-review: --model option, model resolution, TODO side-effect ownership"
```

---

### Task 5: Second-opinion prompt pack in gpt-brainstorm.md

**Files:**
- Modify: `commands/gpt-brainstorm.md`
- Modify: `tests/prompt-contract-test.sh`

**Interfaces:**
- Consumes: `check_role_pack` (Task 2); `--model` syntax (Task 4); `gpt_second_opinion_model` key (Task 1).
- Produces: second-opinion baseline/overlay blocks.

- [ ] **Step 1: Add second-opinion checks to the test (failing first)**

Insert after `check_review_command`:

```bash
check_second_opinion() {
  check_role_pack second-opinion commands/gpt-brainstorm.md second_opinion
  contains commands/gpt-brainstorm.md '--model' \
    "gpt-brainstorm: documents --model option"
}
```

Add `check_second_opinion` to `main`.

- [ ] **Step 2: Run and verify the new checks FAIL**

```bash
tests/prompt-contract-test.sh
```

Expected: FAILs for second-opinion markers and `--model`; exit 1.

- [ ] **Step 3: Rewrite commands/gpt-brainstorm.md**

Replace the entire file contents with:

```markdown
---
description: Brainstorm or pressure-test requirements with GPT (via Codex MCP), then synthesize both models' views. Args: the topic or a path to a requirements/design doc. Optional --model <exact-id> anywhere in the args.
disable-model-invocation: true
---

Run a structured two-model brainstorm on: $ARGUMENTS
(Strip an optional `--model <exact-id>` pair out of the arguments first; the
rest is the subject. If the subject is a file path, read the file and treat
its contents as the subject. Reject an empty or repeated --model value: show
the accepted syntax and stop rather than guessing.)

Model routing: use the `--model` value if given, else
`gpt_second_opinion_model:` from CLAUDE.md, else the Codex CLI default. If no
overlay below matches the resolved model exactly, warn the user, use the
baseline alone, and record the missing variant in the claude-setup repo's
TODO.md per the "GPT model routing" rules in CLAUDE.md.

Protocol — keep the two perspectives genuinely independent:

1. **Your position first, privately.** Draft your own analysis/approach but
   do NOT show it to the user yet and do NOT include it in the prompt to
   Codex (no anchoring).
2. **Get GPT's independent take.** Call `mcp__codex__codex` with sandbox
   read-only and the resolved model. The prompt is the baseline below (plus
   the matching overlay), with `{topic}` filled with the raw inputs you
   received — nothing more. Omit the `{claude_position}` line and everything
   after "REBUTTAL PHASE" from this first call; the baseline text tells GPT a
   rebuttal phase is coming.
3. **Structured disagreement.** Via `mcp__codex__codex-reply`, send the
   REBUTTAL PHASE portion with `{claude_position}` filled with your draft
   position (now that GPT has committed to its own).
4. **Synthesize for the user:**
   - `## Where we agree` — convergent recommendations (highest confidence)
   - `## Where we diverge` — each disagreement with both positions and your
     adjudication, clearly labeled as yours
   - `## Open questions` — the combined list of questions that must be
     answered before implementation
   - `## Recommended next step`

Keep the synthesis under a page. Divergence points are the valuable output —
never average the two views into mush. Keep the session small: ≤20KB working
budget, 30KB hard boundary.

<!-- gpt-baseline:second-opinion:begin -->
You are a skeptical principal engineer and product architect providing an independent second opinion on {topic}. This conversation has two phases.

FIRST RESPONSE — before Claude's position is disclosed:
1. Give one clear recommendation and its rationale.
2. Identify only the top material risks.
3. Ask only forcing questions whose answers could change the recommendation.
4. Present one serious, genuinely distinct alternative and state when it would win.

Commit to your position independently. Do not infer, solicit, or speculate about Claude's view.

REBUTTAL PHASE — after Claude's position is disclosed as:
{claude_position}

Attack that position constructively. Return only substantive disagreements, missing evidence, optimistic assumptions, and concrete failure scenarios that add material information beyond your first response. Label each concern as either BLOCKER or TRADE-OFF and explain its consequence. Do not repeat prior points or manufacture disagreement. If none exist, return exactly: No substantive disagreement.
<!-- gpt-baseline:second-opinion:end -->

<!-- gpt-overlay:second-opinion:gpt-5.6-sol:begin -->
The baseline is authoritative; this overlay only tunes communication. Commit to a position before seeing Claude's. Keep the alternative genuinely distinct. During rebuttal, return only NEW material disagreements and their concrete consequences. Preserve all phase boundaries, contracts, and stop conditions.
<!-- gpt-overlay:second-opinion:gpt-5.6-sol:end -->
```

- [ ] **Step 4: Run the test and verify it PASSES**

```bash
tests/prompt-contract-test.sh
```

Expected: all `ok`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/prompt-contract-test.sh commands/gpt-brainstorm.md
git commit -m "Second-opinion prompt pack: two-phase baseline + gpt-5.6-sol overlay, --model"
```

---

### Task 6: TODO.md + schema and manifest guards

**Files:**
- Create: `TODO.md`
- Modify: `tests/prompt-contract-test.sh`

**Interfaces:**
- Consumes: TODO entry schema from Global Constraints.
- Produces: `TODO.md` at repo root (never installed); `check_todo` guard.

- [ ] **Step 1: Add TODO checks to the test (failing first)**

Insert after `check_second_opinion`:

```bash
check_todo() {
  if [[ ! -f "$REPO/TODO.md" ]]; then
    fail "TODO.md exists at repo root"
    return
  fi
  pass "TODO.md exists at repo root"

  # Only lines that ARE entries (start with the checkbox) are validated;
  # the documented format line in prose starts with a backtick and is skipped.
  local bad dupes
  bad="$(grep -n '^- \[ \] prompt-variant' "$REPO/TODO.md" \
    | grep -Ev 'prompt-variant: role=(ideation|second-opinion|review) model=[^ ]+$' || true)"
  if [[ -z "$bad" ]]; then
    pass "TODO.md: all prompt-variant entries match the schema"
  else
    fail "TODO.md: malformed prompt-variant entries: $bad"
  fi

  dupes="$(grep '^- \[ \] prompt-variant' "$REPO/TODO.md" | sort | uniq -d)"
  if [[ -z "$dupes" ]]; then
    pass "TODO.md: no duplicate role/model pairs"
  else
    fail "TODO.md: duplicate entries: $dupes"
  fi

  if grep -q 'TODO.md' "$REPO/managed-files.sh"; then
    fail "managed-files.sh must NOT include TODO.md"
  else
    pass "managed-files.sh does not include TODO.md"
  fi
}
```

Add `check_todo` to `main`.

- [ ] **Step 2: Run and verify the new check FAILS**

```bash
tests/prompt-contract-test.sh
```

Expected: `FAIL TODO.md exists at repo root`; exit 1.

- [ ] **Step 3: Create TODO.md**

```markdown
# Backlog

Repository-local backlog. NOT installed into ~/.claude (and must never be
added to managed-files.sh).

## Missing prompt variants

Recorded automatically by the GPT-dispatching roles when a resolved model has
no tuned overlay (see CLAUDE.md "GPT model routing"). Entry format, one per
role/model pair:

`- [ ] prompt-variant: role=<ideation|second-opinion|review> model=<exact-model-id>`

(none yet)
```

(The documented format line starts with a backtick, so the entry validator —
which anchors on `^- \[ \] prompt-variant` — correctly ignores it.)

- [ ] **Step 4: Run the test and verify it PASSES**

```bash
tests/prompt-contract-test.sh
```

Expected: all `ok`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/prompt-contract-test.sh TODO.md
git commit -m "Add TODO.md backlog with prompt-variant schema guards"
```

---

### Task 7: Full regression

**Files:**
- Test: `tests/prompt-contract-test.sh`, `tests/uninstall-test.sh`, `install.sh` (DRY_RUN)

**Interfaces:**
- Consumes: everything above.
- Produces: a verified-green branch ready for adversarial review.

- [ ] **Step 1: Run the prompt contract test**

```bash
tests/prompt-contract-test.sh
```

Expected: all `ok`, exit 0.

- [ ] **Step 2: Run the existing installer regression**

```bash
tests/uninstall-test.sh
```

Expected: same pass output as on main (this plan changes no installer behavior).

- [ ] **Step 3: Verify install DRY_RUN still lists exactly the five managed files**

```bash
DRY_RUN=1 ./install.sh
```

Expected: `ok`/`link`/`backup` lines for exactly `CLAUDE.md`, `agents/codex-adversary.md`, `commands/adversarial-review.md`, `commands/gpt-brainstorm.md`, `skills/gpt-brainstorming/SKILL.md` — no TODO.md, no tests/.

- [ ] **Step 4: Commit anything outstanding (should be nothing)**

```bash
git status --short
```

Expected: clean. If not, stop and reconcile before proceeding.

---

### Task 8: Live gpt-5.6-sol smoke matrix

**Files:**
- Create: `tests/smoke-fixtures/defect.py`
- Create: `tests/smoke-fixtures/clean.py`
- Create: `docs/prompt-smoke-<today's date>-gpt-5.6-sol.md`

**Interfaces:**
- Consumes: the composed prompts from Tasks 2, 3, 5 (extract them exactly as the runtime would: baseline body + overlay body).
- Produces: the recorded smoke results that gate the overlays as "tuned".

This task makes live codex MCP calls (sandbox read-only, model gpt-5.6-sol). If the MCP server is unavailable, STOP and report — do not fake results.

- [ ] **Step 1: Create the defect fixture**

`tests/smoke-fixtures/defect.py`:

```python
"""Config reader used by the deploy script."""


def last_n(items, n):
    """Return the last n items of the list (n >= 0)."""
    # NOTE: could be rewritten with itertools.islice for elegance
    return items[len(items) - n:]  # n == 0 returns the WHOLE list, not []


def read_env(path):
    # TODO: someone should really add type hints to this module
    text = open(path).read()
    lines = text.split("\n")
    result = {}
    for line in lines:
        key, value = line.split("=", 1)
        result[key.strip()] = value.strip()
    return result
```

Seeded real defects: `last_n(items, 0)` returns the whole list (boundary), and `read_env` crashes on blank/comment lines and leaks the file handle on error paths. The comments are style bait the reviewer must ignore.

- [ ] **Step 2: Create the clean fixture**

`tests/smoke-fixtures/clean.py`:

```python
"""Pure helpers with no known defects."""


def clamp(value, low, high):
    """Return value bounded to [low, high]. Assumes low <= high."""
    if low > high:
        raise ValueError(f"low ({low}) must be <= high ({high})")
    return max(low, min(value, high))


def chunks(items, size):
    """Yield successive size-length chunks; size must be positive."""
    if size <= 0:
        raise ValueError(f"size must be positive, got {size}")
    for start in range(0, len(items), size):
        yield items[start:start + size]
```

- [ ] **Step 3: Run the five scenarios**

For each row, compose the prompt exactly as the runtime would (baseline body, then overlay body) and call `mcp__codex__codex` with model `gpt-5.6-sol`, sandbox read-only. Record input/output byte counts (`wc -c` on what you send/receive).

1. **Ideation / ambiguous:** `{project context}` = "A CLI tool repo with an installer and a test suite." `{idea}` = "add some kind of caching". Required: exactly one high-impact question, no recap, no premature design.
2. **Ideation / nearly complete:** same context; `{idea}` = "add a --version flag that prints the version from a VERSION file at the repo root, errors with exit 1 if the file is missing, covered by one test". Required: prompt transition to 2–3 distinct approaches without needless questioning.
3. **Second opinion:** `{topic}` = "Store per-user settings as one JSON file per user vs a single SQLite database, for a tool with <1000 users". First call must commit to a recommendation; then codex-reply with a deliberately different Claude position ("I prefer the option you did not recommend because migration tooling is free") — the rebuttal must contain concrete, non-repeated disagreements labeled BLOCKER/TRADE-OFF.
4. **Review / defect fixture:** `{intent}` = "read_env parses KEY=VALUE lines from a config file; last_n returns the last n items". `{payload}` = full contents of `tests/smoke-fixtures/defect.py`. Required: finds the n==0 boundary bug and/or the unhandled blank-line/ValueError path with severity, line, event sequence, minimal fix; ignores the style-bait comments.
5. **Review / clean fixture:** `{intent}` = "bounded clamp and positive-size chunking helpers". `{payload}` = full contents of `clean.py`. Required: no invented defects; explicit "None found." under every empty severity.

- [ ] **Step 4: Record results**

Create `docs/prompt-smoke-<YYYY-MM-DD>-gpt-5.6-sol.md` (today's date) with this structure, filled from Step 3:

```markdown
# Prompt smoke run — gpt-5.6-sol

Prompt revision: <git SHA of the branch at run time>

| # | Role | Scenario | In/out bytes | Contract pass? | Notes |
|---|------|----------|--------------|----------------|-------|
| 1 | ideation | ambiguous feature | | | |
| 2 | ideation | near-complete requirements | | | |
| 3 | second-opinion | JSON-vs-SQLite | | | |
| 4 | review | seeded defects | | | |
| 5 | review | clean fixture | | | |

## Failures and adjustments

<for each failed case: the observed deviation, and the SMALLEST overlay
change that addresses it. One surgical change, then rerun that case only.>
```

Do not paste full transcripts — verdict-level evidence only.

- [ ] **Step 5: If a case failed, apply one surgical overlay change and rerun that case**

Edit only the relevant overlay block, rerun the failing scenario, update the results doc. Then rerun `tests/prompt-contract-test.sh` (byte budget still enforced).

- [ ] **Step 6: Commit**

```bash
git add tests/smoke-fixtures/ docs/prompt-smoke-*.md
git commit -m "Live gpt-5.6-sol smoke matrix: fixtures and recorded results"
```

---

## Final integration

After Task 8, per the project's cross-model policy, run `/adversarial-review` on the branch diff (`main..feature/prompt-updates`) before declaring the work complete, then use superpowers:finishing-a-development-branch.
