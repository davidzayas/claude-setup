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

## H1 — Praise without approval

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

## H2 — Revision without advancement

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

## H3 — Explicit approval advances once

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
