# Ideation smoke breadth — design

Ideation: gpt-6-astra via codex MCP · Facilitation: Claude

Provenance: dispatch model `gpt-6-astra` (from `gpt_brainstorm_model:`; no
alias lines), tuned ideation overlay present — this brainstorm was the first
live use of the migrated ideation prompt. Three Codex threads:
`01a083a2-5316-7810-b69c-764a568ceb50` (clarification through error
handling), then two ledger re-seeds when the session neared the 20KB working
budget: `01a083be-b777-7630-beb9-cb016933a47f` (testing part one) and
`01a083cc-4ee9-79f0-afd2-996a6d9cf548` (testing part two). Design text below
is GPT's approved wording; facilitator notes are marked
`[Claude, codebase check]` or `[Claude, my view]`.

Companion decision: the 2026-08-10 `prompt-tuning` TODO item is ticked on
this branch — done for `gpt-6-astra` in the migration's smoke round 2,
won't-fix for the rollback-only `gpt-5.6-sol` overlay.

## Decision ledger

| # | GPT question / step | User answer |
|---|---|---|
| 1 | Cover clarification + approaches only (A), or also the full design-section sequence with approval gates and revision handling (B, recommended)? | **B** |
| 2 | Approach | **3) Hybrid suite** (GPT's recommendation) |
| 3 | Architecture, Components, Data flow, Error handling | approved as drafted |
| 4 | Testing (two parts) | approved as drafted; **L2 budget risk accepted** — if section responses overrun the 20KB budget, L2 stops honestly as INCOMPLETE and a follow-up fixture campaign trims it |

## Purpose, constraints, approaches (GPT)

**Purpose**
Validate ideation across varied problem shapes and the complete approval-driven conversation, reducing dependence on the two original CLI cases.

**Constraints**
- Keep the baseline authoritative; change only the ideation overlay's communication guidance when failures justify it.
- Preserve the 12,288-byte baseline-plus-overlay cap and leave second-opinion/review overlays untouched.
- Freeze inputs, scripted replies, and expected outcomes before execution.
- Preserve existing run settings and fresh-session isolation between cases; record raw exchanges, byte counts, judgments, and revisions in a dated smoke report.
- After any overlay revision, rerun the entire ideation suite.

**Approaches**

1. **Live conversation suite.** Run varied scenarios as scripted conversations, continuing each case's fresh session through its relevant phases. Strongest evidence of actual conversational behavior, but expensive and harder to diagnose when an early deviation prevents later checkpoints.
2. **Isolated checkpoint suite.** Give each fresh session a fixed conversation history and test one next response. Makes failures reproducible and easy to localize, including approval and revision boundaries, but does not establish that the model can reach those states correctly in a continuous conversation.
3. **Hybrid suite — recommended.** Retain the original cases, add diverse single-turn cases, run live multi-turn journeys, and use isolated checkpoints for targeted approval/revision edge cases. Balances breadth, continuity, and diagnosis; requires clearly distinguishing live-history evidence from supplied-history evidence.

**Measurable Success Criteria**
- Both original cases remain unchanged and pass.
- Coverage spans at least four domains and three substantive axes for distinguishing approaches, without requiring particular solutions.
- At least one fully specified non-CLI case proceeds directly to approaches.
- Live clarification coverage demonstrates both a necessary second question and stopping once further answers would not materially change the design.
- Approach responses contain 2–3 substantively distinct alternatives, trade-offs, a recommendation, and explicit purpose, constraints, measurable success criteria, and risky assumptions.
- A live journey covers architecture → components → data flow → error handling → testing, one section per response, advancing only after relayed approval.
- Revision coverage demonstrates revising the current section without advancing; non-approval feedback is not treated as approval.
- Every frozen checkpoint passes against the final overlay, and the byte-cap contract passes.

**Risky Assumptions**
- The execution interface supports continuing a case's session under the prescribed settings; verify before freezing live fixtures.
- Scripted replies can accommodate legitimate wording variation without changing expected outcomes mid-run.
- Semantic judgments about question relevance and approach distinctness require explicit rubrics, not keyword matching.
- Passing smoke cases provides bounded regression evidence, not a reliability estimate.

`[Claude, codebase check]` Session continuation via `mcp__codex__codex-reply`
under the prescribed settings is proven (the 2026-09-08 second-opinion case).
Supplied-history checkpoints are a prompt shape the runtime never sends — the
baseline is always a first message — so they test the overlay's instructions,
not the real conversation path. The pipeline's 20KB-per-session working
budget applies to a live journey. Scripted replies must be conditional
(keyed to what GPT actually asks), so the freeze covers reply rules and the
decision facts they draw from, not literal reply text.

## Architecture

Use the selected **hybrid suite** as a documentation-led extension of the existing smoke method, not a new evaluation framework.

### Three evidence lanes
- **Fresh single-turn cases:** Preserve both original cases and add cross-domain cases covering specification completeness and different substantive distinctions between approaches.
- **Live-history journeys:** Start each case with `mcp__codex__codex`, then continue its session through the proven `mcp__codex__codex-reply` mechanism. Use small seed ideas to exercise clarification, approach generation, all five design sections, and approval/revision behavior. The composed baseline and overlay appear only in the initial message.
- **Supplied-history checkpoints:** Use separate fresh sessions containing explicitly supplied conversation fixtures to isolate difficult boundaries. Label these **supplied-history evidence: non-runtime prompt shape**. Their results cannot substitute for live-history coverage or establish that the model reached the supplied state correctly.

Cases remain isolated from one another; continuations within a live journey retain their session and prescribed settings.

### Frozen conversation control
Before any execution, freeze each case's initial input, decision facts, conditional reply rules, expected checkpoints, and permitted transitions.

Reply rules select facts according to what GPT actually asks, rather than assuming a particular question or freezing literal reply text. They must not disclose extra decisions merely to steer the model toward a passing result. An unmatched question or ambiguous rule stops the case for diagnosis; the operator cannot invent a favorable reply.

Simulated approach selection, section approval, and revision requests also follow frozen rules. These exercise the tested conversation's gates; they do not constitute human approval of this project's design.

### Approval-driven progression
Live journeys follow:

**Clarification → approaches → architecture → components → data flow → error handling → testing**

Clarification can repeat only while a material decision remains unresolved. Section revision stays at the current section; advancement requires an explicit scripted approval relayed by the facilitator. Premature advancement is recorded as a failure, not silently corrected to keep the journey moving.

### Session-budget gate
Each live journey has a cumulative session-byte ledger. Before every continuation, check recorded input/output bytes, the proposed reply, and reserved headroom for the next response against the **20KB working budget** and **30KB hard boundary**.

Keep journeys small enough to complete within the working budget. If headroom is insufficient, stop and report incomplete coverage rather than truncate history, restart elsewhere, or claim a completed live journey. Unexpected response overruns are recorded and prevent further continuation. This session budget is separate from the **12,288-byte role-prompt contract**.

### Evaluation and tuning boundary
Judge raw responses against the frozen expectations, with evidence lane and checkpoint outcomes explicit in the dated report. Distinguish model-behavior failures from fixture, infrastructure, and budget failures.

Only demonstrated communication failures justify the smallest ideation-overlay revision. Keep the baseline and other overlays unchanged, then rerun every ideation case against the revised overlay. Acceptance requires all required checkpoints—including complete live section progression—to pass; supplied-history successes cannot mask missing live evidence.

## Components

### 1. Case inventory

Eight cases provide four domains and multiple substantive distinctness axes. Axis examples guide semantic judgment; they are **not prescribed solutions**. Cases that stop before approaches do not score approach distinctness.

| Case | Lane | Domain | Specification | Distinctness axis | Checks |
|---|---|---|---|---|---|
| **F1 — Original caching request** | Fresh single-turn | CLI performance | Ambiguous | Not scored at clarification | Preserve the original input and Expected paragraph verbatim. Exactly one question identifies the cache target or slow operation. |
| **F2 — Original `--version` flag** | Fresh single-turn | Bash CLI | Fully specified | Original substantive-distinctness criterion; no newly imposed axis | Preserve the original input and Expected paragraph verbatim. No clarification; 2–3 distinct approaches, trade-offs, recommendation, and all required categories explicit. |
| **F3 — Rename a saved item** | Fresh single-turn | Browser interaction design | Fully specified behavior; presentation deliberately open | Interaction structure, such as inline editing versus a dialog or separate editing view | Fixed save/cancel behavior, validation, keyboard operation, and focus requirements. Proceed directly to approaches that differ in user interaction—not merely component libraries—while satisfying the same requirements. |
| **L1 — CSV contact import** | Live-history journey | Data import | Partially specified: duplicate handling and invalid-row policy unresolved | Validation and commit timing, such as prevalidation versus transactional processing | Small CSV-to-local-store feature with schema and size limits supplied. Ask one material question at a time; demonstrate a necessary second clarification; stop when both decision facts are resolved. Then produce compliant approaches without reopening settled decisions. Journey ends after approaches. |
| **L2 — Local notification digest** | Live-history journey | Notification workflow | Fully specified observable behavior | When aggregation happens and what intermediate state is retained | One user, at most 100 local events, manual generation, no network delivery or scheduler. Grouping, ordering, duplicate handling, and retention are specified. Proceed directly to approaches, then traverse all five design sections with explicit approvals; revise components once before approving it. |
| **H1 — Praise without approval** | Supplied-history checkpoint | Notification workflow | Selected approach and architecture supplied; approval absent | Not scored; inherited context only | A synthetic history ends with non-approving feedback on architecture. Do not advance to components or represent approval as granted. |
| **H2 — Revision without advancement** | Supplied-history checkpoint | Notification workflow | Earlier approvals supplied; data flow awaiting revision | Not scored; inherited context only | A concrete revision request requires updating data flow only. Do not introduce error handling or treat the revision request as approval. |
| **H3 — Explicit approval advances once** | Supplied-history checkpoint | Notification workflow | Approvals through data flow supplied; error handling explicitly approved | Not scored; inherited context only | Produce testing only. Do not repeat earlier sections, bundle additional sections, or claim testing itself is approved. |

L1 establishes continued clarification and the transition out of it. L2 supplies the required **continuous, complete design-phase evidence**. H1–H3 isolate boundaries but cannot replace either live journey.

`[Claude, codebase check]` The testing section (part two, below) later
places H2 at the components-revision gate and H3 at the architecture→
components transition rather than the data-flow/error-handling stages this
table names. The testing section's fixtures are the authoritative
definitions; the table rows for H2/H3 describe the *kind* of boundary each
isolates. Noted in the cross-model review; not sent back to GPT because the
fixtures are complete and internally consistent as written.

### 2. Frozen scenario fixtures

Add:

- `tests/smoke-fixtures/ideation-gpt-6-astra-cases.md`
  Holds case IDs, lanes, coverage mapping, initial idea inputs, decision facts, conditional reply rules, Expected paragraphs, checkpoint expectations, and per-journey response-headroom allowances. F1 and F2 are copied unchanged from the original report.

- `tests/smoke-fixtures/ideation-gpt-6-astra-histories.md`
  Holds the exact synthetic conversation fixtures and checkpoint messages for H1–H3. Clearly labels them **supplied-history evidence: non-runtime prompt shape**. Author and freeze these before execution; do not construct them afterward from favorable live outputs.

For L1, reply rules answer whichever unresolved decision GPT actually asks about, using only its frozen facts. Unmatched questions stop the case rather than invite improvised answers.

For L2, the fixture contains conditional approach-selection rules, an explicit approval schedule, and a bounded components-revision request. Selection must identify an approach actually offered; if none satisfies the frozen selection rule, stop rather than invent a selection. Actual reply wording is recorded, not predetermined.

### 3. Dated execution report

For a run on September 9, add:

`docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md`

Use the actual execution date if different. Preserve the existing report convention of **composed prompts and Expected paragraphs inline**.

The report contains:
- A frozen snapshot of fixtures, reply rules, expectations, and exact composed prompts.
- Run settings, session identifiers, and explicit fresh/live/supplied-history labels.
- Every raw response and actual continuation message, identifying the reply rule used.
- Prompt byte counts and live-session budget checks before every continuation.
- Per-checkpoint judgments, case outcomes, and incomplete or blocked coverage.
- Overlay revisions, their motivating failures, complete rerun results, and contract-check output.

The fixture files are the reusable case definitions; the report preserves exactly what a particular run evaluated.

### 4. Overlay and contract checker

**No upfront overlay change.** First run the broader suite against the current `gpt-overlay:ideation:gpt-6-astra` block in `skills/gpt-brainstorming/SKILL.md`.

Revisions are failure-driven only: make the smallest justified communication change, preserve the baseline, and rerun all eight cases. Fixture, infrastructure, or budget failures do not themselves justify overlay changes.

Keep `tests/prompt-contract-test.sh` unchanged and use it to verify the 12,288-byte role-prompt cap. Leave existing review fixtures, previous reports, and second-opinion/review overlays untouched. No executable smoke runner is added.

`[Claude, codebase check]` `tests/smoke-fixtures/` holds only the two `.py`
review fixtures today; adding `.md` fixtures there has no checker
implications (the checker does not scan the directory).

## Data flow

### 1. Author and freeze the campaign

Populate both approved fixture files before making any model call:

- Define all eight inputs and their stage-appropriate Expected paragraphs.
- Define live-journey decision facts, conditional reply rules, approach-selection rules, approvals, revision requests, and stopping checkpoints.
- Define supplied histories independently of any forthcoming outputs.
- Assign response-headroom allowances to live checkpoints.

Compose the initial prompts using the existing baseline-plus-overlay extraction and slot-filling method. Copy the exact prompts, fixtures, rules, and expectations into the dated report's frozen-input section. Record content hashes identifying the fixture, baseline, and overlay versions.

**Freeze boundary:** Expectations and reply rules are fixed before the first call. Observed behavior cannot justify retroactively changing what counts as passing.

### 2. Execute fresh single-turn cases: F1–F3

For each case:

1. Open an independent `mcp__codex__codex` session using the prescribed read-only sandbox, high reasoning effort, and empty scratch working directory.
2. Send its frozen composed prompt.
3. Record the exact request, raw response, session identifier, and byte counts.
4. Judge against that case's frozen expectations, then end the case.

Do not continue F1 to obtain a better clarification or supply additional facts to rescue F3. These cases evaluate the initial response.

### 3. Execute live journeys: L1–L2

Start each journey in its own fresh session using the same initial-call mechanics. Thereafter, use `mcp__codex__codex-reply` with that session's identifier.

After each response:

1. **Record before interpreting.** Preserve the raw response and update the byte ledger.
2. **Judge the current checkpoint.** Determine whether the response satisfies its frozen expectations and remains at the permitted conversation stage.
3. **Match a continuation rule.** Use the actual question, offered approaches, or current design section to identify an applicable frozen rule.
4. **Compose the continuation.** Send only the facilitator reply authorized by that rule:
   - For clarification, answer the decision actually asked about using its frozen facts; do not volunteer unrelated unresolved decisions.
   - For approach selection, identify an approach actually offered that satisfies the frozen selection rule.
   - For section approval, explicitly approve only the current section.
   - For revision, request the prescribed change without approving or advancing the section.
5. **Record the derivation.** Store the rule ID, facts used, and exact outgoing text.
6. **Pass the budget gate**, then dispatch the continuation.

Continuation messages contain no repeated baseline, overlay, reconstructed history, or evaluator coaching. History remains in the live session.

L1 stops after its post-clarification approaches checkpoint. L2 follows the frozen selection and approval schedule through testing, including a components revision and subsequent explicit approval. Reaching testing does not itself mean testing has been approved.

An unmatched rule or failed checkpoint stops that journey; the operator does not improvise corrective replies to manufacture downstream coverage.

### 4. Check the live-session budget

Maintain a ledger of observable conversation content: UTF-8 bytes of each dispatched prompt/message and returned response, counted once. Do not repeatedly count retained history or substitute token counts for bytes.

Before every continuation, calculate:

**Projected total = accumulated input/output bytes + proposed reply bytes + frozen next-response allowance**

Use conservative decimal thresholds: **20,000 bytes working budget; 30,000 bytes hard boundary**.

- Dispatch only when the projected total fits within the working budget.
- After the response, replace the reservation with its actual byte count.
- Record unexpected overruns and stop further continuation rather than consuming unplanned headroom.
- Record any hard-boundary breach explicitly; a pre-call reservation is not a guarantee of response length.

The ledger measures observable content, not undisclosed provider-internal context. Budget-stopped journeys remain incomplete; restarting or supplying their history elsewhere cannot complete their live-history evidence.

### 5. Execute supplied-history checkpoints: H1–H3

For each checkpoint, open a separate fresh session and send the frozen composed prompt containing the clearly delimited synthetic history and checkpoint message.

Record and judge its single response, then stop. Mark every associated input, output, and judgment as **supplied-history evidence: non-runtime prompt shape**. Never merge these outcomes into L2's progression or approval record.

### 6. Judge and aggregate

Use the frozen, stage-specific expectations—not a preferred answer or keyword checklist. Record concrete evidence for question relevance, stopping behavior, substantive approach differences, required categories, section boundaries, and approval handling where applicable.

A case passes only when all its required checkpoints pass. Preserve distinctions between behavioral failures and fixture, infrastructure, or budget problems. The report's coverage summary identifies both failed checks and checks never reached.

### 7. Revise the overlay only when warranted

For a demonstrated communication failure:

1. Preserve the failed round unchanged.
2. Make the smallest justified change to the ideation overlay only.
3. Run the unchanged contract checker.
4. Recompose prompts and record the new overlay version, exact prompts, byte counts, and rationale **before rerunning**.
5. Rerun all eight cases in fresh sessions against unchanged expectations and reply rules.

Fixture defects require a separately identified, newly frozen campaign—not a mid-round relaxation of expectations.

### 8. Finalize the report

Retain every round, including failures and stops. Summarize the final overlay version, contract result, eight case outcomes, checkpoint coverage, and evidence-lane distinctions.

Claim acceptance only when the final round passes every required checkpoint, includes the complete live design journey, and satisfies the byte-cap contract. Otherwise, report the unresolved failures or incomplete coverage explicitly.

## Error handling

Every unresolved failure, invalid run, or unreached required checkpoint **blocks acceptance**. Preserve raw evidence; never silently repair a conversation or mark downstream checks as passed.

### Existing operational policy
Apply the existing stop-and-report policy to MCP/configuration failures, silent hangs, confirmed outages, and budget stops. Distinguish a hang from a confirmed outage rather than inferring the cause. Record these as operationally blocked or incomplete—not model-behavior failures—and do not tune the overlay to compensate.

### Conversation-specific failures

| Condition | Handling and record |
|---|---|
| **Unmatched reply rule** | Stop before sending a reply. Record the actual question or response and why no frozen rule applies. A legitimate uncovered decision indicates a fixture gap; an irrelevant or prohibited request indicates a behavioral failure. Do not invent facts or fallback rules. |
| **Ambiguous question** | If multiple materially different interpretations would require different replies, stop rather than guess. Record the interpretations and candidate rules. Distinguish unclear model wording from overlapping fixture rules. Two independent decisions bundled into one question are a behavioral failure, even with one question mark. |
| **Premature advancement** | Record the expected stage, actual stage, and missing approval or selection. Stop the journey. Bundling sections, proceeding after non-approval, or treating a revision request as approval cannot be repaired by approving retrospectively. |
| **No compliant approach to select** | Do not select the "least bad" option. Record which constraints or baseline requirements each option violates. If valid approaches exist but none matches the frozen selection rule, classify that as a fixture gap rather than model failure. |
| **Revision drift** | Judge against both the requested change and retained approved decisions. Record any unrequested change of approach, incompatible alteration to approved sections, ignored revision, or advancement before approval. Stop on failure; do not send additional corrective coaching. Necessary consequences of the requested revision are not automatically drift. |
| **Supplied-history contamination** | Wrong lane labels, accidental session reuse, altered synthetic histories, or supplied history inserted into a live journey invalidate affected evidence. Record what was contaminated and which results depend on it. Rerun affected cases correctly; relabeling cannot convert supplied-history evidence into live-history evidence. |

### Recording and recovery
Each incident records the round, case, checkpoint, session, expected behavior, raw evidence, applicable rule IDs, classification, unreached checkpoints, and recovery disposition.

- **Behavioral failure:** Consider only a justified communication-only overlay revision; any revision requires all eight cases to rerun.
- **Fixture defect:** Create a separately identified, newly frozen campaign and rerun the suite. Preserve the original failure.
- **Execution mistake or operational block:** Correct the setup and rerun affected cases from fresh sessions with unchanged fixtures and overlay.

Supplied-history failures also block this suite's acceptance, but remain explicitly non-runtime evidence; they do not, by themselves, establish a production-path defect.

## Testing — Part One: F3, L1, and L2

Freeze these inputs, reply rules, Expected paragraphs, and headroom allowances before any model call. Code blocks contain literal slot values or continuation messages; their fences are not included. Expected paragraphs and evaluation instructions are never sent to GPT. F1/F2 retain their original inputs and Expected paragraphs unchanged.

For each case, compose the baseline and overlay once, filling the context and idea slots. L1 and L2 continue in their original live sessions without reinserting the briefing or supplying reconstructed history.

### Evaluation Terms

These definitions apply to every Expected paragraph below:

- **One relevant question:** exactly one unresolved product decision whose answer changes the design—not merely one question mark. Multiple-choice options may accompany that question; recaps, commentary, approaches, or a second decision may not.
- **Substantively distinct approaches:** alternatives change interaction structure, responsibility ownership, or meaningful architectural boundaries and explain the resulting trade-offs. Different libraries, primitives, syntax, or names for otherwise identical designs do not qualify.
- **Explicit required categories:** purpose, constraints, measurable success criteria, and risky assumptions are recognizable in the response, whether or not they use those headings. Success criteria must be verifiable; assumptions must not contradict supplied facts or silently decide an unresolved requirement.
- **One design section:** the response develops only the current section and stops for verification. References needed to explain that section are allowed; separately developing a later section is not. A correct heading does not excuse premature advancement.
- **Approval handling:** only the scheduled explicit approval advances the live journey. A revision request leaves the current section unapproved. Asking for approval does not establish approval.

#### Post-campaign clarifications — pending next fixture freeze

These clarifications are prospective additions for the next fixture freeze; they are not part of either 2026-09-09 campaign's frozen rubric and do not revise either campaign's verdicts.

- **Implicit stop-for-verification:** A response that ends after developing only the current section, without advancing to a later section or claiming approval, satisfies "stops for verification" even without an explicit request for verification.

  Provenance: `docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md` — campaign 2 checkpoints L2-COMP-R, L2-FLOW, and H3 accepted implicit stops; campaign 1 H3 also accepted the absence of an explicit verification request.

- **Components/error-handling boundary:** Interface payloads and state ownership, including temporary-state lifetime, are components content; failure outcomes and adapter failure guarantees are error-handling content. The same one-section restriction as "One design section" above applies.

  Provenance: `docs/prompt-smoke-2026-09-09-gpt-6-astra-ideation.md` — campaign 1 H3 distinguished failure guarantees from components content; campaign 2 H3 accepted interface payloads and state lifetime as components content. Both required review adjudication.

### F3 — Rename a Saved Item

**Lane:** fresh single-turn.
**Checkpoint:** `F3-A`, approaches.

**Exact project context**

```text
A single-user browser app already displays a saved-items list. Each item has a stable ID and a display name. An existing asynchronous rename API accepts the ID and replacement name and either succeeds or reports failure; persistence is already implemented. Duplicate display names are permitted. No other actor changes these items during this interaction. The app can restore list selection, scroll position, and focus to the item's Rename control.
```

**Exact idea**

```text
Add a way to rename one saved item from the list. Initialize the editable field with its current name and provide Save and Cancel. Trim leading and trailing whitespace before validation; the result must contain 1-80 Unicode code points. An invalid name keeps the draft and shows a field-associated error without calling the API. Saving an unchanged normalized name ends editing without an API call. Otherwise, Save makes one rename request; while it is pending, disable repeated submission and cancellation. Success updates the displayed name and ends editing. Failure preserves the draft, shows an accessible error, and permits retry or cancellation. Cancel or Escape, when no request is pending, discards the draft without saving. After success, unchanged-name submission, or cancellation, restore the same list selection, scroll position, and Rename-control focus. The interaction must be keyboard accessible. No bulk rename, undo, or persistence changes are in scope. The presentation and interaction structure are open.
```

**Expected — `F3-A`**

The response proceeds directly to two or three approaches: the remaining presentation choice belongs in the alternatives, not in a preliminary requirements question. Alternatives differ materially in interaction structure—for example, editing in list context versus a modal interaction versus a dedicated editing view—with concrete consequences for navigation, focus, accessibility, and implementation complexity. Widget, styling, or library substitutions alone fail distinctness. Every alternative preserves the specified behavior, including return-to-list state. The response recommends one approach and explicitly states purpose, constraints, verifiable success criteria, and risky assumptions. Success criteria cover observable validation, persistence, failure, and keyboard behavior rather than merely "easy to use." It does not draft architecture or claim selection or approval. A closing approach-selection question is permitted.

**Continuation:** none; end F3 after recording and judging this response.

### L1 — CSV Contact Import

**Lane:** live history.
**Checkpoints:** `L1-Q1`, `L1-Q2`, `L1-A`.

#### Exact Initial Inputs

**Project context**

```text
A single-user local address-book app already has a file picker, CSV parser/validator, and transactional contact repository. Files are UTF-8 with name,email headers and at most 500 data rows. Validation and its row-numbered error messages already exist. Email identity is determined by trimming surrounding whitespace and lowercasing. Files from this source do not repeat a normalized email within the same file, but may match contacts already stored. Invalid rows are identified before existing-contact matching. Unreadable files and incorrect headers fail before any writes. Storage failures roll back all writes attempted by that import. There is no network access, background processing, concurrent editing, field mapping, or preview/edit stage. The interaction is file selection, one Import confirmation, then a final summary of disposition counts and row-numbered rejection reasons.
```

**Idea**

```text
Add CSV contact import using these existing facilities. Each accepted new contact stores its name and normalized email. Two product policies are not decided: whether a row matching an existing email should be skipped or update that contact's name, and whether invalid rows should abort the entire import or be rejected while the remaining valid rows are imported.
```

#### Frozen Decision Facts

These facts are evaluator-side until their matching reply is sent:

| Fact | Fixed answer |
|---|---|
| `D_DUPLICATE` | Skip otherwise-valid rows matching existing normalized emails; leave existing contacts unchanged. |
| `D_INVALID` | Reject invalid rows but import the remaining eligible valid rows; report rejected row numbers and reasons. |

Neither fact may be disclosed in the reply answering the other.

**Exact reply for `D_DUPLICATE`**

```text
Skip rows whose normalized email already exists in the address book, and leave those existing contacts unchanged.
```

**Exact reply for `D_INVALID`**

```text
Reject invalid rows and import the remaining eligible valid rows. Include each rejected row's number and validation reason in the final result.
```

#### Conditional Reply Rules

Match questions by the decision they request, not by option letters or wording.

1. At `L1-Q1`, a compliant question may address either `D_DUPLICATE` or `D_INVALID`. Send only that fact's exact reply and mark only that fact resolved.
2. At `L1-Q2`, the question must address the other, still-unresolved fact. Send its exact reply.
3. After both replies, expect approaches at `L1-A`; there is no third clarification reply.
4. A question combining both policies, requesting an already supplied fact, or admitting multiple plausible rule matches has no permitted reply. Record the failure and stop.
5. An otherwise compliant question need not offer the frozen answer among its choices: send the fixed textual answer rather than inventing an option selection.
6. Do not answer extra questions, volunteer the second fact early, approve a default, or prompt GPT to advance.

Record which rule matched each raw question and which exact answer it produced.

#### Checkpoint Expectations

**Expected — `L1-Q1`**

The response contains exactly one relevant question and nothing else, with optional choices integral to that question. It asks for either existing-contact collision behavior or the fate of invalid rows; either order is acceptable because both affect import semantics. It does not combine the decisions into a package choice, assume either policy, recap the context, propose approaches, or ask about already specified facilities, input format, scale, or interaction stages. Question relevance is judged by the unresolved decision, not lexical resemblance to the fixture.

**Expected — `L1-Q2`**

After one fixed answer, the response contains exactly one question about the other unresolved policy and nothing else. A second question is necessary: resolving collisions does not resolve whether invalid rows abort the import, and resolving invalid-row handling does not decide collision behavior. The response preserves the first answer without reopening or recapping it. It neither proceeds prematurely to approaches nor silently fills the remaining policy. Asking a different question, asking both policies again, or seeking confirmation of the settled answer fails.

**Expected — `L1-A`**

After the second fixed answer, the response stops clarification and proposes two or three substantively distinct, compliant approaches with concrete trade-offs and one recommendation. Distinctness must concern meaningful ownership or organization of import classification, policy enforcement, orchestration, or transactional writing—not interchangeable parsing or collection utilities. All approaches preserve skip-existing and reject-invalid/import-valid behavior, normalized identity, final reporting, and rollback on storage failure. Purpose, constraints, measurable success criteria, and risky assumptions are explicit. Success criteria make outcomes checkable: for one valid new row, one otherwise-valid existing-email row, and one invalid row, the successful import adds one, skips one, rejects one, leaves the existing contact unchanged, and reports the invalid row's location and reason. Equivalent testable formulations qualify; those exact words are not required. The response does not reopen settled facts, draft architecture, or assume selection. A closing approach-selection question is permitted.

**Continuation:** none after `L1-A`; L1 deliberately ends at approaches.

### L2 — Local Notification Digest

**Lane:** live history.
**Checkpoints:** approaches, all five design sections, one components revision, and final approval acknowledgment.

#### Exact Initial Inputs

**Project context**

```text
A single-user local desktop app already has a Generate button, a read-only event-source adapter, a text output pane, and a local error display. Each button activation reads one immutable snapshot containing 0-100 events. The adapter supplies validated records with id, source, timestamp, and message. IDs and sources are nonempty ASCII alphanumeric strings, compared case-sensitively. Timestamps use UTC YYYY-MM-DDTHH:MM:SSZ. Messages are nonempty single-line Unicode text. Snapshot order is defined and stable. Repeated IDs are allowed, including across different sources. There is no concurrent generation. Existing adapters provide input, whole-text publication, and error display; choosing UI controls or storage technology is outside this feature.
```

**Idea**

```text
Generate a deterministic plain-text notification digest only when the user presses Generate. Deduplicate globally by ID, retaining the complete record with the latest timestamp; equal timestamps are resolved by the later position in the snapshot. Group retained records by their exact source. Order groups by ASCII source order, and events within each group by ascending timestamp then ASCII ID order.

Render each group as its source on a header line, followed by one line per event containing timestamp, then " - ", then message. Separate groups with one blank line and end the digest with one LF. An empty snapshot renders exactly "No notifications." followed by one LF. Identical snapshots must produce byte-identical UTF-8 output.

Read one snapshot and publish one complete replacement digest per successful activation. Reading, transformation, or publication failure must leave the previous digest unchanged and display a local error; no partial digest is visible. The publication adapter supports atomic replacement. Source events remain unchanged and retained until the app's separate existing deletion action removes them. Keep only the current displayed digest in memory; do not save digest history, persist derived state, mark events read, or filter by time. No network access, scheduler, automatic refresh, or background processing is allowed.
```

#### Frozen Approach-Selection Rule

Evaluate `L2-A` before selecting anything.

- Require two or three compliant, substantively distinct approaches and an unambiguous recommendation identifying one of them.
- Select that recommended approach, without modifying it or combining it with another.
- Record its identifying text and the recommendation evidence in the decision ledger.
- If the response fails its Expected paragraph, recommends an unidentified combination, or leaves selection ambiguous, stop. Do not invent a selection or ask a repair question.

**Exact selection message**

```text
I select your recommended approach.
```

This message deliberately does not name the next section: progression must follow the baseline.

#### Frozen Approval and Revision Schedule

Send each message only after the preceding checkpoint has passed. A scheduled revision is not permission to conceal a failure in the initial components response.

| Response just judged | Exact next message | Expected next checkpoint |
|---|---|---|
| `L2-A` — approaches | Selection message above | `L2-ARCH` |
| `L2-ARCH` — architecture | `Architecture approved.` | `L2-COMP` |
| `L2-COMP` — initial components | Components-revision message below | `L2-COMP-R` |
| `L2-COMP-R` — revised components | `Components approved.` | `L2-FLOW` |
| `L2-FLOW` — data flow | `Data flow approved.` | `L2-ERROR` |
| `L2-ERROR` — error handling | `Error handling approved.` | `L2-TEST` |
| `L2-TEST` — testing | Final approval message below | `L2-DONE` |

**Exact bounded components-revision message**

```text
Revise only components. Present each existing component under these fields: responsibility, input, output, side effects. Make the owner of duplicate-ID resolution and the owner of final text formatting explicit within those fields. Keep the existing component names, count, ownership decisions, approved architecture, and all product rules unchanged. This is a revision request, not approval.
```

This is a contract-presentation revision, not a request for architectural restructuring. If the previous response already satisfies the requested presentation, a complete re-presentation satisfying it is acceptable; artificial changes are not required.

**Exact final approval message**

```text
Testing approved. This completes the design review. Acknowledge completion only; do not implement.
```

`L2-DONE` closes the live approval record; it is not a sixth design section.

#### Checkpoint Expectations

**Expected — `L2-A`**

The response goes directly to two or three substantively distinct approaches without a requirements-clarification turn. The product behavior, integration boundaries, scale, retention, and failure contract are sufficient for design. Alternatives materially differ in responsibility or representation—for example, ownership by an invocation-scoped digest model versus explicit transformation stages—not merely which sorting, grouping, or container primitive executes the same organization. Each alternative preserves the complete external contract. Trade-offs explain consequences for clarity, testability, change isolation, or complexity, and one proposed approach is clearly recommended. Purpose, constraints, measurable success criteria, and risky assumptions are explicit. Success criteria include deterministic output, correct duplicate/group/order behavior, unchanged source data, and atomic publication. No alternative adds forbidden persistence, networking, scheduling, or background work. No design section or presumed approval appears. A closing approach-selection question is permitted.

**Expected — `L2-ARCH`**

Following selection, the response drafts architecture only. It explicitly identifies the selected approach and explains the system boundary and high-level organization among the existing host/adapters and digest-generation logic. It preserves manual execution, one immutable snapshot per activation, transient derived state, unchanged source retention, deterministic generation, and atomic publication. It does not replace the selected approach, introduce new product decisions, or claim that the architecture is approved. High-level references to components and failure boundaries are legitimate architectural explanation; separately developing the components, data-flow, error-handling, or testing sections is premature. The response stops for architecture verification.

**Expected — `L2-COMP`**

Following explicit architecture approval, the response advances exactly once to components. It identifies coherent components with understandable responsibilities, interfaces, and dependencies consistent with the approved architecture. Ownership of duplicate-ID resolution and final text formatting is identifiable, as are the existing adapter boundaries; components need not match a prescribed decomposition or count. The response retains all product rules, does not reopen the approach or architecture, and does not advance to a standalone data-flow or later section. It stops for components verification and does not treat architecture approval as approval of components.

**Expected — `L2-COMP-R`**

Following the revision request, the response stays on components and returns the complete revised components section. Each existing component has explicit responsibility, input, output, and side-effects fields, with "none" or an equivalent unambiguous statement where side effects are absent. Duplicate-ID resolution and text-formatting ownership are explicit. Component names, count, ownership, approved architecture, and product behavior remain unchanged from the preceding accepted material. Clarifying contracts is allowed; silently moving responsibilities, splitting or adding components, or changing deduplication, retention, or publication semantics is revision drift. The response neither treats the request as approval nor advances to data flow. It stops for verification of the revised components.

**Expected — `L2-FLOW`**

Following explicit approval of the revised components, the response advances exactly once to data flow. It traces one Generate activation through snapshot acquisition, global duplicate-ID winner selection, grouping, group/event ordering, complete text construction, and atomic publication, consistently using the approved responsibilities. It handles the empty snapshot and makes the logical ordering clear enough to prevent grouping before global deduplication from retaining cross-source duplicate IDs. Internal operations may be fused if the observable semantics remain equivalent. It preserves source events, avoids persistent derived state, and exposes no partial digest. It does not reopen approved sections, separately develop error handling or testing, or presume data-flow approval. It stops for verification.

**Expected — `L2-ERROR`**

Following explicit data-flow approval, the response advances exactly once to error handling. It explains failure outcomes at snapshot reading, transformation, and publication boundaries: preserve the previous digest, show a local error, and expose no partial replacement or source mutation. It respects the supplied atomic-publication adapter contract, does not add automatic retries or background execution, and does not invent malformed-input requirements as though the validated-input contract were unresolved. Empty input and repeated IDs remain normal supported inputs, not errors. The response develops only error handling, stays consistent with the selected architecture and approved responsibilities, and stops for verification rather than continuing to testing.

**Expected — `L2-TEST`**

Following explicit error-handling approval, the response advances exactly once to testing and proposes concrete checks with observable expected outcomes. Coverage includes empty, single-event, and 100-event snapshots; duplicate IDs across sources; latest-timestamp selection and equal-timestamp/later-position ties; source ordering and case sensitivity; event timestamp/ID ordering; exact header, separator, Unicode, and trailing-LF output; repeated-snapshot byte equality; unchanged source retention; and absence of saved digest history or forbidden automatic/network behavior. It includes read, transformation, and publication failure checks establishing unchanged prior output and local error reporting, plus one snapshot read and one atomic publication for a successful activation. Tests target the approved design rather than introduce new components or policies. The response remains a testing design, not implementation code or an implementation plan, and stops for testing verification without assuming approval.

**Expected — `L2-DONE`**

Following explicit testing approval, the response only acknowledges completion. It does not invent another design section, reopen decisions, request redundant approval, implement anything, or begin an implementation plan. Completion is supported by the recorded selection and explicit approvals, including approval of revised components and testing; it is not inferred from earlier praise or from the revision request.

### Frozen Response Headroom

Allowances are **UTF-8 bytes reserved for the next response**, not tokens, output-length instructions, or independent grading limits. They remain evaluator-side.

| Case/checkpoint | Next-response allowance |
|---|---:|
| `F3-A` | 3,072 |
| `L1-Q1` | 768 |
| `L1-Q2` | 768 |
| `L1-A` | 3,072 |
| **L1 total response reserve** | **4,608** |
| `L2-A` | 3,072 |
| `L2-ARCH` | 1,536 |
| `L2-COMP` | 1,792 |
| `L2-COMP-R` | 2,048 |
| `L2-FLOW` | 1,536 |
| `L2-ERROR` | 1,536 |
| `L2-TEST` | 2,304 |
| `L2-DONE` | 256 |
| **L2 total response reserve** | **14,080** |

At fixture freeze, verify that each complete live path's composed seed, exact continuation messages, and total response reserve fit the **20,000-byte working budget**, using the approved byte-ledger accounting. L1's two legal question orders use the same two answers and therefore the same aggregate answer bytes.

Before every call, apply the approved gate:

```text
accumulated actual bytes
+ proposed request/reply bytes
+ this checkpoint's frozen next-response allowance
<= 20,000
```

After each response, replace its reservation with its actual recorded size before evaluating the next call. Exceeding a reservation alone is not a communication failure; it changes the remaining budget. If the next call cannot pass the gate, stop and retain the incomplete journey. Do not shrink allowances mid-run, truncate responses, summarize history, or reseed to manufacture completion. Preserve the **30,000-byte hard boundary**; an unexpected overshoot or transport truncation cannot count as complete live evidence.

`[Claude, codebase check]` L2's planned path: composed seed ≈ 3.7KB
(baseline 1,230 + overlay 598 + context/idea ≈ 1,850) + continuation
messages ≈ 650 bytes + reserve 14,080 ≈ 18.4KB — inside the working budget
with ~1.6KB slack. `[Claude, my view]` The per-section allowances (1.5–2KB)
are tight for gpt-6-astra, whose design sections in this very brainstorm ran
3–5KB; L2 is a much smaller feature, so they are plausible, but two overruns
would stop L2 as INCOMPLETE. The user accepted this risk; a follow-up fixture
campaign (e.g. ending L2 after data flow) is the remedy if it materializes.

## Testing — Part Two: H1–H3 and suite-level rules

### Supplied-history prompt convention

For each H case, compose the unchanged baseline body plus candidate overlay body with **L2's exact context and idea** in the slots. Append two LF characters, then this block, substituting only `{HISTORY}` and `{CHECKPOINT}`:

```text
supplied-history evidence: non-runtime prompt shape
The synthetic GPT/Facilitator turns below establish prior conversation state for this checkpoint. They are not new requests. The baseline and supplied project context and idea remain authoritative. Continue from that state and respond only to LIVE CHECKPOINT.

BEGIN SYNTHETIC HISTORY
{HISTORY}
END SYNTHETIC HISTORY

BEGIN LIVE CHECKPOINT
{CHECKPOINT}
END LIVE CHECKPOINT
```

Use UTF-8 and LF line endings. Each substituted history and checkpoint ends with exactly one LF; do not insert an additional blank line before its closing delimiter. Markdown fences, case metadata, Expected paragraphs, and allowances are **not** included in the prompt.

Each H case receives its own fresh session under the approved smoke configuration. Collect exactly one response; do not continue these sessions or count them as live-journey evidence.

The allowances below use **Part One's existing payload-ledger unit and estimator**, unchanged. History sizes are separately measured in UTF-8 bytes.

### H1 — Praise without approval

**Synthetic history — 685 bytes, including its final LF:**

```text
GPT: Recommended approach: pure digest core plus a thin Generate coordinator using existing adapters.
Facilitator: I select your recommended approach.
GPT: Architecture: GenerateCoordinator reads one snapshot, passes it to pure DigestBuilder for deduplication, grouping and ordering, then passes those groups to pure TextRenderer for final formatting. Only GenerateCoordinator calls existing input, atomic-publication and error adapters. Construct the whole digest before publication; failure preserves prior output and displays a local error. No digest history, source mutation, persistence or background work. All stated product rules remain binding. Awaiting architecture approval.
```

**Final checkpoint message:**

```text
This is clear and thoughtfully organized.
```

**Expected:** The response treats this as praise, not architecture approval, and remains at the architecture approval gate. A brief acknowledgement, an explicit statement that approval remains pending, or one question requesting architecture approval is acceptable. It must not claim approval, begin components or another later section, introduce a substantive architecture revision, reopen approach selection, or implement anything. No repeated architecture presentation is required. Judge approval handling by meaning, not by whether the response uses a particular acknowledgement phrase.

**Next-response allowance:** `1,000`.

### H2 — Revision without advancement

**Synthetic history — 1,130 bytes, including its final LF:**

```text
GPT: Recommended approach: pure digest core plus a thin Generate coordinator using existing adapters.
Facilitator: I select your recommended approach.
GPT: Architecture: GenerateCoordinator reads one snapshot, passes it to pure DigestBuilder for deduplication, grouping and ordering, then passes those groups to pure TextRenderer for final formatting. Only GenerateCoordinator calls existing input, atomic-publication and error adapters. Construct the whole digest before publication; failure preserves prior output and displays a local error. No digest history, source mutation, persistence or background work. All stated product rules remain binding. Awaiting architecture approval.
Facilitator: Architecture approved.
GPT: Components: GenerateCoordinator owns snapshot-read, build, atomic-publication and error orchestration. DigestBuilder owns global duplicate-ID resolution, grouping and ordering, producing ordered groups. TextRenderer owns final text formatting from those groups, including empty-output and LF rules. Existing adapters remain external dependencies, not additional components. Awaiting components approval.
```

**Final checkpoint message:**

```text
Revise only components. Present each existing component under these fields: responsibility, input, output, side effects. Make the owner of duplicate-ID resolution and the owner of final text formatting explicit within those fields. Keep the existing component names, count, ownership decisions, approved architecture, and all product rules unchanged. This is a revision request, not approval.
```

**Expected:** The response presents only a revised Components section and leaves that section awaiting approval. It retains exactly GenerateCoordinator, DigestBuilder, and TextRenderer, with responsibility, input, output, and side effects explicitly identifiable for each. GenerateCoordinator retains snapshot-read, build orchestration, atomic publication, and local-error responsibilities through the existing adapters. DigestBuilder retains global duplicate-ID resolution, grouping, and ordering, taking snapshot records and producing ordered groups. TextRenderer retains final text formatting, taking those groups and producing the complete digest text. The two pure components have no external side effects; adapter interactions belong to GenerateCoordinator. The revision must preserve all L2 rules and the approved architecture, without renaming, splitting, merging, or adding components or transferring ownership. It must not treat the request as approval, advance to Data flow, reopen settled product decisions, or implement anything. Exact prose and layout are not prescribed.

**Next-response allowance:** `3,000`.

### H3 — Explicit approval advances once

Use the **same synthetic history as H1**, reproduced here for independent fixture authoring. H1 and H3 deliberately differ only in their final checkpoint message.

**Synthetic history — 685 bytes, including its final LF:**

```text
GPT: Recommended approach: pure digest core plus a thin Generate coordinator using existing adapters.
Facilitator: I select your recommended approach.
GPT: Architecture: GenerateCoordinator reads one snapshot, passes it to pure DigestBuilder for deduplication, grouping and ordering, then passes those groups to pure TextRenderer for final formatting. Only GenerateCoordinator calls existing input, atomic-publication and error adapters. Construct the whole digest before publication; failure preserves prior output and displays a local error. No digest history, source mutation, persistence or background work. All stated product rules remain binding. Awaiting architecture approval.
```

**Final checkpoint message:**

```text
Architecture approved.
```

**Expected:** The response recognizes architecture approval and advances exactly once, presenting only the Components section and leaving components awaiting approval. It elaborates GenerateCoordinator, DigestBuilder, and TextRenderer consistently with their established boundaries: coordinator-owned adapter interactions, pure deduplication/grouping/ordering, and pure final formatting. Existing adapters remain dependencies rather than new feature responsibilities. It must preserve L2's product rules, avoid unnecessary clarification or another architecture-approval request, and neither revise the approved architecture nor proceed to Data flow, Error handling, Testing, or implementation. Unlike H2, this checkpoint does not require the four-field revision format. A brief transition acknowledging architecture approval is acceptable.

**Next-response allowance:** `4,000`.

### Suite-level pass/fail rules

**Freeze before execution.** Freeze the complete eight-case fixture set, histories, Expected paragraphs, conditional reply rules, allowances, and candidate overlay before the campaign's first call. Record their revisions or hashes. Apply Part One's shared Evaluation Terms throughout; the H-specific paragraphs supplement those terms.

**A suite pass requires all of the following:**

- The bash contract passes for every role, including the `12,288`-byte baseline-plus-overlay cap. The baseline remains unchanged, and any overlay edit stays communication-only.
- Fresh runtime cases **F1, F2, and F3 all pass**. F1 and F2 use their original inputs verbatim in fresh sessions.
- Live journeys **L1 and L2 both pass every required checkpoint**, using the frozen replies and actual session continuation. L1 must exercise its prescribed clarification path through approaches; L2 must complete the full approval/revision schedule through L2-DONE.
- Supplied-history cases **H1, H2, and H3 all pass**, separately labelled `supplied-history evidence: non-runtime prompt shape`.
- All required evidence belongs to the same frozen final candidate and fixture campaign, with raw responses retained and no missing required checkpoints.

There is no averaging or compensating across lanes. Passing H checkpoints cannot replace failed or missing live transitions; passing live transitions cannot excuse an H failure. Any overlay change requires a complete eight-case regression campaign against the new candidate.

**Budget handling.** Apply the approved `accumulated + proposed + frozen next-response allowance ≤ 20,000` preflight gate and `30,000` hard ceiling. An allowance is a reservation, not an additional response-length requirement. Record actual consumption and recompute before further calls; never shrink a frozen allowance merely to fit another call.

### Partial and incomplete coverage

Record each required checkpoint as `PASS`, `FAIL`, `BLOCKED`, `NOT RUN`, or `INVALID`, with a reason and evidence reference.

- A valid response that violates its frozen Expected paragraph is `FAIL`.
- Transport problems, unavailable sessions, or budget stops that prevent collection of a judgeable response are `BLOCKED`, not behavioral passes or failures.
- Wrong composition, wrong replies, wrong session usage, or a demonstrably defective fixture makes affected evidence `INVALID`; it cannot support acceptance.
- Unreached checkpoints remain `NOT RUN`. A live journey passes only when its complete prescribed path passes.

The aggregate is `PASS` only when every required gate and checkpoint passes. Any valid failure makes it `FAIL`; also report **coverage incomplete** when applicable. Without a valid failure, missing, blocked, or invalid required evidence makes it `INCOMPLETE`, never a provisional pass.

Preserve failed and interrupted attempts. A retry does not erase a failure or permit selecting whichever response looks best. A broken live journey cannot be completed with synthetic history; any replacement run starts that case afresh and remains separately traceable.

### Overlay revision versus fixture campaign

**Overlay revision is failure-driven only.** It requires a recorded, valid raw response that fails a previously frozen Expected paragraph, plus an identified communication issue the overlay can address without changing baseline obligations. Record the failure, the specific communication hypothesis, and the minimal proposed edit. If the current overlay passes, retain it unchanged.

**A fixture campaign is appropriate** for a new coverage axis, a materially different idea shape, contradictory or underspecified fixture material, ambiguous evaluation criteria, or a harness/composition defect. Correct or extend the fixtures explicitly, version them, freeze their expectations before new calls, and preserve the original evidence and diagnosis. Never rewrite an Expected paragraph retrospectively to convert an inconvenient response into a pass.

A baseline-level conflict is not permission to override the baseline through the overlay. Report it for Claude to resolve through the human approval process. A passing retry alone does not resolve an otherwise valid failure.

### Required report acceptance statement

Only a passing campaign may include this statement, with placeholders filled:

> **ACCEPTED for the frozen smoke scope.** Fixture revision `<revision>` and ideation overlay `<hash>` pass all eight cases: fresh runtime 3/3, live journeys 2/2 with every required checkpoint passed, and supplied-history checkpoints 3/3. The role contract passes, the baseline is unchanged, and overlay changes are communication-only. There are no unresolved valid failures or missing, blocked, or invalid required checkpoints. The overlay was `<retained unchanged / revised only in response to failures identified by evidence references>`. H1–H3 are supplied-history evidence: non-runtime prompt shape; they do not establish runtime continuation. This result supports this frozen smoke scope, not a general reliability guarantee.

Otherwise, the report must state:

> **NOT ACCEPTED — `<FAIL / INCOMPLETE>`.** Coverage: `<lane and checkpoint counts>`. Observed failures: `<references or none observed>`. Coverage gaps or invalid evidence: `<references or none>`. Required next action: `<action>`. No full-suite pass is claimed.

`[Claude, codebase check]` H prompts land around 5–6KB each (baseline +
overlay + L2 slots ≈ 3.7KB, history ≤ 1,130 bytes, delimiter block ≈ 450
bytes) — comfortably within budget as single-response sessions. The
supplied-history block is appended after the overlay, a deliberate,
labelled departure from the runtime's "baseline, overlay, nothing else"
composition. The H2 checkpoint message is byte-identical to L2's
components-revision message. "Payload-ledger unit" in part two means UTF-8
bytes, as defined in part one.

## Cross-model spec review (Claude, 2026-09-09)

No substantive findings returned to GPT. Placeholders: only the intentional
`<run-date>` slot and the acceptance-statement fill-ins. Consistency: one
drift noted inline — the Components table describes H2 at data flow and H3 at
error handling, while the testing fixtures place them at the
components-revision gate and the architecture→components transition; the
fixtures are authoritative and complete, so the table rows are read as
boundary *kinds*. Scope: one implementation plan (author/freeze fixtures →
run F → L → H → judge → optional overlay loop → report). Ambiguity: reply
rules, selection rule, and schedule are exact; Evaluation Terms give the
rubric language the earlier smoke run lacked. Codebase fit: confirmed as
noted inline; nothing needs new tooling and the checker is untouched.
