# Changelog — thesamer.devkit

All notable changes to the kit. Installed projects can diff their recorded version (in
`.claude/devkit.json`) against this file to see what's new. Format loosely follows
[Keep a Changelog](https://keepachangelog.com); versions are git tags.

## 0.2.0 — 2026-06-22 — Real-world hardening

First hardening pass from a real deployment (`thesamer.com-v5`). 13 backlog items across installer
correctness, brief fidelity, workflow gates, update-awareness, and ergonomics.

### Installer correctness (group A)
- **Recursive + dependency-aware store detection.** Globs common store subdirs and infers the store
  from `package.json` deps, with a certainty signal. **Never advises deleting the Data-safety
  section on a false negative.**
- **Gitignore guard.** The kit's own files (esp. the review gate) can no longer be hidden by a
  blanket `.gitignore` rule — narrow negations are added so they survive a fresh clone.
- **Runnable CI.** The CI template now emits a real toolchain block per stack (Node via `corepack`,
  no double pnpm-version pin), not an all-commented skeleton.
- Fixed two `.yaml`/`.yml` glob false-negatives in docker-compose + workflow detection.

### Brief fidelity (group B)
- **Live/deploy-branch inference** from GitHub workflows (`refs/heads` + `branches:` lists), threaded
  through the brief.
- **Build-time-vs-runtime data hazard** added to the Data-safety template.

### Workflow gates (group C) + preferences keystone (item 0)
- **`## Working preferences`** block: plan gate, preview gate, merge/promote-stay-human.
- **`plan-presenter` agent** — consolidates a plan and stops for go/no-go before code.
- **`preview` skill** — optional local look between BUILD and VERIFY.
- New explicit **`## Feature lifecycle`** section in the template.

### Update-awareness (group D)
- **Provenance** (`.claude/devkit.json`) recorded at install; `devkit-init.sh --check-updates` and a
  `/devkit-update` skill; this CHANGELOG + `VERSION`. Kit-owned vs project-owned merge strategy
  (ADR 0003).

### Ergonomics (group E)
- **Enforcement honesty** (report, not auto-apply; inactive `pre-push` backstop).
- **`/status`** read-only digest skill.
- Status-flip rides the shipping PR; run-&-observe + PATH-fallback docs.

## 0.1.0 — 2026-06-22 — Initial kit

- `devkit-init.sh` scaffolder + `devkit-init` skill; `CLAUDE.template.md`; `docs/` tree templates;
  agent roles (`explorer`, `planner`, `implementer`, `reviewer`); review + CI gates; one-command
  `curl | bash` bootstrap; turnkey git init; open-source launch (MIT).
