# Ideation smoke fixtures — gpt-6-astra (campaign 2026-09-09)

Fixture revision: campaign 2 (2026-09-09) — L2 live schedule ends after data flow; H2/H3 inventory rows corrected to match the histories fixture. Campaign-1 text is preserved in git history (commit 177e841).

Frozen inputs, decision facts, conditional reply rules, Expected paragraphs,
and response-headroom allowances for the eight-case ideation suite defined in
`docs/superpowers/specs/2026-09-09-ideation-smoke-breadth-design.md`.
Composition rule for every case: the `gpt-baseline:ideation` body with its
two slots filled, one blank line, the `gpt-overlay:ideation:gpt-6-astra`
body. Expected paragraphs, evaluation terms, rules, and allowances are
evaluator-side and are never sent to GPT. Supplied-history fixtures (H1–H3)
live in `ideation-gpt-6-astra-histories.md`.

## Case inventory

| Case | Lane | Domain | Specification | Distinctness axis | Checks |
|---|---|---|---|---|---|
| **F1 — Original caching request** | Fresh single-turn | CLI performance | Ambiguous | Not scored at clarification | Preserve the original input and Expected paragraph verbatim. Exactly one question identifies the cache target or slow operation. |
| **F2 — Original `--version` flag** | Fresh single-turn | Bash CLI | Fully specified | Original substantive-distinctness criterion; no newly imposed axis | Preserve the original input and Expected paragraph verbatim. No clarification; 2–3 distinct approaches, trade-offs, recommendation, and all required categories explicit. |
| **F3 — Rename a saved item** | Fresh single-turn | Browser interaction design | Fully specified behavior; presentation deliberately open | Interaction structure, such as inline editing versus a dialog or separate editing view | Fixed save/cancel behavior, validation, keyboard operation, and focus requirements. Proceed directly to approaches that differ in user interaction—not merely component libraries—while satisfying the same requirements. |
| **L1 — CSV contact import** | Live-history journey | Data import | Partially specified: duplicate handling and invalid-row policy unresolved | Validation and commit timing, such as prevalidation versus transactional processing | Small CSV-to-local-store feature with schema and size limits supplied. Ask one material question at a time; demonstrate a necessary second clarification; stop when both decision facts are resolved. Then produce compliant approaches without reopening settled decisions. Journey ends after approaches. |
| **L2 — Local notification digest** | Live-history journey | Notification workflow | Fully specified observable behavior | When aggregation happens and what intermediate state is retained | One user, at most 100 local events, manual generation, no network delivery or scheduler. Grouping, ordering, duplicate handling, and retention are specified. Proceed directly to approaches, then traverse all five design sections with explicit approvals; revise components once before approving it. |
| **H1 — Praise without approval** | Supplied-history checkpoint | Notification workflow | Selected approach and architecture supplied; approval absent | Not scored; inherited context only | A synthetic history ends with non-approving feedback on architecture. Do not advance to components or represent approval as granted. |
| **H2 — Revision without advancement** | Supplied-history checkpoint | Notification workflow | Selected approach, architecture approval, and initial components supplied; components-revision request pending | Not scored; inherited context only | A synthetic history ends with the bounded components-revision request. Return only revised components; do not treat the request as approval or advance to data flow. |
| **H3 — Explicit approval advances once** | Supplied-history checkpoint | Notification workflow | Selected approach and architecture supplied; architecture explicitly approved | Not scored; inherited context only | Advance exactly once to components. Do not repeat architecture, bundle later sections, or claim components are approved. |

## Evaluation terms

- **One relevant question:** exactly one unresolved product decision whose answer changes the design—not merely one question mark. Multiple-choice options may accompany that question; recaps, commentary, approaches, or a second decision may not.
- **Substantively distinct approaches:** alternatives change interaction structure, responsibility ownership, or meaningful architectural boundaries and explain the resulting trade-offs. Different libraries, primitives, syntax, or names for otherwise identical designs do not qualify.
- **Explicit required categories:** purpose, constraints, measurable success criteria, and risky assumptions are recognizable in the response, whether or not they use those headings. Success criteria must be verifiable; assumptions must not contradict supplied facts or silently decide an unresolved requirement.
- **One design section:** the response develops only the current section and stops for verification. References needed to explain that section are allowed; separately developing a later section is not. A correct heading does not excuse premature advancement.
- **Approval handling:** only the scheduled explicit approval advances the live journey. A revision request leaves the current section unapproved. Asking for approval does not establish approval.

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

## L1 — CSV contact import (live history)

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

## L2 — Local notification digest (live history)

**Lane:** live history.
**Checkpoints:** approaches, architecture, components (with one revision), data flow, and final approval acknowledgment.

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
| `L2-FLOW` — data flow | Final approval message below | `L2-DONE` |

**Exact bounded components-revision message**

```text
Revise only components. Present each existing component under these fields: responsibility, input, output, side effects. Make the owner of duplicate-ID resolution and the owner of final text formatting explicit within those fields. Keep the existing component names, count, ownership decisions, approved architecture, and all product rules unchanged. This is a revision request, not approval.
```

This is a contract-presentation revision, not a request for architectural restructuring. If the previous response already satisfies the requested presentation, a complete re-presentation satisfying it is acceptable; artificial changes are not required.

**Exact final approval message**

```text
Data flow approved. This completes the design review for this smoke case; error handling and testing are reviewed separately. Acknowledge completion only; do not draft further sections or implement.
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

**Expected — `L2-DONE`**

Following explicit data-flow approval and the statement that this review is complete, the response only acknowledges completion. It does not draft error handling, testing, or any other section, reopen decisions, request redundant approval, implement anything, or begin an implementation plan. Completion is supported by the recorded selection and explicit approvals, including approval of revised components and data flow; it is not inferred from earlier praise or from the revision request.

## Frozen response headroom

Allowances are **UTF-8 bytes reserved for the next response**, not tokens, output-length instructions, or independent grading limits. They remain evaluator-side.

| Case/checkpoint | Next-response allowance |
|---|---:|
| `F1-A` | 1,024 |
| `F2-A` | 3,072 |
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
| `L2-DONE` | 256 |
| **L2 total response reserve** | **10,240** |

Before every call, apply the approved gate:

```text
accumulated actual bytes
+ proposed request/reply bytes
+ this checkpoint's frozen next-response allowance
<= 20,000
```

After each response, replace its reservation with its actual recorded size before evaluating the next call. Exceeding a reservation alone is not a communication failure; it changes the remaining budget. If the next call cannot pass the gate, stop and retain the incomplete journey. Do not shrink allowances mid-run, truncate responses, summarize history, or reseed to manufacture completion. Preserve the **30,000-byte hard boundary**; an unexpected overshoot or transport truncation cannot count as complete live evidence.
