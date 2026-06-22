# Feature: devkit update-awareness (v0.2 group D, item 8)

**Status:** built; pending merge
**Branch:** `feat/devkit-update` (stacked on `feat/workflow-gates`)
**Owner:** orchestrator (Opus)
**Spec written:** 2026-06-22
**Backlog:** [v0.2 hardening](../v0.2-real-world-hardening.md) item 8 (group D).

## Goal

Stop installed projects from silently drifting from kit improvements — give them provenance, a way to
see what's new, and a **safe** way to pull kit-owned updates without ever clobbering project work.

## Scope

- **Provenance** — `devkit-init` writes `.claude/devkit.json` (source repo, version, ref, install
  date) at install. Tracked + protected by the gitignore guard. Read from the kit's new `VERSION`
  file.
- **`CHANGELOG.md`** + **`VERSION`** at kit root — something to diff against; versions are git tags.
- **`devkit-init.sh --check-updates <dir>`** — read-only: compares the project's recorded version to
  this kit's `VERSION` and lists kit-owned files that differ or are new. No scaffolding.
- **`devkit-init.sh --update <dir>`** — force-refreshes only the `KIT_OWNED_PURE` files (agents +
  the four skills) and bumps provenance. Honors `--dry-run`. Never touches `CLAUDE.md`, `docs/`, or
  generated files.
- **`/devkit-update` skill** (template-installed) — drives the human-in-the-loop flow: read
  provenance → fetch latest kit → summarize CHANGELOG since → `--check-updates` → preview/apply
  `--update` with consent → diff-and-confirm for generated files → verify.
- The kit-owned vs project-owned vs generated split is the safety basis — ADR
  [0003](../decisions/0003-devkit-update-merge-strategy.md).

## Non-goals

- The script does no network I/O; *fetching* a newer kit is the human-authorized step in the skill
  (consistent with ADRs 0001/0002). `--check-updates`/`--update` compare the local kit to the
  project.
- The updater never auto-merges generated/hybrid files (`ci.yml`, PR template, `_template`s) — those
  are diff-and-confirm by hand.

## Data / schema impact

None (the kit stores no data; `.claude/devkit.json` is provenance metadata in the target).

## Test / verify plan

- [x] `shellcheck` clean; `--help` lists the new flags.
- [x] Install writes valid `.claude/devkit.json` (JSON-parsed: version 0.2.0); install count 15 → 17
      (devkit-update skill + provenance).
- [x] `--check-updates` on a fresh install → "current", all files match; on a simulated older
      recorded version → "update available 0.1.0 → 0.2.0"; on a dir with no provenance → graceful
      "run devkit-init once" message.
- [x] **Safety:** drifted a kit-owned `reviewer.md` + added a sentinel to `CLAUDE.md`. `--update
      --dry-run` wrote nothing; `--update` refreshed `reviewer.md` only — **`CLAUDE.md` md5 unchanged,
      sentinel survived**; `--check-updates` clean afterward.
- [x] Idempotent: `--update` skips already-identical files.

## Notes / open questions

- `KIT_OWNED_PURE` is the explicit allow-list that makes no-prompt refresh safe; adding a kit-owned
  file is three edits in `devkit-init.sh` (copy list, the array, gitignore guard).
- Provenance isn't overwritten on a plain re-install (skip-on-exist), so a hand-edited file isn't
  stomped; `--update` and `--force` are the deliberate paths that rewrite it.
- **Adversarial review** confirmed the allow-list safety, mode dispatch, dry-run, and no-network
  posture, and flagged one real hazard: git-derived values were embedded unescaped in the provenance
  JSON, so an unusual remote URL (a quote/backslash) could produce invalid JSON that silently
  disables updates. Fixed with a dependency-free `json_escape` (no `jq`); verified a pathological URL
  now round-trips as valid JSON.
