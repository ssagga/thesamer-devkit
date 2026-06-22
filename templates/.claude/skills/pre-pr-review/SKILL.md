---
name: pre-pr-review
description: Run the standing adversarial review gate on the current branch's diff before opening a PR. Use right before pushing / opening a pull request, or when asked to "review the diff", "do the pre-PR review", or "check this before I merge". Defaults to skepticism — tries to refute that the change is correct.
---

# Pre-PR adversarial review

The standing review gate. Run this on every branch before opening a PR — it is part of the
Definition of Done. Default stance: **assume the change is wrong until shown otherwise.**

## Steps

1. **Get the diff.** Determine the integration branch (see `CLAUDE.md`; usually `main`) and review
   the full change:
   ```bash
   git fetch -q origin 2>/dev/null; git diff <integration-branch>...HEAD
   ```
2. **Delegate to the Reviewer.** Hand the diff to the `reviewer` sub-agent (Opus, high effort), or
   run the built-in `/code-review high`. For changes touching **data, auth, money, or the live
   branch**, do not route review down — top tier only.
3. **Hunt adversarially** for: correctness bugs, regressions in callers of changed code, security
   holes, and **data-safety violations** (any drop/rename shipping with the change; missing backup
   before a live schema change). Also confirm scope didn't creep and docs are updated.
4. **Verify it runs.** Confirm the build passes and the change was actually run/observed — not just
   that the diff reads correctly.
5. **Report a verdict:** `SHIP` or `FIX FIRST`, with ranked findings (blocking / should-fix / nit),
   each as `path:line` + what's wrong + why it matters.

## Resolve before merging

Blocking findings must be fixed or **consciously** deferred (with a note in the PR / roadmap).
A clean verdict you didn't actually pressure-test is worse than none — state what you checked.
