# 0001 — Branch model and setup-routine form for the kit

**Status:** accepted
**Date:** 2026-06-22

## Context

This repo (`thesamer.devkit`) is the agent-dev-system kit, and it is being built *using its own
methodology*. Two foundational choices had to be made before building, because they shape every
later branch and the centerpiece deliverable.

1. The spec §7 branch model assumes a deploying app (`integration → live`). This kit does not
   deploy — it is distributed as files. So "live" is notional here.
2. The setup routine (spec §10.2) could be a shell script, a Claude Code skill, or both.

## Decision

**Branch model:** `main` is the integration truth. `feat/<name>` branches → PR → `main` (CI
validates) → human merges. **Releases are git tags** (e.g. `v0.1.0`), not a separate live branch.
This keeps ceremony minimal for a non-deploying, solo-maintained kit while preserving the
non-negotiable: no change reaches `main` without a reviewable diff.

**Setup routine:** **skill + script.** `bin/devkit-init.sh` is the deterministic engine
(detection, file copy, docs tree, branch convention) and works without an agent. A `devkit-init`
skill is the smart entry point that runs the script, then fills `CLAUDE.md` placeholders from
detected facts and prints the "how we work" summary. This gives one-step install for agents while
remaining usable as a plain script.

**Remote:** a private GitHub repo `thesamer-devkit`, created via `gh` once the human completes the
interactive `gh auth login`. Until then, work proceeds locally on branches.

## Why

- Tags-as-release matches how a library/kit actually ships and avoids a perpetually-empty `develop`.
- Script-plus-skill is the only option that is both portable (a script anyone can run) and
  intelligent (an agent that infers stack/store/deploy and fills the brief).
- Simpler-is-better was the explicit instruction for the branch model.

## Consequences

- The kit's CI gate (build/lint on `main`) stays dormant until the remote exists; it is authored
  now so it activates on first push.
- Because there is no live branch, the spec's "promote integration → live" gate maps to "cut a
  tag" in this repo's own docs. Target repos that *do* deploy still get the full `integration →
  live` model from the template.
- `bin/devkit-init.sh` must be idempotent and is the primary thing to verify, since there is no app
  to run.
