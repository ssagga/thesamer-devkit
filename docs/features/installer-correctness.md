# Feature: installer correctness & safety (v0.2 group A)

**Status:** built; pending merge
**Branch:** `feat/installer-correctness`
**Owner:** orchestrator (Opus)
**Spec written:** 2026-06-22
**Backlog:** [v0.2 hardening](../v0.2-real-world-hardening.md) items 1, 2, 3 (group A).

## Goal

Close the three installer **trust bugs** found on the first real-world deployment
(`thesamer.com-v5`). Each one made `devkit-init` give actively wrong or dangerous advice. Fixing them
is higher-leverage than any new feature: an installer the operator can't trust is worse than none.

## Scope (one PR, three items)

1. **Recursive + dependency-aware store detection** — `detect_stack` in `bin/devkit-init.sh`.
   Root-only globbing (`ls "${t}"/*.sqlite "${t}"/*.db`) missed `data/thesamer.db`, reported
   `store: none`, and the installer then advised *deleting the Data-safety section* for a DB-backed
   CMS.
   - Search common store subdirs (`data/`, `db/`, `.data/`, `prisma/`, `var/`, `storage/`) plus the
     root for `*.sqlite` / `*.sqlite3` / `*.db`.
   - Infer the store from `package.json` deps when no file is on disk yet: `better-sqlite3`/`sqlite3`/
     `@libsql/client` → SQLite, `drizzle-orm` → Drizzle, `@prisma/client` → Prisma, `pg`/`postgres` →
     PostgreSQL, `mysql`/`mysql2` → MySQL, `mongodb`/`mongoose` → MongoDB, `redis`/`ioredis` → Redis.
   - Track **certainty.** A store found via on-disk file or ORM config is *certain*; a store inferred
     from a dependency only is *inferred* and labelled `… (inferred from <dep> — confirm)` with a
     confirm TODO (operator decision, 2026-06-22).
   - **Never advise deleting the Data-safety section on a false negative.** The old unconditional
     "Delete the Data-safety section" TODO becomes conditional: keep it unless the project is truly
     stateless.

2. **Never let the installer's own files be gitignored** — post-install guard in `bin/devkit-init.sh`.
   After scaffolding (and after git is initialised), `git check-ignore` the critical kit files
   (esp. `.claude/skills/pre-pr-review/`). If any are ignored — common cause: a blanket
   `/.claude/skills/` — append narrow negations to `.gitignore` under a marker so the review gate
   survives a fresh clone, and warn loudly. Idempotent (guarded by the marker).

3. **Generate a runnable CI workflow** — `templates/.github/workflows/ci.yml` + `build_ci_yml`.
   The template shipped with every toolchain step commented out — not runnable. Emit a real
   toolchain-setup block for the detected stack (Node via `corepack enable` + `setup-node`; Python/
   Go/Ruby via their setup actions). Using `corepack enable` activates the pnpm/yarn version from
   `package.json`'s `packageManager` field, so we **never** also version-pin in `pnpm/action-setup`
   — that combo fails with `ERR_PNPM_BAD_PM_VERSION`. Drop the Test step when no test command is
   detected (rather than emitting an empty `run:`).

## Non-goals

- No change to the feature lifecycle, agent roles, or branch model.
- Store detection stays best-effort and **additive** — it never modifies the target's store, and on
  uncertainty it errs toward *keeping* the safety section, never deleting.
- Not solving live-vs-deploy branch inference (that's group B / item 4).

## Approach notes

- New detection state: `STACK_STORE` (clean name or `none`), `STACK_STORE_CERTAIN` (false ⇒ inferred
  from deps), `STACK_STORE_EVIDENCE` (human-readable why, e.g. `data/app.db` or `better-sqlite3
  dependency`). The CLAUDE.md persistent-state line shows the inferred annotation; the Data-safety
  body uses the clean store name.
- Gitignore guard walks each ignored file's path prefixes, re-including only the prefixes git
  actually ignores (git can't un-ignore a file whose parent dir is excluded), so the negations stay
  as narrow as correctness allows.
- CI generation replaces a single `# <<DEVKIT_TOOLCHAIN>>` sentinel in the template with the
  stack-specific setup steps, keeping the template human-readable.

## Data / schema impact

None — the kit stores no data; the target's store is only detected.

## Test / verify plan

Run the scaffolder against throwaway fixtures and observe (DoD here is "actually run & observed").

- [x] `shellcheck bin/devkit-init.sh` clean; `--help` exits 0.
- [x] **Nested-SQLite fixture** (`data/app.db` + `better-sqlite3`): store detected as
      `SQLite (data/app.db)`, Data-safety section kept, no "delete" advice.
- [x] **Dep-only fixture** (`better-sqlite3` in deps, no `.db` file): labelled
      `SQLite (inferred from better-sqlite3 dependency — confirm)`, confirm TODO emitted, section kept.
      (Also confirmed `pg` → PostgreSQL via the dry-run fixture.)
- [x] **Blanket-gitignore fixture** (`.gitignore` with `/.claude/skills/`, existing git repo): guard
      detected `pre-pr-review` ignored, appended narrow negations, `git add -A` then stages the file;
      idempotent on re-run (marker guard, no duplicate block).
- [x] **packageManager-pinned fixture** (`"packageManager": "pnpm@9.7.0"`): generated `ci.yml` uses
      `corepack enable`, no `pnpm/action-setup` version pin, Test step omitted (no test script),
      valid YAML.
- [x] **Regression**: empty repo → conditional (not unconditional) delete advice; `--dry-run` wrote
      0 files; fresh git run created 12 files + guard clean (no spurious `.gitignore`); idempotent
      re-run skipped all 12. YAML validated for test/no-test/inferred cases.

## Notes / open questions

- Redis is included as a store (it persists), but many projects use it as an ephemeral cache —
  hence "inferred — confirm" rather than a hard assertion.
- **Adversarial review (Reviewer, Explore-tier) surfaced two pre-existing `.yaml`-vs-`.yml` glob
  false-negatives** — `ls a.yml a.yaml` returns non-zero if *either* operand is an unmatched
  literal, so a project using only the `.yaml` spelling was missed. Fixed both call sites
  (docker-compose store detection + GitHub-workflow deploy detection) by collecting the files that
  actually exist before grepping. Verified with a `.yaml`-only fixture. The deploy-detection one
  touches item 4's territory but is a one-line correctness fix, not the live/deploy-branch feature.
