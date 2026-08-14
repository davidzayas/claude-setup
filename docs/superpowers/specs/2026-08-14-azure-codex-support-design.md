# Azure-Hosted GPT Support Design

Ideation: gpt-5.6-sol via codex MCP · Facilitation: Claude

Status: Approved by user 2026-08-14

Seed: per-file update list from reviewing the owner's
codex-azure-setup-findings.md (machine migration to an Azure OpenAI
deployment, verified working 2026-08-14).

Selected approach: explicit alias registry (over separate deployment/family
fields and per-deployment overlay duplication).

## Architecture

The repository remains a provider-neutral, policy-driven pipeline. Azure
support adds no runtime integration or installer ownership of `~/.codex`; it
documents and governs how existing Codex MCP calls are routed and diagnosed.

The selected design separates two identities:

- **Dispatch model:** resolved by existing precedence and passed unchanged
  to Codex. Under Azure, this is the deployment name.
- **Overlay model:** derived through a single-hop, exact alias such as
  `gpt_model_alias: production-gpt=gpt-5.6-sol`. If no alias matches, it
  equals the dispatch model.

Alias resolution lives exclusively in CLAUDE.md's "GPT model routing"
policy. It affects only prompt-overlay selection and missing-variant TODO
identity; it never changes the model sent to Codex. Thus an aliased Azure
deployment selects the existing family overlay without causing a 404 or
spurious deployment-named TODO. OpenAI configurations and deployments
already named after their family continue unchanged. The five prompt files
retain their current overlay blocks.

Operational support remains documentation and prompt-policy work: Azure
setup guidance explains Codex configuration, version pinning, environment
delivery, and binary verification; GPT-facing roles classify failures before
applying retries. Installation scripts continue managing only `~/.claude`.

Success means an arbitrary Azure deployment can use the correct family
overlay while receiving its real deployment name on the wire, existing
OpenAI routing remains compatible, and retry guidance distinguishes
configuration/service failures from oversized payloads.

Risky assumptions are explicit: aliases are manually maintained, exact, and
non-transitive; one active Codex provider determines the meaning of a
deployment name; and Codex exposes no reliable family metadata requiring
automatic discovery.

## Components

- **CLAUDE.md — routing authority.** Define optional, repeatable
  `gpt_model_alias: <deployment>=<family>` entries and the exact single-hop
  lookup rule. The existing precedence still resolves the dispatch model
  first; aliasing then derives the overlay/TODO model. No alias changes the
  value sent to Codex.

- **skills/gpt-brainstorming/SKILL.md — ideation caller.** Apply the central
  alias rule when reporting variant status, and classify environment,
  pre-inference 400, and 429 failures as stop-and-report outcomes. Preserve
  all baseline and overlay blocks unchanged.

- **commands/gpt-brainstorm.md and commands/adversarial-review.md — user
  entry points.** Add a concise warning that Azure `--model` values are
  deployment names, not underlying family IDs. Their routing prose delegates
  alias interpretation to CLAUDE.md; prompt blocks remain unchanged.

- **agents/codex-adversary.md — review failure policy.** Replace the
  timeout-only heuristic with explicit failure classes. It also identifies
  MCP/CLI binary split-brain as a diagnostic when interactive Codex succeeds
  but MCP fails. Review prompt blocks and read-only boundaries remain
  unchanged.

- **README.md — adoption requirements.** Describe OpenAI-hosted and
  Azure-hosted prerequisites, link the Azure guide, and prominently warn
  that Codex CLI `0.147.0` is incompatible with Azure while `0.146.1` is
  the verified pin.

- **docs/azure-openai-codex.md — Azure runbook.** Provide sanitized inline
  TOML examples, `/openai/v1` and Responses API requirements,
  deployment-name semantics, environment-delivery options, restart
  requirements, version verification, PATH/binary checks, and request-level
  verification. No standalone live configuration or secrets are committed.

- **TODO.md — temporary compatibility debt.** Record removal of the
  `0.146.1` pin after the cited upstream Codex issues are fixed and a newer
  release passes Azure verification.

- **tests/prompt-contract-test.sh — static contract guard.** Add one guard
  that rejects malformed active alias lines while allowing the registry to
  be empty. Existing routing, marker, prompt-size, and TODO checks remain
  intact.

- **install.sh, uninstall.sh, and managed-files.sh — unchanged boundary.**
  They continue managing only `~/.claude`; Codex provider configuration and
  credentials remain adopter-owned.

## Data Flow

1. The adopter configures Codex for one provider. For Azure,
   `~/.codex/config.toml` names the Azure provider and deployment, while the
   API key enters the environment before Claude Code starts. Claude Code
   launches the MCP wrapper, which resolves its Codex binary and sends
   requests to the deployment's `/openai/v1/responses` endpoint.

2. A GPT-facing role resolves the **dispatch model** using existing
   precedence: explicit invocation override, then its `gpt_*_model` default,
   then the Codex CLI default. Slash-command `--model` values and Azure role
   defaults contain deployment names.

