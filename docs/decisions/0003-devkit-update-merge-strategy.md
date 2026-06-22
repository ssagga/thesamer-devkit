# 0003 — Devkit update/merge strategy: kit-owned vs project-owned

**Status:** accepted
**Date:** 2026-06-22

## Context

v0.2 item 8 wants installed projects to pull in kit improvements without drifting, and without an
update ever destroying the project's own work. An update that's too aggressive clobbers the filled
`CLAUDE.md`; one that's too timid leaves stale agent defs forever. The hard part is deciding **which
files an update may overwrite**.

## Decision

Classify every installed file into one of three buckets; the updater treats each differently.

1. **Kit-owned (pure methodology)** — agent defs (`.claude/agents/*`) and skills
   (`.claude/skills/{pre-pr-review,status,preview,devkit-update}`). These carry **no per-project
   fill**: every install gets byte-identical copies. The updater (`devkit-init.sh --update`)
   **force-refreshes** exactly this set (the `KIT_OWNED_PURE` array) and bumps the recorded version.
2. **Project-owned** — `CLAUDE.md` (filled brief), `docs/roadmap.md`, real `docs/features/*` and
   `docs/decisions/*`. The updater **never touches** these. If methodology prose changed in a way
   that affects the brief, the human merges it deliberately (the `/devkit-update` skill surfaces the
   diff).
3. **Generated / hybrid** — `.github/workflows/ci.yml` (stack-filled), the PR template, and the
   `docs/*/_template.md` files. These are kit-authored but commonly customized, so the updater
   **leaves them alone**; the skill diffs-and-confirms if the CHANGELOG says they changed.

Provenance lives in `.claude/devkit.json` (source, version, ref, install date), written at install.
`--check-updates` compares it to the running kit's `VERSION` and reports which kit-owned files
differ; `--update` applies; a `CHANGELOG.md` gives the human something to read.

## Why

- The kit-owned set is **safe to overwrite by construction** because it never contains project data —
  that's the whole basis for a no-prompt refresh. Membership is an explicit allow-list, not a
  guess: a file is force-updated only if it's in `KIT_OWNED_PURE`.
- **Default-to-project-owned for anything ambiguous.** Refusing to touch `ci.yml`/templates is the
  conservative choice; a wrongly-overwritten generated file is a worse failure than a stale one,
  which the human can update by hand from the diff.
- Keeping the updater **deterministic and offline** (it diffs the local kit against the project; the
  *fetching* of a newer kit is the human-authorized step in the skill) matches the kit's standing
  "no surprising network/mutation" posture (ADRs 0001, 0002).

## Consequences

- Adding a new kit-owned file means adding it to `KIT_OWNED_PURE` (and the copy list + gitignore
  guard) — three small edits, all in `devkit-init.sh`.
- If a file ever needs to become both kit-owned *and* per-project filled, it must move to the
  generated/hybrid bucket (diff-and-confirm), never the auto-refresh bucket.
- Idempotency holds: `--update` skips files already identical and only rewrites real diffs.
