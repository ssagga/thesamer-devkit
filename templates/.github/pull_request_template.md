<!--
  This PR is the reversible, readable record and the human approval moment.
  One unit of work = one branch = one PR. Keep the diff atomic.
-->

## What & why

<One or two sentences: what this changes and why. Link the feature spec / roadmap row / issue.>

- Spec: `docs/features/<name>.md` <!-- delete if trivial change -->
- Decision log: `docs/decisions/<NNNN>-<slug>.md` <!-- delete if no real trade-off -->

## How it was verified

<How the change was actually run & OBSERVED to work — not "the diff looks right." Preview URL,
screenshot, commands run, scenarios checked.>

---

## Definition of Done

- [ ] Build passes (CI green).
- [ ] App was actually **run / observed** to confirm the change works.
- [ ] **Adversarial review pass** completed (Reviewer agent or `/code-review`); findings resolved
      or consciously deferred.
- [ ] `CLAUDE.md` accurate (updated if architecture/conventions changed).
- [ ] `docs/roadmap.md` status updated.
- [ ] Decision-log entry appended if a non-obvious choice was made.
- [ ] Feature spec reflects what was actually built.
- [ ] **Data safety:** no drop/rename shipped with additive change; live store backed up before any
      schema change. (Delete if no persistent state touched.)

> Live promotion is a **separate, deliberate action** after merge — not part of this PR.
