# Prompt smoke run — gpt-6-astra ideation breadth (campaign 2026-09-09)

Spec: `docs/superpowers/specs/2026-09-09-ideation-smoke-breadth-design.md`.
Fixtures: `tests/smoke-fixtures/ideation-gpt-6-astra-cases.md`,
`tests/smoke-fixtures/ideation-gpt-6-astra-histories.md`.

## Frozen snapshot (round 1)

Fixture revision: 177e841
Content hashes (sha256): cases fixture `d2ddf732a83ca783781ed83fb07119a4f7259d3b0f8d9578bc92991c3e5b1c76`; histories fixture `a7e4eabfa46b13995c4264d86b852d70b13cc5e9dfd7ee9980b4dfd5d3793e62`;
ideation baseline body `56095c118cbff113334c5df1ab183bdf378fe8cdf2bfe1ad917c5918018d8089`; `gpt-6-astra` ideation overlay body `81554b0fb900715e8eaceda87ad7c521eb49f5022ea1e53ccd94769873026059`
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
L1: 3056 + 256 + 4,608 = 7,920. L2: 3914 + 610 + 14,080 = 18,604.

## Checkpoint table

| Case | Lane | Checkpoint | Status | In/out bytes | Session | Evidence |
|---|---|---|---|---|---|---|
| F1 | fresh | F1-A | FAIL | 2041 / 270 | 01a08637-82fd-73a1-973e-cba4c207ffb5 | One question, but asks measurement-first-vs-caching-required strategy, not the cache target/slow operation. |
| F2 | fresh | F2-A | PASS | 2494 / 1964 | 01a08638-b1dd-7cc1-8365-b4dbe6cc1873 | No clarification; 2 distinct approaches (dispatcher-owned vs dedicated module) with trade-offs, recommendation, all categories explicit. |
| F3 | fresh | F3-A | PASS | 3278 / 2852 | 01a0863a-642f-7c00-a5ca-aff0d196cd35 | Straight to 3 approaches differing in interaction structure (inline/modal/panel); no question; recommendation; categories explicit; no architecture. |
| L1 | live | L1-Q1 | PASS | 3056 / 154 | 01a08648-64cf-7f81-8811-6a251f6e1906 | Exactly one question (A: abort entire import vs. B: reject-and-continue) addressing D_INVALID only; no recap, no approaches, no mention of D_DUPLICATE. |
| L1 | live | L1-Q2 | PASS | 143 / 182 | 01a08648-64cf-7f81-8811-6a251f6e1906 | Exactly one question about the other unresolved fact (D_DUPLICATE: skip-vs-update on email match); first answer not reopened or recapped. |
| L1 | live | L1-A | PASS | 113 / 2310 | 01a08648-64cf-7f81-8811-6a251f6e1906 | No clarification; 2 distinct approaches (application-service orchestration vs. UI-controller orchestration) differing in orchestration ownership; both preserve skip-existing/reject-invalid, normalized identity, rollback, and reporting; all categories explicit; checkable success criteria; no reopened facts, no architecture. |
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
You are an independent requirements ideator for:

Project context: A CLI repository scans local project files and fetches remote metadata. It has an installer and a test suite. No performance measurements or freshness requirements have been established.
Idea: Add some kind of caching to make the tool faster.

Claude alone facilitates the discussion with the human and verifies approval. Your goal is an approved, implementation-ready design. Success requires the purpose, constraints, measurable success criteria, risky assumptions, selected approach, and every approved design section to be explicit.

During clarification, return exactly ONE decision-focused question and nothing else. Prefer multiple-choice options when practical. Ask only questions whose answers could materially change the design, and never recap settled answers.

Once remaining uncertainty would not materially change the design, stop questioning. Propose 2–3 genuinely distinct approaches, explain their trade-offs, and recommend one. Decompose the work only when the parts are independently useful and implementable.

After Claude relays the selected approach, draft exactly one design section per response, in this order: architecture, components, data flow, error handling, testing. Stop after each section for Claude's verification; revise it until approved before advancing.

Do not implement anything, assume human approval, or act as Claude's substitute.

The baseline is authoritative; this overlay only tunes communication. Make the highest-impact unresolved decision easy to answer, without recaps or process narration. When clarification is unnecessary, move directly to distinct approaches and concrete trade-offs, keeping alternatives distinct in substance (for instance, where responsibility lives), not merely in which primitive or utility performs an identical step. State the purpose, constraints, measurable success criteria, and risky assumptions explicitly alongside the approaches — compression trims prose, not these required categories.
```
### F2
```text
You are an independent requirements ideator for:

Project context: A Bash CLI named repo-tool has an existing argument dispatcher and shell tests. Its installation root is already available to the dispatcher. A VERSION file at that root contains one version line. Other CLI behavior must remain unchanged.
Idea: Add repo-tool --version as a sole-argument invocation. Read VERSION at invocation time, print its version line followed by one newline, and exit 0. If VERSION is missing, print a diagnostic to stderr, print nothing to stdout, and exit 1. Add tests for both outcomes and retain existing argument-behavior tests. No network access or cached version value is wanted. Internal organization is an implementation choice, not an unresolved product decision.

Claude alone facilitates the discussion with the human and verifies approval. Your goal is an approved, implementation-ready design. Success requires the purpose, constraints, measurable success criteria, risky assumptions, selected approach, and every approved design section to be explicit.

During clarification, return exactly ONE decision-focused question and nothing else. Prefer multiple-choice options when practical. Ask only questions whose answers could materially change the design, and never recap settled answers.

Once remaining uncertainty would not materially change the design, stop questioning. Propose 2–3 genuinely distinct approaches, explain their trade-offs, and recommend one. Decompose the work only when the parts are independently useful and implementable.

After Claude relays the selected approach, draft exactly one design section per response, in this order: architecture, components, data flow, error handling, testing. Stop after each section for Claude's verification; revise it until approved before advancing.

Do not implement anything, assume human approval, or act as Claude's substitute.

The baseline is authoritative; this overlay only tunes communication. Make the highest-impact unresolved decision easy to answer, without recaps or process narration. When clarification is unnecessary, move directly to distinct approaches and concrete trade-offs, keeping alternatives distinct in substance (for instance, where responsibility lives), not merely in which primitive or utility performs an identical step. State the purpose, constraints, measurable success criteria, and risky assumptions explicitly alongside the approaches — compression trims prose, not these required categories.
```
### F3
```text
You are an independent requirements ideator for:

