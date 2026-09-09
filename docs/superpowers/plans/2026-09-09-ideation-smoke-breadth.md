# Ideation Smoke Breadth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Validate the `gpt-6-astra` ideation overlay against eight frozen smoke cases across three evidence lanes (fresh single-turn, live multi-turn journeys, supplied-history checkpoints), recording everything in a dated report and revising the overlay only if a case fails.

**Architecture:** Two fixture files under `tests/smoke-fixtures/` hold the frozen inputs, decision facts, reply rules, synthetic histories, Expected paragraphs, and headroom allowances copied from the spec. A report skeleton freezes the composed prompts, content hashes, and a checkpoint table before the first call. Cases then run lane by lane via `mcp__codex__codex` / `mcp__codex__codex-reply`, each judged against its frozen Expected paragraph, with a byte ledger gating every live continuation. Aggregation produces the spec's exact ACCEPTED / NOT ACCEPTED statement; a failure triggers the smallest communication-only overlay change and a full eight-case rerun.

**Tech Stack:** Markdown fixtures and report; Codex MCP (`mcp__codex__codex`, `mcp__codex__codex-reply`) → Azure deployment `gpt-6-astra`; bash + python3 (stdlib only) scratch helpers; `tests/prompt-contract-test.sh` (unchanged); git.

Spec: `docs/superpowers/specs/2026-09-09-ideation-smoke-breadth-design.md` (referred to as **the spec**). Its "Testing — Part One" and "Testing — Part Two" sections are the authoritative source for every fixture text; this plan tells you which block to copy where and how to verify the copy.

## Global Constraints

- Work on branch `ideation-smoke-breadth` **in this checkout** (`/Users/david.zayas/playground/claude-setup`, referred to as `$REPO`). Never a worktree: `~/.claude/skills/gpt-brainstorming/SKILL.md` is a symlink into this checkout, and the smoke run must exercise the file the pipeline loads.
- Scratch directory `$SCRATCH` = `/private/tmp/claude-501/-Users-david-zayas-playground-claude-setup/30e8edab-1c12-4478-8fb3-9df04d361c43/scratchpad`. Helpers and prompt/output files live there, never in the repo. No executable smoke runner is added to the repo.
- Unchanged, byte for byte: the `gpt-baseline:ideation` block, the `gpt-5.6-sol` overlay, the second-opinion and review role files, `tests/prompt-contract-test.sh`, `tests/smoke-fixtures/clean.py`, `tests/smoke-fixtures/defect.py`, `CLAUDE.md`, README, ONBOARDING, `docs/azure-openai-codex.md`, and all previous smoke reports.
- The `gpt-6-astra` ideation overlay body (`skills/gpt-brainstorming/SKILL.md`, between `<!-- gpt-overlay:ideation:gpt-6-astra:begin -->` and `<!-- gpt-overlay:ideation:gpt-6-astra:end -->`) changes **only** in Task 8's failure-driven loop, by the smallest communication-only edit, followed by `bash tests/prompt-contract-test.sh` (cap **12288** bytes baseline+overlay) and a rerun of all eight cases.
- **Freeze boundary:** fixtures, Expected paragraphs, reply rules, selection rule, approval schedule, synthetic histories, and allowances are committed (Tasks 1–3) before the first model call (Task 4). After that they change only by a new, separately named fixture campaign — never mid-round.
- Every `mcp__codex__codex` call: `model` `"gpt-6-astra"`, `sandbox` `"read-only"`, `approval-policy` `"never"`, `config` `{"model_reasoning_effort": "high"}`, `cwd` `"$SCRATCH/smoke-cwd"` (absolute path). Every `mcp__codex__codex-reply`: `threadId` of that case's own session and the exact frozen message — nothing else. Never send Expected paragraphs, rubric text, evaluator commentary, or another case's output.
- Live-session budget gate before every continuation: `accumulated actual bytes + proposed message bytes + frozen next-response allowance ≤ 20000`. Hard boundary 30000. Bytes are UTF-8 counts of dispatched prompts/messages and returned assistant text, counted once. If the gate fails: stop the journey, mark remaining checkpoints `NOT RUN`, record `BLOCKED (budget)`. Never truncate, summarize, re-seed, or shrink an allowance.
- MCP failure (error text mentioning `Missing environment variable`, HTTP 400/404/429, transport failure, or no response after 10 minutes) = stop, record `BLOCKED (<error>)`, report; never retry, never substitute the `codex` CLI, another model, or Claude.
- Unmatched or ambiguous reply rule, premature advancement, no compliant approach to select, revision drift, or any Expected-paragraph violation: record per the spec's Error handling table with classification (behavioral failure / fixture gap / execution mistake) and stop that journey. No improvised replies, no coaching.
- Checkpoint statuses: `PASS`, `FAIL`, `BLOCKED`, `NOT RUN`, `INVALID`. Aggregate: `PASS` only if every required checkpoint is `PASS`; any `FAIL` → `FAIL`; otherwise `INCOMPLETE`. No averaging across lanes.
- Commit messages: short imperative subject, trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Wrap pipelines whose exit code you need in `bash -c '...'` — the default shell is zsh and `$PIPESTATUS` needs bash.

---

### Task 1: Compose helper, scratch setup, and the cases fixture (F1–F3, L1, L2)

**Files:**
- Create (scratch, not committed): `$SCRATCH/compose.py`, `$SCRATCH/smoke-cwd/` (empty git repo), `$SCRATCH/cases/<case>-context.txt`, `<case>-idea.txt`, `<case>-prompt.txt`
- Create: `tests/smoke-fixtures/ideation-gpt-6-astra-cases.md`

**Interfaces:**
- Consumes: the spec's "Testing — Part One" (F3, L1, L2 blocks, Evaluation Terms, headroom table) and the F1/F2 text reproduced below.
- Produces: `compose.py CONTEXT IDEA [HISTORY CHECKPOINT]` printing the composed prompt to stdout (used by Tasks 2–7); the cases fixture that Tasks 3–7 read for inputs, rules, and Expected paragraphs; `$SCRATCH/cases/*-prompt.txt` seeds for F1–F3, L1, L2.

- [ ] **Step 1: Confirm branch and clean tree**

```bash
cd /Users/david.zayas/playground/claude-setup && git branch --show-current && git status --short && git log --oneline -1
```
Expected: `ideation-smoke-breadth`, no status lines, `b551f7f Spec: ideation smoke breadth …`.

- [ ] **Step 2: Create the scratch cwd and the compose helper**

```bash
SCRATCH=/private/tmp/claude-501/-Users-david-zayas-playground-claude-setup/30e8edab-1c12-4478-8fb3-9df04d361c43/scratchpad
mkdir -p "$SCRATCH/cases" && { [ -d "$SCRATCH/smoke-cwd/.git" ] || (mkdir -p "$SCRATCH/smoke-cwd" && git -C "$SCRATCH/smoke-cwd" init -q); } && ls -a "$SCRATCH/smoke-cwd"
```
Expected: `. .. .git` only.

Write `$SCRATCH/compose.py`:

