# Uninstall Script Design

Ideation: gpt-5.6-sol via codex MCP · Facilitation: Claude

Status: Approved by user 2026-08-07

## Goals and boundaries

Add a conservative `uninstall.sh` that removes only symlinks verifiably owned
by this repo and restores a user-selected prior state from installer backups.

The design remains stateless: existing destination symlinks and timestamped
backups are the only evidence available. It adds no install ledger, rollback
database, command-line restore language, or settings migration.
`settings.json` remains untouched.

Decisions locked in during brainstorm:

- Multiple backups for a file → **stop and require a choice** (interactive
  numbered menu per ambiguous file; never guess).
- Destination not a repo-owned symlink → **stop before changing anything**;
  report all conflicts and require manual resolution.
- Managed path with no backup → **remove the symlink and leave the path
  absent** (restores the inferred original state).
- `DRY_RUN=1` → **full interaction**: preflight, prompt for ambiguous
  backups, print the exact plan, change nothing.
- Approach: **shared managed-file list** sourced by both scripts.

## Architecture and files

- Create `managed-files.sh`
  - Defines one indexed Bash array containing the five managed relative paths.
  - Contains data only — no filesystem operations.
  - Uses no Bash 4-only features, preserving compatibility with macOS's
    default Bash 3.2.

- Modify `install.sh`
  - Source `managed-files.sh` after determining `REPO`.
  - Replace its inline `FILES=(...)` declaration with the shared array.
  - Preserve all current installation behavior and output semantics.

- Create `uninstall.sh`
  - Uses `set -euo pipefail`.
  - Resolves `REPO` and `DEST` exactly as the installer does.
  - Sources the shared file list.
  - Implements preflight, backup selection, plan rendering, and execution.

- Update `README.md`
  - Document normal and dry-run usage.
  - Explain conflict behavior, interactive selection, and the lack of silent
    idempotency.

- Add `tests/uninstall-test.sh`
  - A self-contained temporary-directory regression suite with no runtime
    dependency or test framework.

No shared general-purpose shell library is needed. The manifest is the only
extracted component.

## Uninstall algorithm

### 1. Initialize

The script computes:

```text
REPO = canonical directory containing uninstall.sh
DEST = ${CLAUDE_HOME:-$HOME/.claude}
DRY_RUN = ${DRY_RUN:-0}
```

It sources `managed-files.sh`. `DRY_RUN` accepts only `0` or `1`; any other
value fails before filesystem changes.

Every destination and expected source is derived from the static relative
paths. User input is treated only as a numeric menu selection and is never
evaluated as shell code.

### 2. Preflight ownership and conflicts

Before discovering backups or prompting the user, inspect every managed path.

A path is owned by this installation only when:

1. The destination is a symlink, including a dangling symlink.
2. `readlink "$dst"` exactly equals `"$REPO/$rel"`.

Missing paths, regular files, directories, and symlinks to any other target
are conflicts. The script collects and reports all conflicts, then exits
nonzero without changing anything.

This deliberately means a partial installation cannot be automatically
unwound. If three paths are managed links and two are missing or user-owned,
all five remain untouched until the user resolves the mismatch.

The preflight also checks that required parent directories are accessible and
writable. These checks reduce predictable execution failures but cannot
eliminate races or filesystem errors.

### 3. Discover backups

For each conflict-free managed destination, discover candidates matching
exactly:

```text
<destination>.backup-<8 digits>-<6 digits>
```

For example:

```text
CLAUDE.md.backup-20260807-094500
```

Malformed `.backup-*` names are ignored. Because historical installs have no
ledger, every exact-pattern match is treated as a possible installer backup.

Candidates are displayed in ascending timestamp order (oldest first):

- Zero candidates: plan to remove the managed symlink and leave the path
  absent.
- One candidate: select it automatically.
- Multiple candidates: require an interactive numbered choice for that path.

Backup discovery must recognize dangling symlinks as candidates, not just
paths for which `-e` is true.

### 4. Collect ambiguous selections

All ambiguous paths are resolved before any mutation.

For each, show the relative managed path and every candidate's timestamped
name. A symlink candidate may also display its link target for clarity, but
the script does not judge whether that target is desirable.

Input must be an integer within the displayed range. Invalid input is
re-prompted. EOF, interruption, or input failure aborts with no changes.

If any choice is required and standard input is not a terminal, the script
exits nonzero and lists the ambiguous paths and candidates. It does not guess
and does not silently select the newest or oldest backup.

A noninteractive terminal is not required when every path has zero or one
candidate.

### 5. Build and validate the complete plan

Store one plan entry per managed path:

```text
relative path
current managed symlink
selected backup, or "none"
resulting state
```

Before execution, revalidate the entire plan:

- Every destination is still the expected managed symlink.
- Every selected backup still exists or is a symlink.
- No destination/backup pairing has changed since discovery.
- Required parent directories remain usable.

If anything changed while the user was choosing, abort before mutation.

Print the complete plan in both normal and dry-run modes. Example actions are:

```text
remove   commands/gpt-brainstorm.md
restore  commands/gpt-brainstorm.md.backup-20260807-094500
```

or:

```text
remove   agents/codex-adversary.md
leave    agents/codex-adversary.md absent (no backup)
```

### 6. Dry run

With `DRY_RUN=1`, perform the complete preflight and all required interactive
selections, print the exact validated plan, and exit successfully without
changing anything.