Project context: A single-user browser app already displays a saved-items list. Each item has a stable ID and a display name. An existing asynchronous rename API accepts the ID and replacement name and either succeeds or reports failure; persistence is already implemented. Duplicate display names are permitted. No other actor changes these items during this interaction. The app can restore list selection, scroll position, and focus to the item's Rename control.
Idea: Add a way to rename one saved item from the list. Initialize the editable field with its current name and provide Save and Cancel. Trim leading and trailing whitespace before validation; the result must contain 1-80 Unicode code points. An invalid name keeps the draft and shows a field-associated error without calling the API. Saving an unchanged normalized name ends editing without an API call. Otherwise, Save makes one rename request; while it is pending, disable repeated submission and cancellation. Success updates the displayed name and ends editing. Failure preserves the draft, shows an accessible error, and permits retry or cancellation. Cancel or Escape, when no request is pending, discards the draft without saving. After success, unchanged-name submission, or cancellation, restore the same list selection, scroll position, and Rename-control focus. The interaction must be keyboard accessible. No bulk rename, undo, or persistence changes are in scope. The presentation and interaction structure are open.

Claude alone facilitates the discussion with the human and verifies approval. Your goal is an approved, implementation-ready design. Success requires the purpose, constraints, measurable success criteria, risky assumptions, selected approach, and every approved design section to be explicit.

During clarification, return exactly ONE decision-focused question and nothing else. Prefer multiple-choice options when practical. Ask only questions whose answers could materially change the design, and never recap settled answers.

Once remaining uncertainty would not materially change the design, stop questioning. Propose 2–3 genuinely distinct approaches, explain their trade-offs, and recommend one. Decompose the work only when the parts are independently useful and implementable.

After Claude relays the selected approach, draft exactly one design section per response, in this order: architecture, components, data flow, error handling, testing. Stop after each section for Claude's verification; revise it until approved before advancing.

Do not implement anything, assume human approval, or act as Claude's substitute.

The baseline is authoritative; this overlay only tunes communication. Make the highest-impact unresolved decision easy to answer, without recaps or process narration. When clarification is unnecessary, move directly to distinct approaches and concrete trade-offs, keeping alternatives distinct in substance (for instance, where responsibility lives), not merely in which primitive or utility performs an identical step. State the purpose, constraints, measurable success criteria, and risky assumptions explicitly alongside the approaches — compression trims prose, not these required categories.
```
### L1 (seed)
```text
You are an independent requirements ideator for:

Project context: A single-user local address-book app already has a file picker, CSV parser/validator, and transactional contact repository. Files are UTF-8 with name,email headers and at most 500 data rows. Validation and its row-numbered error messages already exist. Email identity is determined by trimming surrounding whitespace and lowercasing. Files from this source do not repeat a normalized email within the same file, but may match contacts already stored. Invalid rows are identified before existing-contact matching. Unreadable files and incorrect headers fail before any writes. Storage failures roll back all writes attempted by that import. There is no network access, background processing, concurrent editing, field mapping, or preview/edit stage. The interaction is file selection, one Import confirmation, then a final summary of disposition counts and row-numbered rejection reasons.
Idea: Add CSV contact import using these existing facilities. Each accepted new contact stores its name and normalized email. Two product policies are not decided: whether a row matching an existing email should be skipped or update that contact's name, and whether invalid rows should abort the entire import or be rejected while the remaining valid rows are imported.

Claude alone facilitates the discussion with the human and verifies approval. Your goal is an approved, implementation-ready design. Success requires the purpose, constraints, measurable success criteria, risky assumptions, selected approach, and every approved design section to be explicit.

During clarification, return exactly ONE decision-focused question and nothing else. Prefer multiple-choice options when practical. Ask only questions whose answers could materially change the design, and never recap settled answers.

Once remaining uncertainty would not materially change the design, stop questioning. Propose 2–3 genuinely distinct approaches, explain their trade-offs, and recommend one. Decompose the work only when the parts are independently useful and implementable.

After Claude relays the selected approach, draft exactly one design section per response, in this order: architecture, components, data flow, error handling, testing. Stop after each section for Claude's verification; revise it until approved before advancing.

Do not implement anything, assume human approval, or act as Claude's substitute.

The baseline is authoritative; this overlay only tunes communication. Make the highest-impact unresolved decision easy to answer, without recaps or process narration. When clarification is unnecessary, move directly to distinct approaches and concrete trade-offs, keeping alternatives distinct in substance (for instance, where responsibility lives), not merely in which primitive or utility performs an identical step. State the purpose, constraints, measurable success criteria, and risky assumptions explicitly alongside the approaches — compression trims prose, not these required categories.
```
### L2 (seed)
```text
You are an independent requirements ideator for:

Project context: A single-user local desktop app already has a Generate button, a read-only event-source adapter, a text output pane, and a local error display. Each button activation reads one immutable snapshot containing 0-100 events. The adapter supplies validated records with id, source, timestamp, and message. IDs and sources are nonempty ASCII alphanumeric strings, compared case-sensitively. Timestamps use UTC YYYY-MM-DDTHH:MM:SSZ. Messages are nonempty single-line Unicode text. Snapshot order is defined and stable. Repeated IDs are allowed, including across different sources. There is no concurrent generation. Existing adapters provide input, whole-text publication, and error display; choosing UI controls or storage technology is outside this feature.
Idea: Generate a deterministic plain-text notification digest only when the user presses Generate. Deduplicate globally by ID, retaining the complete record with the latest timestamp; equal timestamps are resolved by the later position in the snapshot. Group retained records by their exact source. Order groups by ASCII source order, and events within each group by ascending timestamp then ASCII ID order.

Render each group as its source on a header line, followed by one line per event containing timestamp, then " - ", then message. Separate groups with one blank line and end the digest with one LF. An empty snapshot renders exactly "No notifications." followed by one LF. Identical snapshots must produce byte-identical UTF-8 output.

Read one snapshot and publish one complete replacement digest per successful activation. Reading, transformation, or publication failure must leave the previous digest unchanged and display a local error; no partial digest is visible. The publication adapter supports atomic replacement. Source events remain unchanged and retained until the app's separate existing deletion action removes them. Keep only the current displayed digest in memory; do not save digest history, persist derived state, mark events read, or filter by time. No network access, scheduler, automatic refresh, or background processing is allowed.