3. The caller searches CLAUDE.md for an exact alias whose left side equals
   the dispatch model. A match supplies the **overlay model**; otherwise the
   dispatch model itself becomes the overlay model. Resolution is
   single-hop.

4. The caller selects an overlay by exact match against the overlay model:

   - Match: compose generic baseline followed by the existing overlay.
   - No match: warn before dispatch, use the baseline alone, and record the
     missing variant under the alias-resolved overlay model according to
     existing TODO ownership rules.

5. The Codex MCP call receives the dispatch model only. The overlay model is
   prompt metadata and never crosses the transport boundary as the requested
   model.

6. The response returns to the owning role for its existing behavior:
   facilitated ideation, second-opinion synthesis, or adversarial-review
   quality gating. The outcome is classified before any retry decision.

Example: `team-gpt-prod` aliased to `gpt-5.6-sol` sends `team-gpt-prod` to
Azure while selecting the `gpt-5.6-sol` overlay. A deployment already named
`gpt-5.6-sol` follows the same path without an alias.

## Error Handling

Failures are classified before any retry:

- **Alias configuration:** Malformed alias lines or conflicting mappings for
  one deployment stop dispatch with a configuration error; callers never
  guess a family. Absence of an alias is valid and falls back to exact
  dispatch-model matching. Absence of a matching overlay is also non-fatal:
  warn, use the baseline, and record the alias-resolved TODO.

- **Environment/authentication:** A missing `AZURE_OPENAI_API_KEY`, stale
  inherited environment, or request-time authentication failure stops the
  GPT stage and reports the corrective action. MCP "Connected" proves only
  the handshake, not credential validity. Restarting Claude Code after
  environment changes is required; payload splitting is prohibited.

- **Pre-inference HTTP errors:** A 400, invalid endpoint/protocol response,
  or deployment 404 stops immediately. The report should distinguish likely
  causes: Codex `0.147.0`'s empty tool description defect, a base URL
  lacking `/openai/v1`, a deployment without `/v1/responses`, or passing a
  family ID instead of the Azure deployment name. These failures are never
  retried by splitting.

- **429 capacity failures:** Quota, credit, or TPM exhaustion stops and
  reports the service limit. It is not treated as a payload-size problem and
  receives no automatic split-and-retry.

- **Timeouts and size:** Payloads remain at or below the 20KB working target
  and never cross the 30KB hard boundary. Oversized work is split
  proactively into independent sessions. A silent timeout may be retried
  only after reducing and separately scoping the payload; the unchanged
  request is never resent. A timeout already within budget is reported as an
  outage.

- **Binary split-brain:** If interactive Codex works while MCP fails,
  compare the executable path and version seen by each environment. Report a
  PATH/version mismatch explicitly, correct the wrapper or PATH, and restart
  Claude Code before verification.

Any failure without a substantive GPT response remains distinct from a
successful empty result: ideation stops, and review reports "Codex didn't
respond" rather than "found nothing." Existing malformed-review response
handling remains unchanged.

## Testing

Automated verification remains lightweight and dependency-free:

- Extend `tests/prompt-contract-test.sh` with one alias-format guard. Every
  active alias line must match exactly one non-whitespace deployment, `=`,
  and one non-whitespace family; zero aliases remains valid.
- Run the full existing prompt-contract suite to prove model defaults,
  overlay markers, prompt budgets, TODO schema, and read-only contracts
  remain intact.
- Run install and uninstall regression suites to confirm the managed-file
  boundary remains unchanged and no Codex configuration enters installer
  scope.
- Inspect the diff to verify existing baseline and overlay blocks are
  byte-for-byte unchanged.

A manual routing matrix validates policy behavior:

| Scenario | Dispatch model | Overlay/TODO model | Expected result |
|---|---|---|---|
| OpenAI family ID, no alias | Family ID | Family ID | Existing overlay |
| Azure deployment with alias | Deployment | Family ID | Existing overlay; no spurious TODO |
| Azure deployment without alias | Deployment | Deployment | Baseline plus deployment-keyed TODO |
| Azure `--model` override with alias | Override deployment | Aliased family | Deployment sent; family overlay |
| Malformed/conflicting alias | None | None | Stop with configuration error |

A failure-policy review checks that missing environment variables,
pre-inference 400s, deployment 404s, and 429s all stop without payload
splitting; only oversized or over-budget timeouts permit smaller independent
sessions; and MCP/CLI disagreement triggers executable-path and version
diagnostics.

The Azure guide's verification playbook provides an optional credentialed
smoke test on an adopter machine: confirm Codex `0.146.1`, verify the
resolved binary path, make a minimal CLI request, restart Claude Code, and
make a minimal MCP request. CI never requires Azure credentials or modifies
`~/.codex`.

Acceptance requires all repository tests passing, every routing-matrix
outcome being unambiguous from the policy text, no prompt-overlay changes,
no secrets in tracked files, and successful pinned-version CLI and MCP smoke
checks on the owner's configured Azure deployment.
