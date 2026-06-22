---
name: status
description: Read-only re-orientation digest for this repo — current branch + uncommitted work, roadmap now/next, open PRs and their CI state, and any data-safety flags. Use to get your bearings at the start of a session or when asked "where are we?", "what's the status?", "what's in flight?", "what's next?". Reads only; never edits, commits, or pushes.
---

# Status digest

A fast projection of the source of truth so a fresh session can re-orient without re-exploring.
**Read-only** — this skill never writes, commits, pushes, or changes state. It only reports what is
already recorded in the repo and on the remote.

## Steps

1. **Local state.** Current branch, how it sits vs the integration branch, and uncommitted work:
   ```bash
   git status -sb
   git log --oneline -5
   ```
2. **Roadmap now/next.** Read `docs/roadmap.md` and report the "Now / in-progress" and the top of
   "Next" — plus anything `in-progress` that has no open branch/PR (a resumability gap).
3. **Open PRs + CI.** If `gh` is available and a remote exists:
   ```bash
   gh pr list --state open 2>/dev/null
   gh pr checks 2>/dev/null   # for the current branch's PR, if any
   ```
   Report each open PR's title, base, and check state (pass / pending / fail). If `gh` is absent,
   say so and skip — do not guess.
4. **Data-safety flags.** If `CLAUDE.md` has a Data-safety section, note the store and surface any
   open `TODO`/`FIXME` near it, plus any unmigrated schema change in the working tree. If there is
   no store, say "stateless — no data-safety gate."
5. **Report.** One compact digest:
   - **Branch:** `<name>` (`<N>` ahead / `<M>` behind `<integration>`), `<clean|dirty>`.
   - **Now:** the in-progress item (or "nothing checked out").
   - **Next:** the top 1–3 backlog items.
   - **Open PRs:** each with CI state, or "none".
   - **Data safety:** store + any flags, or "stateless".
   - **Resumability:** call out anything that lives only in this chat and isn't written down yet.

## Rules

- **Never** modify anything — no `git add`, no edits, no `gh pr create/merge`. If the user wants an
  action, report and let them trigger it.
- Prefer conclusions over dumps: summarize, don't paste raw multi-screen output.
- If something can't be read (no `gh`, no remote, no roadmap), state the gap plainly rather than
  inventing a value.