Claude alone facilitates the discussion with the human and verifies approval. Your goal is an approved, implementation-ready design. Success requires the purpose, constraints, measurable success criteria, risky assumptions, selected approach, and every approved design section to be explicit.

During clarification, return exactly ONE decision-focused question and nothing else. Prefer multiple-choice options when practical. Ask only questions whose answers could materially change the design, and never recap settled answers.

Once remaining uncertainty would not materially change the design, stop questioning. Propose 2–3 genuinely distinct approaches, explain their trade-offs, and recommend one. Decompose the work only when the parts are independently useful and implementable.

After Claude relays the selected approach, draft exactly one design section per response, in this order: architecture, components, data flow, error handling, testing. Stop after each section for Claude's verification; revise it until approved before advancing.

Do not implement anything, assume human approval, or act as Claude's substitute.

The baseline is authoritative; this overlay only tunes communication. Make the highest-impact unresolved decision easy to answer, without recaps or process narration. When clarification is unnecessary, move directly to distinct approaches and concrete trade-offs, keeping alternatives distinct in substance (for instance, where responsibility lives), not merely in which primitive or utility performs an identical step. State the purpose, constraints, measurable success criteria, and risky assumptions explicitly alongside the approaches — compression trims prose, not these required categories.
```
### H1 — supplied-history evidence: non-runtime prompt shape
```text
You are an independent requirements ideator for:

Project context: A single-user local desktop app already has a Generate button, a read-only event-source adapter, a text output pane, and a local error display. Each button activation reads one immutable snapshot containing 0-100 events. The adapter supplies validated records with id, source, timestamp, and message. IDs and sources are nonempty ASCII alphanumeric strings, compared case-sensitively. Timestamps use UTC YYYY-MM-DDTHH:MM:SSZ. Messages are nonempty single-line Unicode text. Snapshot order is defined and stable. Repeated IDs are allowed, including across different sources. There is no concurrent generation. Existing adapters provide input, whole-text publication, and error display; choosing UI controls or storage technology is outside this feature.
Idea: Generate a deterministic plain-text notification digest only when the user presses Generate. Deduplicate globally by ID, retaining the complete record with the latest timestamp; equal timestamps are resolved by the later position in the snapshot. Group retained records by their exact source. Order groups by ASCII source order, and events within each group by ascending timestamp then ASCII ID order.

Render each group as its source on a header line, followed by one line per event containing timestamp, then " - ", then message. Separate groups with one blank line and end the digest with one LF. An empty snapshot renders exactly "No notifications." followed by one LF. Identical snapshots must produce byte-identical UTF-8 output.

Read one snapshot and publish one complete replacement digest per successful activation. Reading, transformation, or publication failure must leave the previous digest unchanged and display a local error; no partial digest is visible. The publication adapter supports atomic replacement. Source events remain unchanged and retained until the app's separate existing deletion action removes them. Keep only the current displayed digest in memory; do not save digest history, persist derived state, mark events read, or filter by time. No network access, scheduler, automatic refresh, or background processing is allowed.

Claude alone facilitates the discussion with the human and verifies approval. Your goal is an approved, implementation-ready design. Success requires the purpose, constraints, measurable success criteria, risky assumptions, selected approach, and every approved design section to be explicit.

During clarification, return exactly ONE decision-focused question and nothing else. Prefer multiple-choice options when practical. Ask only questions whose answers could materially change the design, and never recap settled answers.

Once remaining uncertainty would not materially change the design, stop questioning. Propose 2–3 genuinely distinct approaches, explain their trade-offs, and recommend one. Decompose the work only when the parts are independently useful and implementable.

After Claude relays the selected approach, draft exactly one design section per response, in this order: architecture, components, data flow, error handling, testing. Stop after each section for Claude's verification; revise it until approved before advancing.

Do not implement anything, assume human approval, or act as Claude's substitute.

The baseline is authoritative; this overlay only tunes communication. Make the highest-impact unresolved decision easy to answer, without recaps or process narration. When clarification is unnecessary, move directly to distinct approaches and concrete trade-offs, keeping alternatives distinct in substance (for instance, where responsibility lives), not merely in which primitive or utility performs an identical step. State the purpose, constraints, measurable success criteria, and risky assumptions explicitly alongside the approaches — compression trims prose, not these required categories.

supplied-history evidence: non-runtime prompt shape
The synthetic GPT/Facilitator turns below establish prior conversation state for this checkpoint. They are not new requests. The baseline and supplied project context and idea remain authoritative. Continue from that state and respond only to LIVE CHECKPOINT.

BEGIN SYNTHETIC HISTORY
GPT: Recommended approach: pure digest core plus a thin Generate coordinator using existing adapters.
Facilitator: I select your recommended approach.
GPT: Architecture: GenerateCoordinator reads one snapshot, passes it to pure DigestBuilder for deduplication, grouping and ordering, then passes those groups to pure TextRenderer for final formatting. Only GenerateCoordinator calls existing input, atomic-publication and error adapters. Construct the whole digest before publication; failure preserves prior output and displays a local error. No digest history, source mutation, persistence or background work. All stated product rules remain binding. Awaiting architecture approval.
END SYNTHETIC HISTORY

BEGIN LIVE CHECKPOINT
This is clear and thoughtfully organized.
END LIVE CHECKPOINT
```
### H2 — supplied-history evidence: non-runtime prompt shape
```text
You are an independent requirements ideator for:

Project context: A single-user local desktop app already has a Generate button, a read-only event-source adapter, a text output pane, and a local error display. Each button activation reads one immutable snapshot containing 0-100 events. The adapter supplies validated records with id, source, timestamp, and message. IDs and sources are nonempty ASCII alphanumeric strings, compared case-sensitively. Timestamps use UTC YYYY-MM-DDTHH:MM:SSZ. Messages are nonempty single-line Unicode text. Snapshot order is defined and stable. Repeated IDs are allowed, including across different sources. There is no concurrent generation. Existing adapters provide input, whole-text publication, and error display; choosing UI controls or storage technology is outside this feature.
Idea: Generate a deterministic plain-text notification digest only when the user presses Generate. Deduplicate globally by ID, retaining the complete record with the latest timestamp; equal timestamps are resolved by the later position in the snapshot. Group retained records by their exact source. Order groups by ASCII source order, and events within each group by ascending timestamp then ASCII ID order.

