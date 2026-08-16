# Install Prerequisite Preflight Design

Ideation: gpt-5.6-sol via codex MCP · Facilitation: Claude

Status: Approved by user 2026-08-16

Decisions locked in during brainstorm:

- Missing prerequisites: **abort before changes**; `SKIP_CHECKS=1` overrides
  (legitimate config-first installs); `DRY_RUN=1` runs the checks
  advisory-only.
- Hard blockers: missing `claude`, missing `codex`, failed
  `claude mcp get codex`. Codex version/provider suitability and the
  superpowers plugin are **warnings only**.
- Approach: **inline aggregated preflight** in install.sh (over a standalone
  checker script and first-failure guards), mirroring uninstall.sh's
  collect-all-then-report-once conflict-preflight pattern.
- Verified assumption: `claude mcp get codex` exits 0 when registered, 1
  when missing (confirmed live on the owner's machine).

## Architecture

Use the selected inline, aggregated preflight as a new first phase of
`install.sh`, before any backup, directory creation, or symlink mutation.

The flow is:

1. Initialize paths and flags without changing the filesystem.
2. Collect prerequisite results for `claude`, `codex`, and
   `claude mcp get codex`.
3. Report all failures together, matching `uninstall.sh`'s
   conflict-preflight style.
4. Apply mode policy:
   - Normal: abort on any hard failure.
   - `SKIP_CHECKS=1`: skip checks with an explicit notice.
   - `DRY_RUN=1`: run and report checks, but continue to the mutation-free
     preview.
5. Run the existing linking workflow unchanged.

Codex version/provider suitability and Superpowers status remain warnings,
not gates. Commands resolve through `PATH`, providing a test seam for
shims.

README will place prerequisites before installation and distinguish three
verification levels: binary availability, MCP registration/handshake, and a
live MCP request proving credentials and provider access. The installer
will not install dependencies, modify MCP registration, or claim that
handshake success verifies credentials.

Success means missing hard prerequisites cannot cause a normal partial
install, while intentional overrides and dry-run previews remain available.
The verified assumption is that `claude mcp get codex` exits `0` when
registered and `1` when missing.

## Components

- `install.sh`: gains an inline `preflight` function and a small failure
  accumulator. It checks PATH-resolved `claude` and `codex`, then runs
  `claude mcp get codex` only when `claude` exists. It prints
  detected/warning information, reports all hard failures once, and returns
  a single pass/fail result to the installer gate. `SKIP_CHECKS` and
  `DRY_RUN` affect only that gate; existing link/backup behavior stays
  unchanged.

- `README.md`: gains a prominent prerequisites section before Install with
  compact OpenAI and Azure Codex installation/registration instructions,
  the Azure `0.146.1` pin, Superpowers setup guidance, and layered
  verification commands. The later Requirements content is consolidated to
  avoid contradictory duplicate instructions.

- `docs/azure-openai-codex.md`: remains the detailed Azure runbook and
  source for environment delivery, registration variants, provider
  validation, and troubleshooting. Only minor cross-linking or wording
  synchronization should be needed.

- `tests/uninstall-test.sh`: existing installer/uninstaller fixtures run
  with `SKIP_CHECKS=1`, preserving their focus and all 53 current checks.
  New preflight-specific cases use temporary PATH shims for `claude` and
  `codex`, including a `claude` shim that controls `mcp get codex` exit
  status.

- `managed-files.sh`, `uninstall.sh`, and managed configuration files
  remain unchanged.

## Data Flow

`install.sh` consumes four read-only inputs: `PATH`, `CLAUDE_HOME`,
`SKIP_CHECKS`, and `DRY_RUN`.

1. If `SKIP_CHECKS=1`, the installer prints that preflight was bypassed and
   proceeds (when `DRY_RUN=1` is also set, it proceeds only to the existing
   preview). `DRY_RUN=1` alone does not bypass the checks — they run and
   report advisorily.
2. Otherwise it independently checks for `claude` and `codex`.
3. When `claude` exists, it runs `claude mcp get codex`. When absent,
   registration is reported as "not checked" rather than duplicated as
   another failure.
4. Results are accumulated and printed together. The detected Codex version
   and Azure pin reminder are informational; Superpowers is identified as
   manually verified.
5. Hard failures branch by mode:
   - Normal install: exit nonzero before "Linking into…" or any filesystem
     mutation.
   - Dry run: label failures advisory, then show the complete mutation-free
     link plan.
6. A passing or explicitly bypassed preflight enters the unchanged
   backup-and-link loop.

The documented colleague workflow is: choose one provider → install the
appropriate Codex version → register the Codex MCP server → verify binaries
and registration → preview/install the managed files → merge/verify
Superpowers settings → restart Claude Code → make one trivial live MCP
request. Only that final request, optionally correlated with provider
metrics, verifies credentials and the complete chain.

## Error Handling

`DRY_RUN` and `SKIP_CHECKS` accept only `0` or `1`; invalid values exit `1`
before probes or filesystem changes.

Probe commands run inside guarded conditionals so `set -e` cannot terminate
collection early. Hard failures are accumulated and reported together using
the established pattern:

> Nothing changed — required dependencies are unavailable:
> `claude` CLI not found in PATH
> `codex` CLI not found in PATH
> Codex MCP registration could not be verified

If `claude` is missing, the MCP check is reported as skipped, not as a
second failure. Any nonzero result from `claude mcp get codex` is described
as "could not verify," because it may represent missing registration or
another CLI error. Remediation points to the README and mentions
`SKIP_CHECKS=1`.

A failed `codex --version` probe, an unsuitable Azure version, or
unverified Superpowers status produces a warning only. Successful MCP
registration explicitly says that live credentials were not tested.

Normal prerequisite failure exits `1`; dry-run prerequisite failure is
labeled advisory and still exits `0` after the link preview.
Flag-validation and unrelated script errors remain fatal even during dry
run. Existing mid-install `mv`/`ln` failure behavior is unchanged and is
not made transactional by this work.

## Testing

Extend `tests/uninstall-test.sh` without adding a test framework.

Existing fixtures will invoke `install.sh` with `SKIP_CHECKS=1`, preserving
the current 53 install/uninstall checks independently of the developer
machine. New preflight fixtures will use a sanitized PATH plus temporary
shims:

- `claude` handles exactly `mcp get codex` and returns a configured status.
- `codex` handles `--version`.
- Omitted shims simulate missing binaries without consulting real
  installations.

Required cases:

- All prerequisites pass and installation proceeds.
- Both binaries missing: both failures reported, exit `1`, filesystem
  snapshot unchanged.
- Each binary missing independently.
- MCP lookup returns `1`: clear failure, no mutation.
- Dry run with failures: advisory output, link preview, exit `0`, no
  mutation.
- `SKIP_CHECKS=1`: probes are not invoked and installation proceeds.
- Invalid flag values: exit `1`, no mutation.
- Version-probe and Superpowers warnings do not block installation.
- MCP success output states that credentials remain untested.

Assertions cover exit status, diagnostic text, probe invocation, symlink
results, and before/after snapshots. Verification runs:

```bash
bash -n install.sh tests/uninstall-test.sh
bash tests/uninstall-test.sh </dev/null
bash tests/prompt-contract-test.sh
```

Completion requires all existing 93 checks plus the new preflight checks to
pass, with no fixture reading or modifying the real Claude home or relying
on locally installed Claude/Codex binaries.