Dry run follows the same no-terminal rule because an exact plan cannot be
produced until ambiguous backups have been selected.

### 7. Execute

For each plan entry:

1. Recheck that the destination is still the exact managed symlink.
2. Remove that symlink only. This never follows or modifies its repo target.
3. If a backup was selected:
   - Confirm the destination is absent.
   - Move the selected backup into the original destination.
4. If no backup was selected, leave the destination absent.

Moving rather than copying preserves the restored object's type, permissions,
metadata, and symlink identity. The selected `.backup-<stamp>` name is
consumed by the move, but its contents are not deleted. Every unselected
backup remains untouched.

The script never overwrites an existing destination. It does not remove empty
`agents`, `commands`, or `skills` directories because they may be user-owned.

On success, print totals for removed links, restored backups, and paths left
absent.

## Edge cases

| State | Behavior |
|---|---|
| No backup for a managed path | Remove its managed symlink and leave the path absent. |
| Exactly one backup | Restore it automatically. |
| Multiple backups | Require a validated interactive selection for that path. |
| No terminal when a choice is required | Exit nonzero before mutation and list the candidates. |
| Current path is missing, regular, a directory, or a wrong-target symlink | Treat it as a conflict; report all conflicts and make no changes. |
| Partial installation | The non-managed paths are conflicts, so no managed links are removed. |
| Already successfully uninstalled | A second run finds non-managed paths and exits without changes. It is safe to rerun but intentionally not a silent successful no-op because there is no ledger proving why those paths differ. |
| Custom `CLAUDE_HOME` | Use it exactly as `install.sh` does; an empty value falls back to `$HOME/.claude`. |
| Selected backup is a symlink | Move the symlink itself without dereferencing it, including when it is dangling. |
| Symlinked repo file was edited after installation | Removing the destination link does not remove the edited repo file; the edits remain in the clone. |
| Repo was moved after installation | Links targeting the old location do not exactly match the current repo and are reported as conflicts. |
| Malformed backup suffix | Ignore it; only the exact timestamp pattern is considered. |
| `settings.json` or unrelated backups | Never inspect or modify them. |

## Error handling and recovery

Expected problems — conflicts, ambiguity without a terminal, invalid input,
missing selected backups, and permission failures found during preflight —
must fail before mutation with actionable messages.

The two-phase structure prevents known conflicts from causing a partial
uninstall, but it cannot make multiple filesystem operations transactional.
An unexpected I/O failure may occur after earlier plan entries have
completed.

The script will not implement automatic cross-file rollback. Rollback would
add more renames and failure states while potentially disturbing
already-restored user configuration. Instead:

- Stop immediately on an execution failure.
- Identify the path and failed operation.
- Report which earlier entries completed.
- Leave every unselected backup untouched.
- If link removal succeeded but restoration failed, the selected backup
  remains at its backup path whenever the move itself did not complete.
- Tell the user to inspect the printed plan and resolve the remaining paths
  manually.

The only object explicitly deleted is a symlink whose raw target exactly
matches this repo. No user configuration file or backup content is deleted
or overwritten.

## Testing

`tests/uninstall-test.sh` will create a fresh temporary repo fixture and
`CLAUDE_HOME` for every case, with cleanup restricted to that exact temporary
directory. It must never exercise the caller's real `~/.claude`.

The regression matrix covers:

1. **Installer refactor**
   - All five paths still link correctly.
   - Existing files and symlinks receive timestamped backups.
   - Existing installer dry-run behavior remains unchanged.

2. **Fresh installation**
   - Install into an empty destination.
   - Uninstall removes all five links.
   - Paths remain absent and parent directories remain.

3. **Single backups**
   - Prepopulate all managed paths, install, then uninstall.
   - Original file contents and modes are restored.
   - Selected backup names no longer exist after being moved.

4. **Multiple backups**
   - Create two or more valid candidates.
   - Run under a pseudo-terminal and select a candidate other than the
     first listed (there is no default).
   - Verify the chosen object is restored and other candidates remain
     untouched.

5. **Mixed backup counts**
   - Exercise zero, one, and multiple candidates in one plan.
   - Confirm no mutation occurs until the final choice has been validated.

6. **Conflict preflight**
   - Test missing paths, regular files, directories, and wrong-target
     symlinks.
   - Snapshot the fixture before execution and prove it is unchanged
     afterward.

7. **Partial installation**
   - Combine correct managed links with missing or user-owned paths.
   - Confirm the script reports every conflict and changes none of them.

8. **Dry run**
   - Include an ambiguous backup and make a selection under a
     pseudo-terminal.
   - Verify the printed plan and byte-for-byte unchanged filesystem state.

9. **No terminal**
   - Run with redirected standard input while multiple candidates exist.
   - Confirm nonzero exit and no filesystem changes.

10. **Symlink restoration**
    - Restore both valid and dangling symlink backups.
    - Verify their raw targets are preserved.

11. **Already uninstalled**
    - Run a second time after success.
    - Confirm nonzero conflict reporting and no further changes.

12. **Destination override and isolation**
    - Test a custom `CLAUDE_HOME`.
    - Confirm `settings.json`, unrelated files, malformed backups, and the
      source repo remain untouched.

Finally, run `bash -n` on all shell files and ShellCheck when available.
ShellCheck remains a development check rather than a user-facing dependency.