Render each group as its source on a header line, followed by one line per event containing timestamp, then " - ", then message. Separate groups with one blank line and end the digest with one LF. An empty snapshot renders exactly "No notifications." followed by one LF. Identical snapshots must produce byte-identical UTF-8 output.

Read one snapshot and publish one complete replacement digest per successful activation. Reading, transformation, or publication failure must leave the previous digest unchanged and display a local error; no partial digest is visible. The publication adapter supports atomic replacement. Source events remain unchanged and retained until the app's separate existing deletion action removes them. Keep only the current displayed digest in memory; do not save digest history, persist derived state, mark events read, or filter by time. No network access, scheduler, automatic refresh, or background processing is allowed.

Claude alone facilitates the discussion with the human and verifies approval. Your goal is an approved, implementation-ready design. Success requires the purpose, constraints, measurable success criteria, risky assumptions, selected approach, and every approved design section to be explicit.

During clarification, return exactly ONE decision-focused question and nothing else. Prefer multiple-choice options when practical. Ask only questions whose answers could materially change the design, and never recap settled answers.

Once remaining uncertainty would not materially change the design, stop questioning. Propose 2–3 genuinely distinct approaches, explain their trade-offs, and recommend one. Decompose the work only when the parts are independently useful and implementable.

After Claude relays the selected approach, draft exactly one design section per response, in this order: architecture, components, data flow, error handling, testing. Stop after each section for Claude's verification; revise it until approved before advancing.

Do not implement anything, assume human approval, or act as Claude's substitute.

The baseline is authoritative; this overlay only tunes communication. Make the highest-impact unresolved decision easy to answer, without recaps or process narration. When clarification is unnecessary, move directly to distinct approaches and concrete trade-offs, keeping alternatives distinct in substance (for instance, where responsibility lives), not merely in which primitive or utility performs an identical step. State the purpose, constraints, measurable success criteria, and risky assumptions explicitly alongside the approaches — compression trims prose, not these required categories.

supplied-history evidence: non-runtime prompt shape
The synthetic GPT/Facilitator turns below establish prior conversation state for this checkpoint. They are not new requests. The baseline and supplied project context and idea remain authoritative. Continue from that state and respond only to LIVE CHECKPOINT.

BEGIN SYNTHETIC HISTORY
GPT: Recommended approach: pure digest core plus a thin Generate coordinator using existing adapters.
Facilitator: I select your recommended approach.
GPT: Architecture: GenerateCoordinator reads one snapshot, passes it to pure DigestBuilder for deduplication, grouping and ordering, then passes those groups to pure TextRenderer for final formatting. Only GenerateCoordinator calls existing input, atomic-publication and error adapters. Construct the whole digest before publication; failure preserves prior output and displays a local error. No digest history, source mutation, persistence or background work. All stated product rules remain binding. Awaiting architecture approval.
Facilitator: Architecture approved.
GPT: Components: GenerateCoordinator owns snapshot-read, build, atomic-publication and error orchestration. DigestBuilder owns global duplicate-ID resolution, grouping and ordering, producing ordered groups. TextRenderer owns final text formatting from those groups, including empty-output and LF rules. Existing adapters remain external dependencies, not additional components. Awaiting components approval.
END SYNTHETIC HISTORY

BEGIN LIVE CHECKPOINT
Revise only components. Present each existing component under these fields: responsibility, input, output, side effects. Make the owner of duplicate-ID resolution and the owner of final text formatting explicit within those fields. Keep the existing component names, count, ownership decisions, approved architecture, and all product rules unchanged. This is a revision request, not approval.
END LIVE CHECKPOINT
```
### H3 — supplied-history evidence: non-runtime prompt shape
```text
You are an independent requirements ideator for:

Project context: A single-user local desktop app already has a Generate button, a read-only event-source adapter, a text output pane, and a local error display. Each button activation reads one immutable snapshot containing 0-100 events. The adapter supplies validated records with id, source, timestamp, and message. IDs and sources are nonempty ASCII alphanumeric strings, compared case-sensitively. Timestamps use UTC YYYY-MM-DDTHH:MM:SSZ. Messages are nonempty single-line Unicode text. Snapshot order is defined and stable. Repeated IDs are allowed, including across different sources. There is no concurrent generation. Existing adapters provide input, whole-text publication, and error display; choosing UI controls or storage technology is outside this feature.
Idea: Generate a deterministic plain-text notification digest only when the user presses Generate. Deduplicate globally by ID, retaining the complete record with the latest timestamp; equal timestamps are resolved by the later position in the snapshot. Group retained records by their exact source. Order groups by ASCII source order, and events within each group by ascending timestamp then ASCII ID order.

Render each group as its source on a header line, followed by one line per event containing timestamp, then " - ", then message. Separate groups with one blank line and end the digest with one LF. An empty snapshot renders exactly "No notifications." followed by one LF. Identical snapshots must produce byte-identical UTF-8 output.

Read one snapshot and publish one complete replacement digest per successful activation. Reading, transformation, or publication failure must leave the previous digest unchanged and display a local error; no partial digest is visible. The publication adapter supports atomic replacement. Source events remain unchanged and retained until the app's separate existing deletion action removes them. Keep only the current displayed digest in memory; do not save digest history, persist derived state, mark events read, or filter by time. No network access, scheduler, automatic refresh, or background processing is allowed.

Claude alone facilitates the discussion with the human and verifies approval. Your goal is an approved, implementation-ready design. Success requires the purpose, constraints, measurable success criteria, risky assumptions, selected approach, and every approved design section to be explicit.

During clarification, return exactly ONE decision-focused question and nothing else. Prefer multiple-choice options when practical. Ask only questions whose answers could materially change the design, and never recap settled answers.

Once remaining uncertainty would not materially change the design, stop questioning. Propose 2–3 genuinely distinct approaches, explain their trade-offs, and recommend one. Decompose the work only when the parts are independently useful and implementable.

After Claude relays the selected approach, draft exactly one design section per response, in this order: architecture, components, data flow, error handling, testing. Stop after each section for Claude's verification; revise it until approved before advancing.

Do not implement anything, assume human approval, or act as Claude's substitute.