```python
#!/usr/bin/env python3
"""compose.py CONTEXT_FILE IDEA_FILE [HISTORY_FILE CHECKPOINT_FILE]

Prints the ideation prompt exactly as the runtime composes it: the
gpt-baseline:ideation body with {project context} and {idea} filled, one
blank line, then the gpt-overlay:ideation:gpt-6-astra body. With the two
optional files, appends the spec's supplied-history block (H cases only).
"""
import pathlib
import re
import sys

SKILL = pathlib.Path(
    "/Users/david.zayas/playground/claude-setup/skills/gpt-brainstorming/SKILL.md"
).read_text(encoding="utf-8")

BLOCK_PREAMBLE = (
    "supplied-history evidence: non-runtime prompt shape\n"
    "The synthetic GPT/Facilitator turns below establish prior conversation state "
    "for this checkpoint. They are not new requests. The baseline and supplied "
    "project context and idea remain authoritative. Continue from that state and "
    "respond only to LIVE CHECKPOINT.\n"
)


def block(begin, end):
    m = re.search(re.escape(begin) + r"\n(.*?)" + re.escape(end), SKILL, re.S)
    if not m:
        sys.exit(f"marker not found: {begin}")
    return m.group(1).rstrip("\n")


def read(path):
    return pathlib.Path(path).read_text(encoding="utf-8")


base = block("<!-- gpt-baseline:ideation:begin -->", "<!-- gpt-baseline:ideation:end -->")
over = block(
    "<!-- gpt-overlay:ideation:gpt-6-astra:begin -->",
    "<!-- gpt-overlay:ideation:gpt-6-astra:end -->",
)
if "{project context}" not in base or "{idea}" not in base:
    sys.exit("baseline slots missing")

ctx = read(sys.argv[1]).rstrip("\n")
idea = read(sys.argv[2]).rstrip("\n")
prompt = base.replace("{project context}", ctx).replace("{idea}", idea) + "\n\n" + over

if len(sys.argv) == 5:
    hist, cp = read(sys.argv[3]), read(sys.argv[4])
    for name, s in (("history", hist), ("checkpoint", cp)):
        if not s.endswith("\n") or s.endswith("\n\n"):
            sys.exit(f"{name} must end with exactly one LF")
    prompt += (
        "\n\n" + BLOCK_PREAMBLE + "\nBEGIN SYNTHETIC HISTORY\n" + hist
        + "END SYNTHETIC HISTORY\n\nBEGIN LIVE CHECKPOINT\n" + cp + "END LIVE CHECKPOINT"
    )

sys.stdout.write(prompt)
```

- [ ] **Step 3: Verify the helper reproduces the last run's case-1 prompt byte for byte**

