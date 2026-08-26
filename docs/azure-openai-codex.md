# Running the pipeline against Azure OpenAI

The pipeline's GPT stages call the Codex MCP server, which talks to
whatever provider `~/.codex/config.toml` selects. This runbook is the
Azure-specific setup: config, credentials, the version pin, and how to
verify the whole chain. Nothing in this repo's installer touches
`~/.codex` — this configuration is yours to own.

## Codex configuration

```toml
model = "<your-deployment-name>"
model_provider = "azure"

[model_providers.azure]
name = "Azure OpenAI"
base_url = "https://<your-resource>.openai.azure.com/openai/v1"
env_key = "AZURE_OPENAI_API_KEY"
wire_api = "responses"
```

Four rules, each learned the hard way:

- `model` is the Azure **deployment name**, not the model-family name. The
  pipeline sends it verbatim on every call (the "dispatch model"). If your
  deployment name differs from the family id, add one
  `gpt_model_alias: <deployment>=<family>` line in CLAUDE.md ("GPT model
  routing") so prompt overlays still match.
- `model_provider = "azure"` must be set at the **top level**, not just the
  provider block defined — otherwise cached ChatGPT auth can win.
- `env_key` is the environment variable **NAME**. Pasting the key value
  produces `Missing environment variable: <the key string>`.
- `wire_api = "responses"` is the only supported protocol; the deployment
  must expose `/v1/responses` (the `/openai/v1` base path, no
  `api-version` query needed).

## Version guidance — Azure needs 0.149.1 or newer

Codex CLI 0.147.0 wrapped a built-in tool with an empty `description`,
which Azure's Responses API schema rejects, so on 0.147.0–0.148.x **every
request fails before inference** with
`Invalid 'input[0].tools[0].description'` (openai/codex #37380, #37487,
#37675). **0.149.1 is verified working against Azure** (2026-08-26, both
legs of the playbook below: CLI request and MCP call from Claude Code).
Two cautions: the upstream issues were never formally closed and the fix
may be partly Azure-side, so re-run the playbook after ANY codex upgrade;
and 0.146.1 remains the known-good fallback if a future version regresses.

Watch for the duplicate-binary trap: `npm install -g` and the native
installer write to different places (e.g. `~/.local/bin/codex`), and the
MCP wrapper resolves whatever its own PATH finds. Check with `type -a
codex` and run `codex --version` from a shell AND confirm the version the
MCP wrapper's PATH resolves — a stale broken version there reproduces the
Azure bug only in MCP calls while the interactive CLI works. MCP servers
also keep the binary they launched with: fully restart Claude Code after
upgrading, or the old version keeps serving MCP calls.

## Getting the key into the environment

- Shell/CLI: `export AZURE_OPENAI_API_KEY="..."` in `~/.zshrc`. It must
  resolve in non-interactive shells: verify with
  `zsh -c 'source ~/.zshrc; echo ${AZURE_OPENAI_API_KEY:0:8}'`, and keep
  the export above any interactive-guard early return.
- GUI apps (Codex Desktop): `launchctl setenv AZURE_OPENAI_API_KEY "..."`,
  made persistent with a LaunchAgent. Fully quit and relaunch the app
  after setting.
- Hardening: keep the key in the macOS Keychain and export via
  `security find-generic-password -s AZURE_OPENAI_API_KEY -w` in
  `~/.zshrc`, so no plaintext key sits in dotfiles.

## Wiring the MCP server in Claude Code

Install the pinned CLI first (see Version pin above), then register the
server at user scope — two working shapes, pick one:

```bash
npm install -g @openai/codex@0.149.1

# Shape 1 — shell wrapper: the key stays in ~/.zshrc and is resolved when
# the server starts (requires the export above any interactive-guard early
# return; verify with: zsh -c 'source ~/.zshrc; echo ${AZURE_OPENAI_API_KEY:0:8}')
claude mcp add codex -s user -- zsh -c 'source ~/.zshrc >/dev/null 2>&1; exec codex mcp-server'

# Shape 2 — ${VAR} expansion: Claude Code resolves it from its own launch
# environment; the literal key value never enters ~/.claude.json (the
# single quotes matter — the shell must not expand it at add time)
claude mcp add codex -s user -e AZURE_OPENAI_API_KEY='${AZURE_OPENAI_API_KEY}' -- codex mcp-server
```

Then fully restart Claude Code and check `claude mcp get codex` — but read
the gotchas below before trusting what it says.

Two operational gotchas:

- **"Connected" proves the handshake only.** The server starts fine
  without the key; `Missing environment variable: AZURE_OPENAI_API_KEY`
  fires at request time.
- **MCP servers inherit the environment from session start.** After any
  env or config change, fully restart Claude Code (or `/mcp` → reconnect).

## Verification playbook

1. `echo ${AZURE_OPENAI_API_KEY:0:8}` in the launching shell (truncated
   on purpose — never print or paste the full key);
   `launchctl getenv AZURE_OPENAI_API_KEY` for GUI apps (also truncate
   before sharing its output).
2. `codex --version` → 0.149.1 (or the version you've verified), and
   `type -a codex` shows one binary (or all copies at that version).
3. In Codex: `/status` must show the Azure provider URL and your
   deployment name.
4. Negative test: `codex logout`, `unset OPENAI_API_KEY`, run a prompt — a
   response can only have come from Azure.
5. Ground truth: watch the Azure resource's metrics (request count,
   processed tokens) while sending one prompt from one surface at a time.
6. From a Claude Code session, invoke a trivial codex MCP call; success
   plus Azure metrics movement verifies the full chain.
7. Debugging: `RUST_LOG=debug codex "test" 2>~/codex-debug.log`, grep for
   your resource host.

## Failure signatures (what the pipeline's stop-and-report rules key on)

| Signature | Meaning | Fix |
|---|---|---|
| `Missing environment variable: AZURE_OPENAI_API_KEY` | Key not in the environment the failing surface inherited | Export/launchctl per above; restart Claude Code |
| `Invalid 'input[0].tools[0].description'` (400, pre-inference) | Codex 0.147.0–0.148.x regression | Upgrade to 0.149.1+; check for duplicate binaries and restart Claude Code |
| 404 on the model | Family id sent where a deployment name was needed, or wrong deployment | Fix the model value / alias registry |
| 400 protocol/endpoint errors | Base URL missing `/openai/v1`, or deployment lacks `/v1/responses` | Fix base_url / deployment |
| 429 | Quota / TPM / credits exhausted | Service limit — not a payload problem; check Azure quotas |

None of these are payload-size problems: the pipeline's split-and-retry
playbook applies only to silent timeouts on oversized sessions.