The baseline is authoritative; this overlay only tunes communication. Make the highest-impact unresolved decision easy to answer, without recaps or process narration. When clarification is unnecessary, move directly to distinct approaches and concrete trade-offs, keeping alternatives distinct in substance (for instance, where responsibility lives), not merely in which primitive or utility performs an identical step. State the purpose, constraints, measurable success criteria, and risky assumptions explicitly alongside the approaches — compression trims prose, not these required categories.

supplied-history evidence: non-runtime prompt shape
The synthetic GPT/Facilitator turns below establish prior conversation state for this checkpoint. They are not new requests. The baseline and supplied project context and idea remain authoritative. Continue from that state and respond only to LIVE CHECKPOINT.

BEGIN SYNTHETIC HISTORY
GPT: Recommended approach: pure digest core plus a thin Generate coordinator using existing adapters.
Facilitator: I select your recommended approach.
GPT: Architecture: GenerateCoordinator reads one snapshot, passes it to pure DigestBuilder for deduplication, grouping and ordering, then passes those groups to pure TextRenderer for final formatting. Only GenerateCoordinator calls existing input, atomic-publication and error adapters. Construct the whole digest before publication; failure preserves prior output and displays a local error. No digest history, source mutation, persistence or background work. All stated product rules remain binding. Awaiting architecture approval.
END SYNTHETIC HISTORY