```bash
SCRATCH=/private/tmp/claude-501/-Users-david-zayas-playground-claude-setup/30e8edab-1c12-4478-8fb3-9df04d361c43/scratchpad
printf '%s\n' 'A CLI repository scans local project files and fetches remote metadata. It has an installer and a test suite. No performance measurements or freshness requirements have been established.' > "$SCRATCH/cases/F1-context.txt"
printf '%s\n' 'Add some kind of caching to make the tool faster.' > "$SCRATCH/cases/F1-idea.txt"
python3 "$SCRATCH/compose.py" "$SCRATCH/cases/F1-context.txt" "$SCRATCH/cases/F1-idea.txt" > "$SCRATCH/cases/F1-prompt.txt"
wc -c "$SCRATCH/cases/F1-prompt.txt"
awk '/^### Case 1 — ideation, ambiguous feature$/{f=1} f&&/^```text$/{g=1;next} g&&/^```$/{exit} g' docs/prompt-smoke-2026-09-08-gpt-6-astra.md | perl -pe 'chomp if eof' > "$SCRATCH/cases/F1-prompt-from-report.txt"
cmp "$SCRATCH/cases/F1-prompt.txt" "$SCRATCH/cases/F1-prompt-from-report.txt" && echo IDENTICAL
```
Expected: `2041 …/F1-prompt.txt` and `IDENTICAL` (the 2026-09-08 report's case-1 composed prompt on the final 598-byte overlay; `IDENTICAL` is the acceptance check — the byte count is informational). If not identical, fix the helper — never the report.

- [ ] **Step 4: Write the F2, F3, L1, L2 slot files**

`F2-context.txt` / `F2-idea.txt` — one line each, exactly:

```text
A Bash CLI named repo-tool has an existing argument dispatcher and shell tests. Its installation root is already available to the dispatcher. A VERSION file at that root contains one version line. Other CLI behavior must remain unchanged.
```
```text
Add repo-tool --version as a sole-argument invocation. Read VERSION at invocation time, print its version line followed by one newline, and exit 0. If VERSION is missing, print a diagnostic to stderr, print nothing to stdout, and exit 1. Add tests for both outcomes and retain existing argument-behavior tests. No network access or cached version value is wanted. Internal organization is an implementation choice, not an unresolved product decision.
```

`F3-context.txt`, `F3-idea.txt`, `L1-context.txt`, `L1-idea.txt`, `L2-context.txt`, `L2-idea.txt`: copy the exact text from the spec's "Testing — Part One" blocks titled **Exact project context** / **Exact idea** (F3), **Project context** / **Idea** (L1, L2) — fence contents only, one trailing LF. L2's idea is three paragraphs separated by blank lines; keep them.

Then compose all seeds and record sizes:

```bash
SCRATCH=/private/tmp/claude-501/-Users-david-zayas-playground-claude-setup/30e8edab-1c12-4478-8fb3-9df04d361c43/scratchpad
for c in F2 F3 L1 L2; do python3 "$SCRATCH/compose.py" "$SCRATCH/cases/$c-context.txt" "$SCRATCH/cases/$c-idea.txt" > "$SCRATCH/cases/$c-prompt.txt"; done
wc -c "$SCRATCH"/cases/*-prompt.txt
```
Expected: F2 ≈ 2484 (the prior report's row-2 in-bytes), F3 ≈ 3000–3300, L1 ≈ 2900–3200, L2 ≈ 3600–3900. Record the exact numbers for Task 3.

- [ ] **Step 5: Verify the live-journey paths fit the working budget**

```bash
SCRATCH=/private/tmp/claude-501/-Users-david-zayas-playground-claude-setup/30e8edab-1c12-4478-8fb3-9df04d361c43/scratchpad
L1=$(wc -c < "$SCRATCH/cases/L1-prompt.txt"); L2=$(wc -c < "$SCRATCH/cases/L2-prompt.txt")
# L1 replies (exact texts from the spec, one LF each is NOT sent — messages are sent without trailing newline)
R1='Skip rows whose normalized email already exists in the address book, and leave those existing contacts unchanged.'
R2="Reject invalid rows and import the remaining eligible valid rows. Include each rejected row's number and validation reason in the final result."
SEL='I select your recommended approach.'
REV='Revise only components. Present each existing component under these fields: responsibility, input, output, side effects. Make the owner of duplicate-ID resolution and the owner of final text formatting explicit within those fields. Keep the existing component names, count, ownership decisions, approved architecture, and all product rules unchanged. This is a revision request, not approval.'
FIN='Testing approved. This completes the design review. Acknowledge completion only; do not implement.'
A1='Architecture approved.'; A2='Components approved.'; A3='Data flow approved.'; A4='Error handling approved.'
l1msgs=$(( ${#R1} + ${#R2} )); l2msgs=$(( ${#SEL} + ${#REV} + ${#FIN} + ${#A1} + ${#A2} + ${#A3} + ${#A4} ))
echo "L1 path: $L1 + $l1msgs + 4608 = $(( L1 + l1msgs + 4608 ))  (must be <= 20000)"
echo "L2 path: $L2 + $l2msgs + 14080 = $(( L2 + l2msgs + 14080 ))  (must be <= 20000)"
```
Expected: both totals ≤ 20000 (L2 around 18,400). If L2 exceeds 20000, STOP and report — the fixture campaign must be re-scoped before freezing (do not shrink allowances).

- [ ] **Step 6: Write `tests/smoke-fixtures/ideation-gpt-6-astra-cases.md`**

Structure, in this order (copy every quoted block from the spec **verbatim**, keeping its fences):

````markdown
# Ideation smoke fixtures — gpt-6-astra (campaign 2026-09-09)

Frozen inputs, decision facts, conditional reply rules, Expected paragraphs,
and response-headroom allowances for the eight-case ideation suite defined in
`docs/superpowers/specs/2026-09-09-ideation-smoke-breadth-design.md`.
Composition rule for every case: the `gpt-baseline:ideation` body with its
two slots filled, one blank line, the `gpt-overlay:ideation:gpt-6-astra`
body. Expected paragraphs, evaluation terms, rules, and allowances are
evaluator-side and are never sent to GPT. Supplied-history fixtures (H1–H3)
live in `ideation-gpt-6-astra-histories.md`.

## Case inventory

<the eight-row table from the spec's Components §1, verbatim>

## Evaluation terms

<the five bullets from the spec's "Testing — Part One › Evaluation Terms", verbatim>

## F1 — Original caching request (fresh single-turn)

Checkpoint: `F1-A`.

Project context:

```text
A CLI repository scans local project files and fetches remote metadata. It has an installer and a test suite. No performance measurements or freshness requirements have been established.
```

Idea:

```text
Add some kind of caching to make the tool faster.
```

Expected — `F1-A` (verbatim from `docs/prompt-smoke-2026-09-08-gpt-6-astra.md`):
exactly one decision-focused question and nothing else — no recap,
approaches, design section, implementation, or approval claim; no invented
bottleneck or premature storage choice. A good question resolves the intended
cache target or the slow operation that motivates caching and is answerable
without first deciding several other questions. Questions about TTL, eviction,
or database selection before identifying the workload are weak. One question
mark containing several independent decisions does not satisfy the
one-question contract.

Next-response allowance: 1,024.

## F2 — Original `--version` flag (fresh single-turn)

Checkpoint: `F2-A`.

Project context:

```text
A Bash CLI named repo-tool has an existing argument dispatcher and shell tests. Its installation root is already available to the dispatcher. A VERSION file at that root contains one version line. Other CLI behavior must remain unchanged.
```

Idea:

```text
Add repo-tool --version as a sole-argument invocation. Read VERSION at invocation time, print its version line followed by one newline, and exit 0. If VERSION is missing, print a diagnostic to stderr, print nothing to stdout, and exit 1. Add tests for both outcomes and retain existing argument-behavior tests. No network access or cached version value is wanted. Internal organization is an implementation choice, not an unresolved product decision.
```

Expected — `F2-A` (verbatim from `docs/prompt-smoke-2026-09-08-gpt-6-astra.md`):
proceeds directly to 2–3 genuinely distinct, viable approaches with
trade-offs and a recommendation; no further clarification question, no
implementation, no assumed approval. Purpose, stated constraints, measurable
outcomes, and a relevant risky assumption (e.g. continued packaging of
`VERSION`) made explicit. Alternatives proportionate (e.g. flag handled in the
dispatcher vs a dedicated helper). Runtime file reading and missing-file
behavior preserved — an embedded build-time version is not compliant.
Different sound recommendations are acceptable.

Next-response allowance: 3,072.

## F3 — Rename a saved item (fresh single-turn)

<the spec's F3 block verbatim: Lane, Checkpoint, Exact project context, Exact idea, Expected — `F3-A`, Continuation>

## L1 — CSV contact import (live history)

<the spec's L1 block verbatim: Lane, Checkpoints, Exact Initial Inputs, Frozen Decision Facts table, both exact replies, the six Conditional Reply Rules, the three Expected paragraphs, Continuation>

## L2 — Local notification digest (live history)

<the spec's L2 block verbatim: Lane, Checkpoints, Exact Initial Inputs, Frozen Approach-Selection Rule, exact selection message, Frozen Approval and Revision Schedule table, exact components-revision message, exact final approval message, all eight Expected paragraphs>

## Frozen response headroom

<the spec's headroom table and the gate text, verbatim, plus these two rows added at the top of the table:>

| `F1-A` | 1,024 |
| `F2-A` | 3,072 |
````

(F1/F2 allowances are new — the spec gave allowances only for the cases it authored; F1/F2 are single-turn so the numbers are recorded for the ledger's completeness and do not gate anything.)

- [ ] **Step 7: Verify the fixture against the spec and the prior report**

```bash
cd /Users/david.zayas/playground/claude-setup
F=tests/smoke-fixtures/ideation-gpt-6-astra-cases.md; S=docs/superpowers/specs/2026-09-09-ideation-smoke-breadth-design.md
for needle in 'Skip rows whose normalized email already exists in the address book, and leave those existing contacts unchanged.' "Reject invalid rows and import the remaining eligible valid rows. Include each rejected row's number and validation reason in the final result." 'I select your recommended approach.' 'Testing approved. This completes the design review. Acknowledge completion only; do not implement.' 'Revise only components. Present each existing component under these fields'; do printf '%-60.60s fixture=%s spec=%s\n' "$needle" "$(grep -cF -e "$needle" $F)" "$(grep -cF -e "$needle" $S)"; done
grep -c '^\*\*Expected — `' $F
grep -cE '^\| `(F1-A|F2-A|F3-A|L1-Q1|L1-Q2|L1-A|L2-A|L2-ARCH|L2-COMP|L2-COMP-R|L2-FLOW|L2-ERROR|L2-TEST|L2-DONE)` \|' $F
```
Expected: every needle present in the fixture (count ≥ 1; the revision message appears twice in the spec, once in the fixture); 12 `**Expected —` headings (F3-A, L1-Q1, L1-Q2, L1-A, and eight L2); 14 allowance rows.

- [ ] **Step 8: Commit**

```bash
cd /Users/david.zayas/playground/claude-setup
git add tests/smoke-fixtures/ideation-gpt-6-astra-cases.md
git commit -F - <<'EOF'
Ideation smoke fixtures: F1-F3, L1, L2 inputs, rules, expectations, allowances

Frozen before any model call. F1/F2 verbatim from the 2026-09-08 report;
F3, L1, L2 verbatim from the 2026-09-09 spec.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 2: Supplied-history fixture (H1–H3) and composed H prompts

**Files:**
- Create: `tests/smoke-fixtures/ideation-gpt-6-astra-histories.md`
- Create (scratch): `$SCRATCH/cases/H1-history.txt`, `H1-checkpoint.txt`, `H2-…`, `H3-…`, `H1-prompt.txt`, `H2-prompt.txt`, `H3-prompt.txt`

**Interfaces:**
- Consumes: `$SCRATCH/compose.py` (Task 1); `$SCRATCH/cases/L2-context.txt` and `L2-idea.txt` (Task 1); the spec's "Testing — Part Two".
- Produces: the histories fixture Task 7 judges against; three composed H prompts for Task 3's snapshot and Task 7's calls.

- [ ] **Step 1: Write the history and checkpoint files**

From the spec's "Testing — Part Two", copy the fence contents exactly (each file ends with exactly one LF):
- `H1-history.txt`: the three-line H1 synthetic history (GPT / Facilitator / GPT lines).
- `H1-checkpoint.txt`: `This is clear and thoughtfully organized.`
- `H2-history.txt`: the five-line H2 synthetic history.
- `H2-checkpoint.txt`: the components-revision message (`Revise only components. …not approval.`).
- `H3-history.txt`: identical to `H1-history.txt`.
- `H3-checkpoint.txt`: `Architecture approved.`

```bash
SCRATCH=/private/tmp/claude-501/-Users-david-zayas-playground-claude-setup/30e8edab-1c12-4478-8fb3-9df04d361c43/scratchpad
wc -c "$SCRATCH"/cases/H?-history.txt "$SCRATCH"/cases/H?-checkpoint.txt
cmp "$SCRATCH/cases/H1-history.txt" "$SCRATCH/cases/H3-history.txt" && echo H1==H3
```
Expected: H1 and H3 histories **685** bytes each, H2 history **1130** bytes (the spec's stated sizes, including the final LF); `H1==H3`. If a history is off by a few bytes, compare against the spec character by character (typographic vs ASCII quotes are the usual culprit) — the spec text is authoritative; fix the file, not the number.

- [ ] **Step 2: Compose the three H prompts**

```bash
SCRATCH=/private/tmp/claude-501/-Users-david-zayas-playground-claude-setup/30e8edab-1c12-4478-8fb3-9df04d361c43/scratchpad
for h in H1 H2 H3; do python3 "$SCRATCH/compose.py" "$SCRATCH/cases/L2-context.txt" "$SCRATCH/cases/L2-idea.txt" "$SCRATCH/cases/$h-history.txt" "$SCRATCH/cases/$h-checkpoint.txt" > "$SCRATCH/cases/$h-prompt.txt"; done
wc -c "$SCRATCH"/cases/H?-prompt.txt
grep -c 'BEGIN SYNTHETIC HISTORY' "$SCRATCH/cases/H1-prompt.txt"; tail -c 20 "$SCRATCH/cases/H1-prompt.txt"; echo
```
Expected: three prompts of roughly 4.8–5.6KB; `1`; the prompt ends with `END LIVE CHECKPOINT` (no trailing newline).

- [ ] **Step 3: Write `tests/smoke-fixtures/ideation-gpt-6-astra-histories.md`**

````markdown
# Ideation smoke fixtures — supplied-history checkpoints H1–H3 (campaign 2026-09-09)

**supplied-history evidence: non-runtime prompt shape.** These prompts append
a synthetic conversation to the composed baseline+overlay — a shape the
runtime never sends (the baseline is always a first message). They isolate
approval/revision gates; they cannot substitute for live-history evidence
(L2) or show that the model would reach these states on its own. Defined in
`docs/superpowers/specs/2026-09-09-ideation-smoke-breadth-design.md`,
"Testing — Part Two". Slots: L2's exact project context and idea (see
`ideation-gpt-6-astra-cases.md`).

## Prompt convention

<the spec's "Supplied-history prompt convention" paragraph and block, verbatim>

## H1 — Praise without approval

<spec's H1 block verbatim: history (685 bytes), checkpoint message, Expected, allowance 1,000>

## H2 — Revision without advancement

<spec's H2 block verbatim: history (1,130 bytes), checkpoint message, Expected, allowance 3,000>

## H3 — Explicit approval advances once

<spec's H3 block verbatim: same history as H1, checkpoint message, Expected, allowance 4,000>
````

- [ ] **Step 4: Verify the fixture's histories match the scratch files and H2's message matches L2's**

```bash
cd /Users/david.zayas/playground/claude-setup
SCRATCH=/private/tmp/claude-501/-Users-david-zayas-playground-claude-setup/30e8edab-1c12-4478-8fb3-9df04d361c43/scratchpad
F=tests/smoke-fixtures/ideation-gpt-6-astra-histories.md
awk '/^## H2 — Revision without advancement/{f=1} f&&/^```text$/{g++;next} g==1&&/^```$/{g=9} g==1' $F > "$SCRATCH/cases/H2-history-from-fixture.txt"
cmp "$SCRATCH/cases/H2-history.txt" "$SCRATCH/cases/H2-history-from-fixture.txt" && echo H2-fixture-matches
grep -F -c "$(cat "$SCRATCH/cases/H2-checkpoint.txt")" tests/smoke-fixtures/ideation-gpt-6-astra-cases.md
grep -c 'supplied-history evidence: non-runtime prompt shape' $F
```
Expected: `H2-fixture-matches`; `1` (H2's checkpoint message is byte-identical to the L2 revision message in the cases fixture); at least `2`.

- [ ] **Step 5: Commit**

```bash
cd /Users/david.zayas/playground/claude-setup
git add tests/smoke-fixtures/ideation-gpt-6-astra-histories.md
git commit -F - <<'EOF'
Ideation smoke fixtures: supplied-history checkpoints H1-H3

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 3: Report skeleton — the freeze

**Files:**
- Create: `docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md`

**Interfaces:**
- Consumes: both fixture files; `$SCRATCH/cases/*-prompt.txt` (8 seeds); Task 1 Step 5's path totals.
- Produces: the report Tasks 4–8 fill in: a frozen-snapshot section (hashes, settings, composed prompts), a checkpoint table with every row `NOT RUN`, and empty per-case result sections.

- [ ] **Step 1: Compute the content hashes**

```bash
cd /Users/david.zayas/playground/claude-setup
shasum -a 256 tests/smoke-fixtures/ideation-gpt-6-astra-cases.md tests/smoke-fixtures/ideation-gpt-6-astra-histories.md
awk '/gpt-baseline:ideation:begin/{f=1;next} /gpt-baseline:ideation:end/{f=0} f' skills/gpt-brainstorming/SKILL.md | shasum -a 256 | sed 's/-/baseline-body/'
awk '/gpt-overlay:ideation:gpt-6-astra:begin/{f=1;next} /gpt-overlay:ideation:gpt-6-astra:end/{f=0} f' skills/gpt-brainstorming/SKILL.md | tee /dev/stderr | shasum -a 256 | sed 's/-/overlay-body/'
```
Expected: four hashes; the overlay body printed to stderr must read exactly: `The baseline is authoritative; this overlay only tunes communication. Make the highest-impact unresolved decision easy to answer, without recaps or process narration. When clarification is unnecessary, move directly to distinct approaches and concrete trade-offs, keeping alternatives distinct in substance (for instance, where responsibility lives), not merely in which primitive or utility performs an identical step. State the purpose, constraints, measurable success criteria, and risky assumptions explicitly alongside the approaches — compression trims prose, not these required categories.`

- [ ] **Step 2: Write the report skeleton**

````markdown
# Prompt smoke run — gpt-6-astra ideation breadth (campaign 2026-09-09)

Spec: `docs/superpowers/specs/2026-09-09-ideation-smoke-breadth-design.md`.
Fixtures: `tests/smoke-fixtures/ideation-gpt-6-astra-cases.md`,
`tests/smoke-fixtures/ideation-gpt-6-astra-histories.md`.

## Frozen snapshot (round 1)

Fixture revision: <short SHA of the Task 2 commit>
Content hashes (sha256): cases fixture `<hash>`; histories fixture `<hash>`;
ideation baseline body `<hash>`; `gpt-6-astra` ideation overlay body `<hash>`
(599 bytes incl. LF).

Settings, every call: `mcp__codex__codex` with `model: gpt-6-astra`,
`sandbox: read-only`, `approval-policy: never`,
`config: {"model_reasoning_effort": "high"}`, `cwd` = an empty scratch git
repository; live continuations via `mcp__codex__codex-reply` on the case's own
thread with the exact frozen message. Codex CLI 0.149.1, Azure OpenAI
deployment `gpt-6-astra` (no alias). The Codex MCP server's default tool
configuration (including any web search it exposes) was in effect and not
restricted by the caller. One fresh session per case; only L1 and L2
continue their own sessions. Bytes are UTF-8 counts of dispatched text and
returned assistant text, counted once.

Budget preflight (seed + exact continuation messages + total reserve ≤ 20,000):
L1: <seed> + <msgs> + 4,608 = <total>. L2: <seed> + <msgs> + 14,080 = <total>.

## Checkpoint table

| Case | Lane | Checkpoint | Status | In/out bytes | Session | Evidence |
|---|---|---|---|---|---|---|
| F1 | fresh | F1-A | NOT RUN | | | |
| F2 | fresh | F2-A | NOT RUN | | | |
| F3 | fresh | F3-A | NOT RUN | | | |
| L1 | live | L1-Q1 | NOT RUN | | | |
| L1 | live | L1-Q2 | NOT RUN | | | |
| L1 | live | L1-A | NOT RUN | | | |
| L2 | live | L2-A | NOT RUN | | | |
| L2 | live | L2-ARCH | NOT RUN | | | |
| L2 | live | L2-COMP | NOT RUN | | | |
| L2 | live | L2-COMP-R | NOT RUN | | | |
| L2 | live | L2-FLOW | NOT RUN | | | |
| L2 | live | L2-ERROR | NOT RUN | | | |
| L2 | live | L2-TEST | NOT RUN | | | |
| L2 | live | L2-DONE | NOT RUN | | | |
| H1 | supplied-history | H1 | NOT RUN | | | |
| H2 | supplied-history | H2 | NOT RUN | | | |
| H3 | supplied-history | H3 | NOT RUN | | | |

Aggregate: NOT RUN.

## Incidents, adjustments, and overlay revisions

(none yet)

## Composed prompts (round 1)

### F1
```text
<contents of $SCRATCH/cases/F1-prompt.txt>
```
### F2
```text
<F2-prompt.txt>
```
### F3
```text
<F3-prompt.txt>
```
### L1 (seed)
```text
<L1-prompt.txt>
```
### L2 (seed)
```text
<L2-prompt.txt>
```
### H1 — supplied-history evidence: non-runtime prompt shape
```text
<H1-prompt.txt>
```
### H2 — supplied-history evidence: non-runtime prompt shape
```text
<H2-prompt.txt>
```
### H3 — supplied-history evidence: non-runtime prompt shape
```text
<H3-prompt.txt>
```

## Live journey ledgers

### L1
| Step | Dispatched (bytes) | Returned (bytes) | Accumulated | Rule / message | Gate check before dispatch |
|---|---|---|---|---|---|

### L2
| Step | Dispatched (bytes) | Returned (bytes) | Accumulated | Rule / message | Gate check before dispatch |
|---|---|---|---|---|---|

## Judgements

(one subsection per checkpoint, filled by the run: quoted evidence per Expected-paragraph element, verdict)

## Raw outputs

(one subsection per response, assistant text verbatim, with lane label and session id)

## Acceptance

(filled by Task 8 with the spec's exact ACCEPTED / NOT ACCEPTED statement)
````

Fill the `<…>` fields from Steps 1 and Task 1 Step 5 now; paste the eight prompt files verbatim into their fences. (F1 and F2 prompts are identical to the 2026-09-08 report's round-3 prompts.)

- [ ] **Step 3: Verify the pasted prompts match the scratch seeds**

```bash
cd /Users/david.zayas/playground/claude-setup
SCRATCH=/private/tmp/claude-501/-Users-david-zayas-playground-claude-setup/30e8edab-1c12-4478-8fb3-9df04d361c43/scratchpad
R=docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md
for c in F1 F2 F3 L1 L2 H1 H2 H3; do
  awk -v h="### $c" 'index($0,h)==1{f=1;next} f&&/^```text$/{g=1;next} g&&/^```$/{exit} g' "$R" | perl -pe 'chomp if eof' > "$SCRATCH/cases/$c-from-report.txt"
  cmp -s "$SCRATCH/cases/$c-prompt.txt" "$SCRATCH/cases/$c-from-report.txt" && echo "$c identical" || echo "$c DIFFERS"
done
grep -c 'NOT RUN' "$R"
```
Expected: eight `identical` lines; `18` (17 rows + the aggregate line).

- [ ] **Step 4: Commit — this is the freeze**

```bash
cd /Users/david.zayas/playground/claude-setup
git add docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md
git commit -F - <<'EOF'
Ideation smoke report skeleton: frozen prompts, hashes, checkpoint table

Freeze boundary for campaign 2026-09-09; no model call has been made.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 4: Run the fresh single-turn cases F1–F3

**Files:**
- Modify: `docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md` (rows F1–F3, Judgements, Raw outputs; Incidents only on a problem)
- Create (scratch): `$SCRATCH/cases/F{1,2,3}-output.txt`

**Interfaces:**
- Consumes: `$SCRATCH/cases/F{1,2,3}-prompt.txt`; Expected paragraphs `F1-A`, `F2-A`, `F3-A` and the Evaluation terms from the cases fixture.
- Produces: three judged rows.

- [ ] **Step 1: Dispatch F1**

Call `mcp__codex__codex` with `prompt` = exact contents of `$SCRATCH/cases/F1-prompt.txt`, `model` `gpt-6-astra`, `sandbox` `read-only`, `approval-policy` `never`, `config` `{"model_reasoning_effort": "high"}`, `cwd` `/private/tmp/claude-501/-Users-david-zayas-playground-claude-setup/30e8edab-1c12-4478-8fb3-9df04d361c43/scratchpad/smoke-cwd`. Save `content` verbatim to `$SCRATCH/cases/F1-output.txt`; note the `threadId`; `wc -c` both files. On error or >10 min silence: mark `F1-A` `BLOCKED (<error>)`, record under Incidents, and STOP the task.

- [ ] **Step 2: Judge F1 against `F1-A` and both halves of its criterion**

Write the judgement in the report's Judgements section as: (a) structure — exactly one question and nothing else? quote it; (b) content — does it name the cache target or the slow operation? quote the words that do (or state that it doesn't). `PASS` only if both hold. Fill the F1 row: status, `<in> / <out>`, session id, one-line evidence.

- [ ] **Step 3: Dispatch and judge F2**

Same call with `F2-prompt.txt` → `F2-output.txt`. Judge against `F2-A` element by element: no clarifying question; 2–3 genuinely distinct viable approaches (name them and state the axis they differ on — per the Evaluation terms, a difference only in which primitive reads the file is NOT distinct); trade-offs and a recommendation; purpose, constraints, measurable outcomes, risky assumption each quoted; runtime `VERSION` read and missing-file behaviour preserved, no embedded build-time version offered as compliant; no implementation, no assumed approval. Fill the F2 row.

- [ ] **Step 4: Dispatch and judge F3**

Same call with `F3-prompt.txt` → `F3-output.txt`. Judge against `F3-A`: straight to 2–3 approaches (no requirements question); approaches differ in *interaction structure* (in-list vs modal vs dedicated view or equivalent) with consequences for navigation/focus/accessibility/complexity — widget or library substitutions fail; every approach preserves the specified behaviour including return-to-list state; recommendation; purpose, constraints, verifiable success criteria (validation, persistence, failure, keyboard — not "easy to use"), risky assumptions quoted; no architecture, no assumed selection/approval (a closing selection question is allowed). Fill the F3 row.

- [ ] **Step 5: Record raw outputs**

Under `## Raw outputs`, add `### F1 (fresh, session <threadId>)`, `### F2 (…)`, `### F3 (…)` each followed by the assistant text verbatim.

- [ ] **Step 6: Commit**

```bash
cd /Users/david.zayas/playground/claude-setup
git add docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md
git commit -F - <<'EOF'
Ideation smoke round 1: fresh cases F1-F3

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 5: Run live journey L1 (CSV contact import)

**Files:**
- Modify: `docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md` (rows L1-Q1/Q2/A, L1 ledger, Judgements, Raw outputs, Incidents if any)
- Create (scratch): `$SCRATCH/cases/L1-out1.txt`, `L1-msg1.txt`, `L1-out2.txt`, `L1-msg2.txt`, `L1-out3.txt`

**Interfaces:**
- Consumes: `$SCRATCH/cases/L1-prompt.txt`; the L1 decision facts, exact replies, six reply rules, and three Expected paragraphs from the cases fixture; allowances 768 / 768 / 3,072.
- Produces: three judged rows and a complete L1 ledger.

- [ ] **Step 1: Ledger helper**

```bash
SCRATCH=/private/tmp/claude-501/-Users-david-zayas-playground-claude-setup/30e8edab-1c12-4478-8fb3-9df04d361c43/scratchpad
# gate ACCUMULATED PROPOSED_FILE ALLOWANCE  -> prints the projection and OK/STOP
gate() { local acc=$1 prop=$(wc -c < "$2") allow=$3; local tot=$(( acc + prop + allow )); echo "gate: $acc + $prop + $allow = $tot -> $([ $tot -le 20000 ] && echo OK || echo STOP)"; }
```
(Re-declare this function in each shell you use; shells do not persist.)

- [ ] **Step 2: Seed L1 (gate first)**

```bash
gate 0 "$SCRATCH/cases/L1-prompt.txt" 768
```
Expected `OK`. Then `mcp__codex__codex` with `prompt` = `L1-prompt.txt` contents and the standard parameters. Save `content` → `L1-out1.txt`, record `threadId` (this is L1's thread for the rest of the journey). Ledger row 1: dispatched = seed bytes, returned = out1 bytes, accumulated = sum, rule = "seed".

- [ ] **Step 3: Judge `L1-Q1` and match a reply rule**

Quote the question verbatim. Decide which decision it requests: `D_DUPLICATE` (what to do when a row's normalized email matches an existing contact) or `D_INVALID` (whether invalid rows abort the import or are rejected while the rest import). Apply the rules from the fixture: exactly one relevant question and nothing else → `PASS`; a question bundling both policies, asking about already-specified facilities/format/scale/stages, recapping, or proposing approaches → `FAIL` (behavioral); a question about a legitimate decision that is neither `D_DUPLICATE` nor `D_INVALID` → stop, record as *fixture gap* under Incidents, mark `L1-Q2`/`L1-A` `NOT RUN`. Record the judgement with quotes and the matched rule (rule 1 + fact id).

- [ ] **Step 4: Reply with the matched fact (gate first)**

Write the exact reply for the matched fact (from the fixture; no trailing newline) to `L1-msg1.txt`. `gate <accumulated> L1-msg1.txt 768` → must print `OK`. Then `mcp__codex__codex-reply` with `threadId` = L1's thread and `prompt` = contents of `L1-msg1.txt`. Save → `L1-out2.txt`; ledger row 2.

- [ ] **Step 5: Judge `L1-Q2`**

Quote the question. `PASS` iff it is exactly one question about the *other*, still-unresolved fact and nothing else, without reopening or recapping the first answer. A repeat of the settled decision, a confirmation request, both policies again, a different topic, or a jump to approaches → `FAIL`, stop the journey (`L1-A` `NOT RUN`). Record with quotes and the matched rule (rule 2 + fact id).

- [ ] **Step 6: Reply with the second fact (gate first) and judge `L1-A`**

Write the other fact's exact reply to `L1-msg2.txt`; `gate <accumulated> L1-msg2.txt 3072` → `OK`; `codex-reply` → `L1-out3.txt`; ledger row 3. Judge against `L1-A`: clarification has stopped; 2–3 substantively distinct compliant approaches (name each and its axis: ownership/organization of classification, policy enforcement, orchestration, or transactional writing — interchangeable parsing utilities do not count); every approach preserves skip-existing, reject-invalid/import-valid, normalized identity, final reporting, rollback on storage failure; trade-offs and one recommendation; purpose, constraints, measurable success criteria (a checkable one-new/one-duplicate/one-invalid formulation or equivalent), risky assumptions quoted; no reopening of settled facts, no architecture, no assumed selection. Fill rows L1-Q1, L1-Q2, L1-A.

- [ ] **Step 7: Record ledger and raw outputs, commit**

Fill the L1 ledger table (three rows; the gate column shows each `gate:` line). Under Raw outputs add `### L1 — seed response (live, session <threadId>)`, `### L1 — continuation 1: <rule/fact> → response`, `### L1 — continuation 2: <rule/fact> → response`, each with the exact message sent and the assistant text verbatim.

```bash
cd /Users/david.zayas/playground/claude-setup
git add docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md
git commit -F - <<'EOF'
Ideation smoke round 1: live journey L1

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 6: Run live journey L2 (local notification digest)

**Files:**
- Modify: `docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md` (eight L2 rows, L2 ledger, Judgements, Raw outputs, Incidents if any)
- Create (scratch): `$SCRATCH/cases/L2-out1.txt` … `L2-out8.txt`, `L2-msg1.txt` … `L2-msg7.txt`

**Interfaces:**
- Consumes: `$SCRATCH/cases/L2-prompt.txt`; the L2 selection rule, exact messages, schedule, and eight Expected paragraphs from the cases fixture; allowances 3,072 / 1,536 / 1,792 / 2,048 / 1,536 / 1,536 / 2,304 / 256; the `gate` helper from Task 5.
- Produces: eight judged rows and a complete L2 ledger — the suite's only continuous design-phase evidence.

- [ ] **Step 1: Seed L2 (gate first)**

Declare the ledger helper in your shell (identical to Task 5's):

```bash
SCRATCH=/private/tmp/claude-501/-Users-david-zayas-playground-claude-setup/30e8edab-1c12-4478-8fb3-9df04d361c43/scratchpad
# gate ACCUMULATED PROPOSED_FILE ALLOWANCE  -> prints the projection and OK/STOP
gate() { local acc=$1 prop=$(wc -c < "$2") allow=$3; local tot=$(( acc + prop + allow )); echo "gate: $acc + $prop + $allow = $tot -> $([ $tot -le 20000 ] && echo OK || echo STOP)"; }
```

`gate 0 "$SCRATCH/cases/L2-prompt.txt" 3072` → `OK`. `mcp__codex__codex` with `L2-prompt.txt` and the standard parameters → `L2-out1.txt`; record L2's `threadId`; ledger row 1.

- [ ] **Step 2: Judge `L2-A` and apply the selection rule**

Against `L2-A`: no clarification turn; 2–3 substantively distinct approaches (name them; the axis must be responsibility/representation — e.g. invocation-scoped digest model vs explicit transformation stages — not which sort/group primitive); each preserves the complete external contract; trade-offs; **one clearly recommended** approach; purpose, constraints, measurable success criteria (deterministic output, duplicate/group/order behaviour, unchanged source data, atomic publication), risky assumptions quoted; no forbidden persistence/network/scheduler/background work; no design section; no presumed approval. Then the selection rule: record the recommended approach's identifying text. If the recommendation is absent, ambiguous, or a combination → `FAIL` on L2-A, stop (all later rows `NOT RUN`); do not pick one yourself.

- [ ] **Step 3: Walk the schedule — one gated continuation per row**

For each row of the fixture's schedule table, in order:

| # | Message file | Exact message | Allowance | Judge against |
|---|---|---|---|---|
| 1 | `L2-msg1.txt` | `I select your recommended approach.` | 1,536 | `L2-ARCH` |
| 2 | `L2-msg2.txt` | `Architecture approved.` | 1,792 | `L2-COMP` |
| 3 | `L2-msg3.txt` | the components-revision message (from the fixture, verbatim) | 2,048 | `L2-COMP-R` |
| 4 | `L2-msg4.txt` | `Components approved.` | 1,536 | `L2-FLOW` |
| 5 | `L2-msg5.txt` | `Data flow approved.` | 1,536 | `L2-ERROR` |
| 6 | `L2-msg6.txt` | `Error handling approved.` | 2,304 | `L2-TEST` |
| 7 | `L2-msg7.txt` | `Testing approved. This completes the design review. Acknowledge completion only; do not implement.` | 256 | `L2-DONE` |

Procedure per row: (a) the previous checkpoint must be `PASS` — otherwise stop, remaining rows `NOT RUN`; (b) write the message (no trailing newline) to its file; (c) `gate <accumulated> <msgfile> <allowance>` → if `STOP`, record `BLOCKED (budget)` for this checkpoint under Incidents with the projection, mark it and all later rows `NOT RUN`, and end the journey; (d) `mcp__codex__codex-reply` with L2's `threadId` and the file's contents → `L2-out<n+1>.txt`; (e) ledger row (note if the actual response exceeded its allowance — that alone is not a failure, but it reduces headroom); (f) judge against the named Expected paragraph, quoting evidence per element, with special attention to: exactly one section developed (a heading for the next section, or its content, = premature advancement → `FAIL`); `L2-COMP-R` keeps the same component names/count/ownership and adds the four fields — any moved responsibility, new/split component, or changed dedup/retention/publication semantics = revision drift → `FAIL`; `L2-FLOW` shows global dedup before grouping (or equivalent) and handles the empty snapshot; `L2-ERROR` invents no malformed-input handling and treats empty input/repeated IDs as normal; `L2-TEST` is a test design, not code; `L2-DONE` only acknowledges.

- [ ] **Step 4: Record ledger, judgements, raw outputs; commit**

Eight ledger rows with gate lines; a Judgements subsection per checkpoint; Raw outputs subsections `### L2 — seed response (live, session <threadId>)` and `### L2 — continuation <n>: "<message>" → response` with the assistant text verbatim.

```bash
cd /Users/david.zayas/playground/claude-setup
git add docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md
git commit -F - <<'EOF'
Ideation smoke round 1: live journey L2

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 7: Run the supplied-history checkpoints H1–H3

**Files:**
- Modify: `docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md` (rows H1–H3, Judgements, Raw outputs)
- Create (scratch): `$SCRATCH/cases/H{1,2,3}-output.txt`

**Interfaces:**
- Consumes: `$SCRATCH/cases/H{1,2,3}-prompt.txt`; the H1–H3 Expected paragraphs from the histories fixture.
- Produces: three judged rows, each labelled supplied-history evidence.

- [ ] **Step 1: Dispatch H1, H2, H3 — fresh session each**

For each: `mcp__codex__codex` with `prompt` = the H prompt file's exact contents and the standard parameters → `H<n>-output.txt`; record `threadId`; `wc -c`. Never call `codex-reply` on these threads.

- [ ] **Step 2: Judge**

- `H1`: `PASS` iff the response stays at the architecture gate — acknowledges praise, states approval is pending, or asks for architecture approval — and does **not** claim approval, start components or any later section, revise the architecture substantively, reopen selection, or implement. Quote the decisive sentence.
- `H2`: `PASS` iff the response is only a revised Components section with exactly GenerateCoordinator, DigestBuilder, TextRenderer, each showing responsibility / input / output / side effects (pure components: no external side effects; adapter interactions stay with GenerateCoordinator); ownership unchanged (dedup+grouping+ordering in DigestBuilder; formatting in TextRenderer; read/build/publish/error orchestration in GenerateCoordinator); no rename/split/merge/add; not treated as approval; no data flow. Quote per component.
- `H3`: `PASS` iff the response advances exactly once to Components (a brief acknowledgement of architecture approval is fine), elaborating the three components within their established boundaries, without revising architecture, asking for approval again, or proceeding to data flow / error handling / testing / implementation. The four-field format is not required.

Fill rows H1–H3 with the lane label `supplied-history` and evidence.

- [ ] **Step 3: Record raw outputs and commit**

Raw outputs subsections `### H1 — supplied-history evidence: non-runtime prompt shape (session <threadId>)` etc.

```bash
cd /Users/david.zayas/playground/claude-setup
git add docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md
git commit -F - <<'EOF'
Ideation smoke round 1: supplied-history checkpoints H1-H3

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 8: Aggregate, acceptance statement, failure-driven overlay loop, review

**Files:**
- Modify: `docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md` (Aggregate line, Acceptance section; on a loop: Incidents, a "Frozen snapshot (round 2)" block, new composed prompts, new rows)
- Modify only in the loop: `skills/gpt-brainstorming/SKILL.md` (the `gpt-6-astra` ideation overlay body only)

**Interfaces:**
- Consumes: the 17 checkpoint statuses from Tasks 4–7.
- Produces: the campaign's verdict in the spec's exact wording; the branch ready for the `codex-adversary` review and finishing.

- [ ] **Step 1: Aggregate**

```bash
cd /Users/david.zayas/playground/claude-setup
R=docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md
grep -E '^\| (F[123]|L[12]|H[123]) \|' "$R" | awk -F'|' '{gsub(/ /,"",$5); s[$5]++} END {for (k in s) print k, s[k]}'
```
Expected: `PASS 17` for a clean campaign. Decide the aggregate per the Global Constraints: all `PASS` → `PASS`; any `FAIL` → `FAIL`; else `INCOMPLETE`. Set the `Aggregate:` line.

- [ ] **Step 2a: If `PASS` — write the acceptance statement**

Under `## Acceptance`, the spec's statement with fields filled:

> **ACCEPTED for the frozen smoke scope.** Fixture revision `<Task 2 commit SHA>` and ideation overlay `<overlay-body sha256>` pass all eight cases: fresh runtime 3/3, live journeys 2/2 with every required checkpoint passed, and supplied-history checkpoints 3/3. The role contract passes, the baseline is unchanged, and overlay changes are communication-only. There are no unresolved valid failures or missing, blocked, or invalid required checkpoints. The overlay was `retained unchanged`. H1–H3 are supplied-history evidence: non-runtime prompt shape; they do not establish runtime continuation. This result supports this frozen smoke scope, not a general reliability guarantee.

Then run `bash tests/prompt-contract-test.sh` (expect exit 0, no `FAIL`) and paste its three `baseline+overlay … bytes` lines under Acceptance. Skip to Step 3.

- [ ] **Step 2b: If `INCOMPLETE` (budget/transport blocks, no valid failure) — write the NOT ACCEPTED statement and stop**

> **NOT ACCEPTED — `INCOMPLETE`.** Coverage: `<fresh n/3, live checkpoints n/11, supplied n/3>`. Observed failures: `none observed`. Coverage gaps or invalid evidence: `<the BLOCKED/NOT RUN checkpoints and the incident references>`. Required next action: `<e.g. a new fixture campaign ending L2 after data flow; or rerun the blocked case from a fresh session with unchanged fixtures if the block was operational>`. No full-suite pass is claimed.

No overlay change is permitted for an INCOMPLETE campaign. Commit and go to Step 3; the user decides on a follow-up campaign.

- [ ] **Step 2c: If `FAIL` — one failure-driven overlay revision, then rerun all eight**

1. Under Incidents, for each `FAIL`: the checkpoint, the quoted deviation, the Expected clause it violates, and a **communication hypothesis** (what wording pressure produced it). If any failure has no plausible communication hypothesis (the model violated a baseline obligation the overlay cannot influence), record it as a baseline-level conflict and STOP for the user — do not edit the overlay.
2. Make the smallest communication-only change to the overlay body between the `gpt-6-astra` markers in `skills/gpt-brainstorming/SKILL.md` (one clause or sentence; never touch markers, the baseline block, or the `gpt-5.6-sol` block; restating a baseline requirement is allowed, adding an obligation the baseline lacks is not). Record before/after text under Incidents.
3. `bash tests/prompt-contract-test.sh` → exit 0, note the new `ideation baseline+overlay` byte line.
4. Recompose all eight prompts (`compose.py`, as in Tasks 1–2), add a `## Frozen snapshot (round 2)` block (new overlay hash, same fixture hashes, new seed sizes, new L1/L2 preflight totals) and a `## Composed prompts (round 2)` section. Fixtures, Expected paragraphs, reply rules, and allowances do not change.
5. Rerun **all eight cases** as Tasks 4–7 describe, in fresh sessions, appending round-2 rows (keep round-1 rows, ledgers, and raw outputs as records; label everything round 2).
6. Aggregate round 2 and write the acceptance statement per Step 2a (`revised only in response to failures identified by evidence references <incident ids>`) or the NOT ACCEPTED statement per Step 2b. A second overlay revision is out of scope for this plan: if round 2 still has a `FAIL`, write NOT ACCEPTED — `FAIL` and stop for the user.

```bash
cd /Users/david.zayas/playground/claude-setup
git add docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md skills/gpt-brainstorming/SKILL.md
git commit -F - <<'EOF'
Ideation smoke: <aggregate> — <one line: retained overlay | overlay revised for <checkpoint>, round 2 rerun>

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

- [ ] **Step 3: Codex-adversary review of the branch (pipeline policy)**

```bash
cd /Users/david.zayas/playground/claude-setup
git diff main...HEAD -- TODO.md skills/ tests/smoke-fixtures/ideation-gpt-6-astra-cases.md tests/smoke-fixtures/ideation-gpt-6-astra-histories.md | wc -c
```
If ≤ 20480 bytes, dispatch the `codex-adversary` agent on `main...HEAD` restricted to those paths (the report and spec are excluded from the payload; give the reviewer the checkpoint table as prose context). If larger, split into two sessions: fixtures in one, overlay+TODO in the other. Pass: dispatch model `gpt-6-astra`, overlay model `gpt-6-astra`, variant status "tuned overlay present", and the intent: "Frozen smoke-fixture campaign for the gpt-6-astra ideation overlay: two fixture files transcribed from the 2026-09-09 spec (must match it verbatim; histories 685/685/1130 bytes; H2 message identical to L2's revision message), a dated report, the TODO tick, and — only if a case failed — one communication-only overlay revision. Baseline, other overlays, checker, and existing fixtures must be unchanged." Adjudicate every finding: fix (rerun the checker, commit) or rebut explicitly in your final message; MEDIUM/LOW may be logged in `TODO.md` under `## Follow-ups from final branch review (2026-09-09)`.

- [ ] **Step 4: Final verification and branch finish**

```bash
cd /Users/david.zayas/playground/claude-setup
bash -c 'bash tests/prompt-contract-test.sh 2>&1 | tail -3; echo "exit=${PIPESTATUS[0]}"; bash tests/uninstall-test.sh 2>&1 | tail -1'
git status --short; git log --oneline main..HEAD
```
Expected: `exit=0`, `89 passed, 0 failed`, clean tree, the branch's commits. Then invoke `superpowers:finishing-a-development-branch` (previous work merged via PR; `ONBOARDING.md` is unchanged, so no re-share).
