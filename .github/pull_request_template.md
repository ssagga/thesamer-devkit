<!-- One unit of work = one branch = one PR. This PR is the reversible, readable record. -->

## What & why

<One or two sentences. Link the roadmap row / feature spec / decision log.>

- Roadmap: `docs/roadmap.md`
- Spec: `docs/features/<name>.md` <!-- delete if trivial -->
- Decision: `docs/decisions/<NNNN>-<slug>.md` <!-- delete if no trade-off -->

## How it was verified

<For this kit, "verified" = ran `bin/devkit-init.sh` against a throwaway dir and confirmed the
scaffold landed correctly. Paste the gist.>

---

## Definition of Done

- [ ] Lint passes (`shellcheck bin/*.sh`, CI green).
- [ ] Scaffolder actually **run / observed** against a sandbox repo.
- [ ] **Adversarial review** done (`/pre-pr-review`, Reviewer agent, or `/code-review`).
- [ ] `CLAUDE.md` accurate.
- [ ] `docs/roadmap.md` status updated.
- [ ] Decision-log entry appended if a non-obvious choice was made.
- [ ] Docs reflect what was actually built.