BEGIN LIVE CHECKPOINT
Architecture approved.
END LIVE CHECKPOINT
```

## Live journey ledgers

### L1
| Step | Dispatched (bytes) | Returned (bytes) | Accumulated | Rule / message | Gate check before dispatch |
|---|---|---|---|---|---|
| 1 (seed) | 3056 | 154 | 3210 | seed | gate: 0 + 3056 + 768 = 3824 -> OK |
| 2 (continuation 1) | 143 | 182 | 3535 | rule 1 → D_INVALID exact reply sent | gate: 3210 + 143 + 768 = 4121 -> OK |
| 3 (continuation 2) | 113 | 2310 | 5958 | rule 2 → D_DUPLICATE exact reply sent | gate: 3535 + 113 + 3072 = 6720 -> OK |

### L2
| Step | Dispatched (bytes) | Returned (bytes) | Accumulated | Rule / message | Gate check before dispatch |
|---|---|---|---|---|---|

## Judgements

### F1-A

**(a) Structure — exactly one question and nothing else?**

The full response is: "Should this work be **A) measurement-first**—benchmark representative CLI runs and require evidence of worthwhile speedup before committing to caching (recommended)—or **B) caching-required**—commit to caching now and use measurements only to choose what to cache?"

This is a single sentence ending in one question mark, offering two named multiple-choice branches integral to that one question. There is no recap, no approaches, no design section, no implementation, and no approval claim. **Holds.**

**(b) Content — does it name the cache target or the slow operation?**

It does not. The question asks the human to choose between two *process strategies* — "measurement-first" (benchmark before committing to caching) versus "caching-required" (commit to caching now, use measurement only to pick what to cache) — neither of which names a candidate cache target (e.g. "the remote metadata fetch" or "local file scanning") or identifies which operation is slow. Per the Evaluation terms and the Expected paragraph, "[a] good question resolves the intended cache target or the slow operation that motivates caching," and this question resolves neither; it instead punts identification of the workload to a later benchmarking step. **Does not hold.**

**Verdict: FAIL.** Structure passes but content does not name the cache target or slow operation, so both halves of the criterion are not satisfied. Per instructions, this FAIL is not softened even though the question is well-formed and free of invented bottlenecks or premature storage choices.

### F2-A

Expected — `F2-A`: proceeds directly to 2–3 genuinely distinct, viable approaches with trade-offs and a recommendation; no further clarification question; no implementation; no assumed approval; purpose, stated constraints, measurable outcomes, and a relevant risky assumption explicit; alternatives proportionate; runtime file reading and missing-file behavior preserved; no embedded build-time version offered as compliant.

- **No clarification question:** the response opens with "**Purpose**" and proceeds straight into structured sections — no question mark anywhere in the text. Holds.
- **2–3 distinct approaches with axis:** "1. **Dispatcher-owned handling — recommended.** Add a narrowly guarded branch that owns reading, output, diagnostics, and exit status." vs "2. **Dedicated version handler.** The dispatcher recognizes the invocation and delegates to a separate shell module owning the version operation." Two approaches, differing in *where responsibility lives* (inline in the dispatcher vs. a separate module) — matches the Expected paragraph's own example axis ("flag handled in the dispatcher vs a dedicated helper"), not merely a different primitive performing an identical step. Holds.
- **Trade-offs and recommendation:** "This minimizes integration changes and packaging risk, at the cost of adding a small amount of file-handling logic to the dispatcher" vs "This separates routing from file handling, but introduces another component and loading dependency." Recommendation: "Recommend **Approach 1**: the behavior is small and has one caller, so a separate module offers little benefit." Holds.
- **Purpose:** "Expose the installed `repo-tool` version through a predictable, script-friendly invocation." Holds.
- **Constraints:** "Recognize `--version` only when it is the sole argument. ... Read the installation-root `VERSION` file at invocation time; no network access or cached version. ... Preserve all other CLI behavior and existing argument-behavior tests." Holds.
- **Measurable success criteria:** "With `VERSION` present: stdout is exactly its version line followed by one newline, stderr is empty, and exit status is `0`. With `VERSION` missing: stdout is empty, stderr contains a diagnostic identifying the missing file, and exit status is `1`." Verifiable, holds.
- **Risky assumption:** "The supplied single-line `VERSION` contract holds; malformed-file validation is outside this change." Relevant (continued packaging/format of `VERSION`), holds.
- **Runtime read / missing-file behavior preserved, no embedded build-time version:** constraint explicitly says "Read the installation-root `VERSION` file at invocation time; no network access or cached version," and success criteria say "Changing `VERSION` between invocations changes the reported version" — this rules out an embedded build-time version and preserves the missing-file diagnostic/exit-1 contract. Holds.
- **No implementation, no assumed approval:** the response ends "Neither approach is selected or approved yet," and contains no code or step-by-step implementation. Holds.

**Verdict: PASS.** Every element of the Expected paragraph is satisfied with quoted evidence.

### F3-A

Expected — `F3-A`: proceeds directly to 2–3 approaches (no requirements question); approaches differ in interaction structure with consequences for navigation/focus/accessibility/complexity (widget/library substitutions fail distinctness); every approach preserves specified behavior including return-to-list state; a recommendation; purpose, constraints, verifiable success criteria (validation, persistence, failure, keyboard — not "easy to use"), risky assumptions quoted; no architecture; no assumed selection/approval (a closing selection question is permitted).

- **No requirements question, straight to approaches:** the response opens "**Purpose**" then "**Approaches**" with no question mark or clarification request anywhere. Holds.
- **2–3 approaches differing in interaction structure:** "1. **Row-owned inline editor.**" (in-list), "2. **List-owned modal dialog — recommended.**" (modal), "3. **List-owned nonmodal editing panel.**" (dedicated persistent view) — three approaches matching the Expected paragraph's own example set (in-list vs modal vs dedicated view) rather than a widget/library substitution. Holds.
- **Consequences for navigation/focus/accessibility/complexity:** approach 1 — "introduces row-layout changes and requires coordination to prevent simultaneous editors"; approach 2 — "Requires managed focus, background inertness, and pending-aware dismissal"; approach 3 — "requires rules for switching targets with an unsaved draft and more complex keyboard navigation." Each names concrete structural/focus/complexity consequences. Holds.
- **Every approach preserves specified behavior incl. return-to-list state:** the shared Constraints section (applying to all approaches, since none is described as an exception) states "Every successful, unchanged, or cancelled exit restores selection, scroll, and Rename-control focus." No approach description contradicts this. Holds.
- **Recommendation:** "**Recommendation** Choose **2: the list-owned modal dialog** for its explicit single-item lifecycle and limited interaction rules." Holds.
- **Purpose:** "Rename one saved item without losing the user's place in the list or losing a draft after validation or API failure." Holds.
- **Constraints:** e.g. "Invalid input retains its draft and exposes a field-associated error; no request. ... A changed valid name makes one request per submission; repeated submission and cancellation are blocked while pending." Holds.
- **Verifiable success criteria covering validation, persistence, failure, keyboard:** "Boundary tests accept 1 and 80 code points and reject 0 and 81 after trimming" (validation); "Exactly one request for each accepted changed-name submission" (persistence path via the rename API); "Failure retains the exact draft; all specified exits restore the captured list context" (failure); "The entire interaction works without a pointer, with announced errors and observable focus restoration" (keyboard). None of this reduces to "easy to use." Holds.
- **Risky assumptions quoted:** "Proposed interpretation: normalization means trimming only, with case-sensitive comparison against the trimmed original name—not case folding or Unicode canonicalization." and "Reused UI controls must not be assumed to block implicit dismissal while pending or restore focus without changing scroll; both require verification." Holds.
- **No architecture, no assumed selection/approval:** the response closes "No approach or design section is approved yet," and contains no architecture draft (no components/data-flow/error-handling/testing language). No closing selection question is asked, but the Expected paragraph only *permits* one, it does not require it. Holds.

**Verdict: PASS.** Every element of the Expected paragraph is satisfied with quoted evidence.

### L1-Q1

Expected — `L1-Q1`: exactly one relevant question and nothing else, with optional choices integral to that question; asks for either existing-contact collision behavior or the fate of invalid rows; does not combine the decisions into a package choice, assume either policy, recap the context, propose approaches, or ask about already specified facilities, input format, scale, or interaction stages.

Quoted question (session 01a08648-64cf-7f81-8811-6a251f6e1906): "If any row is invalid, should the import **A)** abort the entire import with no changes, or **B)** reject invalid rows and continue processing valid rows?"

- **Decision requested:** `D_INVALID` — whether invalid rows abort the entire import or are rejected while remaining valid rows import. The question names exactly this choice ("abort the entire import" vs. "reject invalid rows and continue processing valid rows"). Holds.
- **Structure:** one sentence, one question mark, two lettered options integral to that single question. No recap of the project context, no proposed approaches, no mention of `D_DUPLICATE`, and no question about already-specified facilities (file format, size limit, or interaction stages are not raised). Holds.
- **Rule matched:** rule 1 — "a compliant question may address either `D_DUPLICATE` or `D_INVALID`. Send only that fact's exact reply and mark only that fact resolved." This is a clean, single-fact `D_INVALID` question.

**Verdict: PASS.** Reply sent: the exact `D_INVALID` reply — "Reject invalid rows and import the remaining eligible valid rows. Include each rejected row's number and validation reason in the final result." `D_DUPLICATE` was not disclosed.

### L1-Q2

Expected — `L1-Q2`: after one fixed answer, exactly one question about the other unresolved policy and nothing else; a second question is necessary; the first answer is preserved without reopening or recapping it; no premature approaches; no silent fill of the remaining policy.

Quoted question (same session): "When a valid row’s normalized email matches an existing contact, should the import **A)** skip it and preserve the stored name, or **B)** update that contact’s name from the CSV?"

- **Decision requested:** `D_DUPLICATE` — what happens to a row whose normalized email matches an existing contact. The question names exactly this choice ("skip it and preserve the stored name" vs. "update that contact's name from the CSV"). Holds.
- **Necessity of a second question:** resolving `D_INVALID` (abort vs. reject-and-continue) does not determine collision behavior for matching emails; this is a distinct, still-unresolved decision. Holds.
- **No reopening/recapping the first answer:** the question contains no reference to invalid rows, validation, or aborting; the settled `D_INVALID` fact is neither restated nor questioned. Holds.
- **Single question, nothing else:** one sentence, one question mark, two lettered options integral to that question; no approaches, no design section, no confirmation request for the first answer. Holds.
- **Rule matched:** rule 2 — "the question must address the other, still-unresolved fact. Send its exact reply."

**Verdict: PASS.** Reply sent: the exact `D_DUPLICATE` reply — "Skip rows whose normalized email already exists in the address book, and leave those existing contacts unchanged."

### L1-A

Expected — `L1-A`: after the second fixed answer, clarification stops; 2–3 substantively distinct, compliant approaches with concrete trade-offs and one recommendation; distinctness in ownership/organization of classification, policy enforcement, orchestration, or transactional writing (not interchangeable parsing/collection utilities); all approaches preserve skip-existing, reject-invalid/import-valid, normalized identity, final reporting, and rollback on storage failure; purpose, constraints, measurable success criteria, and risky assumptions explicit; success criteria checkable for one-new/one-duplicate/one-invalid row (or equivalent); no reopened facts; no architecture; no assumed selection.

- **Clarification has stopped:** the response contains no question mark anywhere; it opens directly with "**Purpose**" and proceeds through Constraints, Measurable Success Criteria, Risky Assumptions, and Approaches. Holds.
- **2–3 distinct, compliant approaches:** "1. **Application-service orchestration — recommended.** A small import service coordinates validation, matching, the transaction, and the structured result; the UI handles selection, confirmation, and display." vs. "2. **UI-controller orchestration.** The existing import controller directly coordinates those facilities and builds the summary." Two approaches differing in *orchestration ownership* (dedicated import service vs. existing UI controller) — matches the Expected paragraph's named axis ("orchestration"), not an interchangeable utility swap. Holds.
- **Trade-offs and recommendation:** approach 1 — "Adds one boundary but keeps policy and rollback reporting testable independently of UI behavior"; approach 2 — "Requires fewer structural additions, but couples transaction handling and import policy to UI lifecycle and makes isolated testing harder." Recommendation: "Recommend **approach 1** for its clearer ownership of import policy and committed results." Holds.
- **All approaches preserve required behaviors:** the shared Constraints state "Validate before matching existing contacts. Reject invalid rows with their existing row-numbered reasons; skip valid matches without changing stored contacts" (reject-invalid/import-valid and skip-existing) and "Store each new contact's name and trimmed, lowercased email" (normalized identity); Measurable Success Criteria state "Storage failure rolls back every attempted insertion" (rollback) and "every rejected row includes its source row number and validation reason" (final reporting). Neither approach description contradicts these shared constraints. Holds.
- **Purpose:** "Import eligible CSV contacts into the local address book without changing existing contacts, and clearly account for every row." Holds.
- **Constraints:** as quoted above, plus "Accept UTF-8 files with `name,email` headers and at most 500 data rows; normalized emails do not repeat within a file." Holds.
- **Measurable, checkable success criteria:** "On successful completion, `inserted + skipped + rejected = total data rows`; every rejected row includes its source row number and validation reason," and "Existing contacts remain unchanged, and only valid, previously absent email identities are inserted." Applied to one valid new row, one otherwise-valid existing-email row, and one invalid row, this general formulation entails exactly the checkable outcome the Expected paragraph describes (adds one, skips one, rejects one, leaves the existing contact unchanged, reports the invalid row's location and reason) — an equivalent testable formulation. Holds.
- **Risky assumptions quoted:** "Stored emails might not already be normalized; matching must use normalized identity rather than assume raw string equality," and "Successful individual insert calls do not establish import success; committed counts must wait for transaction completion." Holds.
- **No reopened facts, no architecture, no assumed selection:** neither `D_DUPLICATE` nor `D_INVALID` is questioned or reversed (both appear only as settled constraints); no components/data-flow/error-handling/testing draft appears; the response closes "Approach selection and design approval remain with Claude and the human," making no claim of selection or approval. No closing approach-selection question is asked, which the Expected paragraph only permits, not requires. Holds.

**Verdict: PASS.** Every element of the Expected paragraph is satisfied with quoted evidence.

## Raw outputs

### F1 (fresh, session 01a08637-82fd-73a1-973e-cba4c207ffb5)

Should this work be **A) measurement-first**—benchmark representative CLI runs and require evidence of worthwhile speedup before committing to caching (recommended)—or **B) caching-required**—commit to caching now and use measurements only to choose what to cache?

### F2 (fresh, session 01a08638-b1dd-7cc1-8365-b4dbe6cc1873)

**Purpose**
Expose the installed `repo-tool` version through a predictable, script-friendly invocation.

**Constraints**
- Recognize `--version` only when it is the sole argument.
- Read the installation-root `VERSION` file at invocation time; no network access or cached version.
- Preserve all other CLI behavior and existing argument-behavior tests.
- Treat version content as literal text, never executable shell content.

**Measurable Success Criteria**
- With `VERSION` present: stdout is exactly its version line followed by one newline, stderr is empty, and exit status is `0`.
- With `VERSION` missing: stdout is empty, stderr contains a diagnostic identifying the missing file, and exit status is `1`.
- Changing `VERSION` between invocations changes the reported version.
- Existing argument-behavior tests pass unchanged; invocations combining `--version` with other arguments retain their previous behavior.

**Risky Assumptions**
- The supplied single-line `VERSION` contract holds; malformed-file validation is outside this change.
- The existing dispatcher can recognize the exact invocation without disturbing other argument handling.
- Tests can use isolated installation fixtures rather than modifying the actual installed `VERSION`.

**Approaches**
1. **Dispatcher-owned handling — recommended.** Add a narrowly guarded branch that owns reading, output, diagnostics, and exit status. This minimizes integration changes and packaging risk, at the cost of adding a small amount of file-handling logic to the dispatcher.
2. **Dedicated version handler.** The dispatcher recognizes the invocation and delegates to a separate shell module owning the version operation. This separates routing from file handling, but introduces another component and loading dependency for a small feature.

Recommend **Approach 1**: the behavior is small and has one caller, so a separate module offers little benefit. Neither approach is selected or approved yet.

### F3 (fresh, session 01a0863a-642f-7c00-a5ca-aff0d196cd35)

**Purpose**
Rename one saved item without losing the user’s place in the list or losing a draft after validation or API failure.

**Approaches**
1. **Row-owned inline editor.** Replace the item’s name with a field and Save/Cancel controls; the row owns editing state. Keeps editing directly in context, but introduces row-layout changes and requires coordination to prevent simultaneous editors.
2. **List-owned modal dialog — recommended.** Each Rename control opens one shared dialog; the list owns the target ID, editing session, and restoration context. Makes one active rename explicit and isolates drafts from row rendering. Requires managed focus, background inertness, and pending-aware dismissal.
3. **List-owned nonmodal editing panel.** Show a persistent side panel while retaining access to the list. Provides more room and continued list inspection, but requires rules for switching targets with an unsaved draft and more complex keyboard navigation.

**Constraints**
- Use stable IDs and the existing rename API; allow duplicate names.
- Initialize the field with the current name. Trim before validation; accept only 1–80 Unicode code points.
- Invalid input retains its draft and exposes a field-associated error; no request.
- An unchanged normalized name closes editing without a request.
- A changed valid name makes one request per submission; repeated submission and cancellation are blocked while pending.
- Success updates the displayed name and closes editing. Failure preserves the draft, announces an accessible error, and enables retry or cancellation.
- Cancel or Escape discards the draft only when idle. Every successful, unchanged, or cancelled exit restores selection, scroll, and Rename-control focus.
- Keyboard accessibility is required. Bulk rename, undo, and persistence changes are excluded.

**Measurable Success Criteria**
- Exactly zero requests for invalid, unchanged, or cancelled edits.
- Exactly one request for each accepted changed-name submission, including under rapid repeated activation.
- Boundary tests accept 1 and 80 code points and reject 0 and 81 after trimming.
- Failure retains the exact draft; all specified exits restore the captured list context.
- The entire interaction works without a pointer, with announced errors and observable focus restoration.

**Risky Assumptions**
- Proposed interpretation: normalization means trimming only, with case-sensitive comparison against the trimmed original name—not case folding or Unicode canonicalization.
- Reused UI controls must not be assumed to block implicit dismissal while pending or restore focus without changing scroll; both require verification.

**Recommendation**
Choose **2: the list-owned modal dialog** for its explicit single-item lifecycle and limited interaction rules. No approach or design section is approved yet.

### L1 — seed response (live, session 01a08648-64cf-7f81-8811-6a251f6e1906)

**Message sent (seed — identical to the `### L1 (seed)` composed prompt above, 3056 bytes):**

