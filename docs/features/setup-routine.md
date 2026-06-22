# Feature: setup-routine (`devkit-init`)

**Status:** in-progress (built; pending merge)
**Branch:** `feat/setup-routine`
**Owner:** orchestrator (Opus) + Implementer (Sonnet) for the script
**Spec written:** 2026-06-22

## Goal

The one-step installer that drops the whole system into any target repo: a filled-in `CLAUDE.md`,
the `docs/` tree, the agent roles, the review/CI gates, and the branch convention. This is the
kit's centerpiece deliverable — it must work the same on project #1 and project #20.

## Scope

- **`bin/devkit-init.sh`** — deterministic engine. Runs with no agent. Detects stack/store/deploy,
  copies templates into the target, fills the unambiguous `CLAUDE.md` + `ci.yml` placeholders,
  ensures the docs tree and integration branch exist, prints a "how we work here" summary.
- **`.claude/skills/devkit-init/SKILL.md`** — smart entry point. Runs the script, then does the
  *semantic* filling a regex can't (architecture map, project description, gotchas), and walks the
  human through reviewing the generated draft.

## Non-goals

- No network calls, no installing dependencies, no creating the GitHub remote (that's a separate,
  human-authorized step).
- The script does not try to write the architecture map or prose brief — it leaves clearly-marked
  `TODO` placeholders for the agent/human. Detection is best-effort, never destructive.

## Approach

**Script (`bin/devkit-init.sh`):**

- `set -euo pipefail`; shellcheck-clean; POSIX-leaning bash.
- Self-locates the kit root from `${BASH_SOURCE[0]}` so it can be run from anywhere against any
  target dir.
- Usage: `devkit-init.sh [options] [TARGET_DIR]` (default `TARGET_DIR=$PWD`).
  - `--help`, `--dry-run` (print actions, write nothing), `--force` (overwrite existing files),
    `--integration-branch NAME` (default `main`), `--no-git` (skip git operations).
- **Detection (best-effort, additive):**
  - Stack: `package.json` (+ lockfile → npm/pnpm/yarn; deps → next/vite/react/etc.),
    `pyproject.toml`/`requirements.txt`, `go.mod`, `Cargo.toml`, `Gemfile`.
  - Commands: from `package.json` scripts when present, else stack defaults; unknown → placeholder.
  - Persistent store: `prisma/schema.prisma`, drizzle config, `*.sqlite`, `docker-compose*.y*ml`
    with a db service, `supabase/`, knex/migrations dirs. None found → mark "none" and tell the
    skill to delete the Data-safety section.
  - Deploy: `vercel.json`/`.vercel`, `netlify.toml`, `fly.toml`, `render.yaml`, `Dockerfile`,
    deploy workflows under `.github/workflows`.
- **Scaffold (idempotent):** copy templates; never clobber an existing file unless `--force`
  (skip + warn instead). Fill unambiguous `CLAUDE.md` tokens (project name, stack line, commands,
  branch names) and `ci.yml` (install/build/test, integration branch). Stamp the seed ADR date.
- **Git:** for a **fresh** target, `git init -b <integration>` (auto-init is part of "init what the
  system needs"); for an **existing** repo, leave branches alone and only advise. Never auto-commit,
  push, or create remotes. (Added in `feat/turnkey-git-init` to make the one-liner fully turnkey.)
- End with a printed "how we work here" summary + the list of `TODO`s the human must resolve.

**Skill (`devkit-init`):** runs the script, reads the generated `CLAUDE.md`, fills the semantic
gaps (one-line description, architecture map, gotchas) by inspecting the repo (delegating to an
Explorer), surfaces every `TODO` for human sign-off, and reminds the human that the brief is a
draft to be corrected — stale docs are a defect.

## Data / schema impact

None — the kit stores no data. The *target* repo's store is only detected, never modified.

## Test / verify plan

- [x] `shellcheck bin/devkit-init.sh` clean.
- [x] `bin/devkit-init.sh --help` prints usage (exit 0).
- [x] Run against a throwaway **Node** repo (Next.js + pnpm + prisma): CLAUDE.md got stack +
      commands + Prisma data-safety filled; docs/agents/.github landed (12 files); idempotent
      re-run skipped all 12 without clobbering.
- [x] Run against an **empty/unknown** repo: no crash; clean single TODO markers; store→none note.
- [x] `--dry-run` wrote nothing (0 files). `--force` overwrote (12 created). Both verified.
- [x] Adversarial review (orchestrator, Opus): fixed a malformed `<boot/deploy>` substitution and a
      dead nested `if`; trimmed a leading blank line in the generated brief. Re-verified clean.

## Notes / open questions

- The script fills only unambiguous tokens; prose is the skill's/human's job — by design, to avoid
  confidently-wrong briefs.
- Idempotency is the highest-risk property (re-running must not destroy human edits) — tested explicitly.
