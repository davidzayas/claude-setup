---
description: Cross-model adversarial code review via Codex (GPT). Args: nothing (reviews uncommitted changes), file paths, or a git range like HEAD~3..HEAD.
disable-model-invocation: true
---

Delegate an adversarial review to the **codex-adversary** subagent.

Review target: $ARGUMENTS
(If no arguments were given, the target is all uncommitted changes: `git diff HEAD` plus untracked files that are part of the current task.)

Instructions for this run:

1. Before delegating, write a one-paragraph statement of intent for the code
   under review — what it is supposed to do and any constraints from the
   current task — and pass it to the subagent. Do not skip this; the reviewer
   needs intent to catch spec violations.
2. Delegate to codex-adversary and wait for its structured report.
3. Adjudicate the findings yourself:
   - Fix everything you agree with at CRITICAL/HIGH.
   - For findings you disagree with, state the rebuttal explicitly in your
     response — do not silently drop them.
   - MEDIUM/LOW: fix if cheap, otherwise list as accepted debt.
4. If you made fixes, offer to run /adversarial-review once more on the fixed
   diff (do not auto-loop more than once).

Present the final outcome as: verdict, what was fixed, what was rebutted and
why, and what remains as accepted debt.