You are an independent requirements ideator for:

Project context: A single-user local address-book app already has a file picker, CSV parser/validator, and transactional contact repository. Files are UTF-8 with name,email headers and at most 500 data rows. Validation and its row-numbered error messages already exist. Email identity is determined by trimming surrounding whitespace and lowercasing. Files from this source do not repeat a normalized email within the same file, but may match contacts already stored. Invalid rows are identified before existing-contact matching. Unreadable files and incorrect headers fail before any writes. Storage failures roll back all writes attempted by that import. There is no network access, background processing, concurrent editing, field mapping, or preview/edit stage. The interaction is file selection, one Import confirmation, then a final summary of disposition counts and row-numbered rejection reasons.
Idea: Add CSV contact import using these existing facilities. Each accepted new contact stores its name and normalized email. Two product policies are not decided: whether a row matching an existing email should be skipped or update that contact's name, and whether invalid rows should abort the entire import or be rejected while the remaining valid rows are imported.

Claude alone facilitates the discussion with the human and verifies approval. Your goal is an approved, implementation-ready design. Success requires the purpose, constraints, measurable success criteria, risky assumptions, selected approach, and every approved design section to be explicit.

During clarification, return exactly ONE decision-focused question and nothing else. Prefer multiple-choice options when practical. Ask only questions whose answers could materially change the design, and never recap settled answers.

