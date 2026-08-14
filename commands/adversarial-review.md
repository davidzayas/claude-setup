---
description: Cross-model adversarial code review via Codex (GPT). Args: nothing (reviews uncommitted changes), file paths, or a git range like HEAD~3..HEAD. Optional --model <exact-id> anywhere in the args.
disable-model-invocation: true
---

Delegate an adversarial review to the **codex-adversary** subagent.

Review target: $ARGUMENTS
(Strip an optional `--model <exact-id>` pair out of the arguments first; the
rest is the target. If no target remains, review all uncommitted changes:
`git diff HEAD` plus untracked files that are part of the current task.
Reject an empty or repeated --model value: show the accepted syntax and stop
rather than guessing.)

Instructions for this run:

1. Resolve the dispatch model: the `--model` value if given, else
   `gpt_review_model:` from CLAUDE.md, else the Codex CLI default — under
   an Azure provider these are deployment names. Derive the overlay model
   via the `gpt_model_alias:` registry in CLAUDE.md (exact, single-hop; no
   match = the dispatch model). Check whether `agents/codex-adversary.md`
   has a `gpt-overlay:review:<overlay model>` block. If not, warn the user
   ("no tuned variant for <overlay model>; using the generic baseline") and
   record the missing variant — keyed by the overlay model — in the
   claude-setup repo's TODO.md per the "GPT model routing" rules in
   CLAUDE.md; you own this side effect; the subagent is read-only and must
   never write it. Pass the dispatch model to the subagent for the wire
   call.
2. Write a one-paragraph statement of intent for the code under review —
   what it is supposed to do and any constraints from the current task. Do
   not skip this; the reviewer needs intent to catch spec violations.
3. Delegate to codex-adversary, passing the intent, the resolved model, and
   its variant status (tuned overlay or generic baseline). Wait for its
   structured report.
4. Adjudicate the findings yourself:
   - Fix everything you agree with at CRITICAL/HIGH.
   - For findings you disagree with, state the rebuttal explicitly in your
     response — do not silently drop them.
   - MEDIUM/LOW: fix if cheap, otherwise list as accepted debt.
5. If you made fixes, offer to run /adversarial-review once more on the
   fixed diff (do not auto-loop more than once).

Present the final outcome as: verdict, what was fixed, what was rebutted and
why, and what remains as accepted debt.