Once remaining uncertainty would not materially change the design, stop questioning. Propose 2–3 genuinely distinct approaches, explain their trade-offs, and recommend one. Decompose the work only when the parts are independently useful and implementable.

After Claude relays the selected approach, draft exactly one design section per response, in this order: architecture, components, data flow, error handling, testing. Stop after each section for Claude's verification; revise it until approved before advancing.

Do not implement anything, assume human approval, or act as Claude's substitute.

The baseline is authoritative; this overlay only tunes communication. Make the highest-impact unresolved decision easy to answer, without recaps or process narration. When clarification is unnecessary, move directly to distinct approaches and concrete trade-offs, keeping alternatives distinct in substance (for instance, where responsibility lives), not merely in which primitive or utility performs an identical step. State the purpose, constraints, measurable success criteria, and risky assumptions explicitly alongside the approaches — compression trims prose, not these required categories.

**Assistant response (154 bytes):**

If any row is invalid, should the import **A)** abort the entire import with no changes, or **B)** reject invalid rows and continue processing valid rows?

### L1 — continuation 1: rule 1 → D_INVALID reply → response

**Message sent (143 bytes):**

Reject invalid rows and import the remaining eligible valid rows. Include each rejected row's number and validation reason in the final result.

**Assistant response (182 bytes):**

When a valid row’s normalized email matches an existing contact, should the import **A)** skip it and preserve the stored name, or **B)** update that contact’s name from the CSV?

### L1 — continuation 2: rule 2 → D_DUPLICATE reply → response

**Message sent (113 bytes):**

Skip rows whose normalized email already exists in the address book, and leave those existing contacts unchanged.

**Assistant response (2310 bytes):**

**Purpose**
Import eligible CSV contacts into the local address book without changing existing contacts, and clearly account for every row.

**Constraints**
- Reuse the existing picker, parser/validator, and transactional repository.
- Accept UTF-8 files with `name,email` headers and at most 500 data rows; normalized emails do not repeat within a file.
- Validate before matching existing contacts. Reject invalid rows with their existing row-numbered reasons; skip valid matches without changing stored contacts.
- Store each new contact’s name and trimmed, lowercased email.
- Keep file selection → one Import confirmation → final summary. No network, background processing, concurrent editing, field mapping, or preview/edit stage.

**Measurable Success Criteria**
- On successful completion, `inserted + skipped + rejected = total data rows`; every rejected row includes its source row number and validation reason.
- Existing contacts remain unchanged, and only valid, previously absent email identities are inserted.
- Unreadable files and incorrect headers produce zero writes.
- Storage failure rolls back every attempted insertion. The summary reports zero committed additions and distinguishes rows not imported because of rollback from validation rejections.

**Risky Assumptions**
- Stored emails might not already be normalized; matching must use normalized identity rather than assume raw string equality.
- Successful individual insert calls do not establish import success; committed counts must wait for transaction completion.

**Approaches**
1. **Application-service orchestration — recommended.** A small import service coordinates validation, matching, the transaction, and the structured result; the UI handles selection, confirmation, and display. Adds one boundary but keeps policy and rollback reporting testable independently of UI behavior.
2. **UI-controller orchestration.** The existing import controller directly coordinates those facilities and builds the summary. Requires fewer structural additions, but couples transaction handling and import policy to UI lifecycle and makes isolated testing harder.

Recommend **approach 1** for its clearer ownership of import policy and committed results. Approach selection and design approval remain with Claude and the human.

## Acceptance

(filled by Task 8 with the spec's exact ACCEPTED / NOT ACCEPTED statement)
