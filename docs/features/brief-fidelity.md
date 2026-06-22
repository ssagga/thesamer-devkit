# Feature: brief & branch-model fidelity (v0.2 group B)

**Status:** built; pending merge
**Branch:** `feat/brief-fidelity` (stacked on `feat/installer-correctness`)
**Owner:** orchestrator (Opus)
**Spec written:** 2026-06-22
**Backlog:** [v0.2 hardening](../v0.2-real-world-hardening.md) items 4, 5 (group B).

## Goal

Make the generated brief tell the truth about two things the first deployment got wrong: which
branch actually ships to production, and the build-time-vs-runtime data hazard that caused the one
prod bug that bit.

## Scope

4. **Infer the live/deploy branch from existing workflows** — `detect_stack` + `build_claude_md`.
   The kit defaulted live == integration. Real project: `main` = CI, `production` = deploy. Now we
   scan deploy-flavored workflows (`deploy|release|publish`) for the branch they ship from —
   `on.push.branches` (inline `[a, b]`, compact flow, and block `- a`) and
   `if: github.ref == 'refs/heads/<x>'` guards — and surface the first non-integration branch
   (preferring well-known names: production/prod/release/live/stable/deploy/master/main). It threads
   through every `<live-branch>` slot in the brief (branch model, data-safety backup rule, top-tier
   review trigger) with a confirm TODO. When no distinct branch is found, behaviour is unchanged
   (live == integration, or a TODO if a deploy target exists).

5. **"Build-time vs runtime data" hazard** — `CLAUDE.template.md` Data-safety section. Generalizes
   the prod bug: if the build can't see the production store, do not statically pre-render pages that
   read it — they bake a build-time snapshot and serve stale/seed data after every deploy. Recommends
   dynamic rendering or runtime caching with on-demand invalidation. Rides in the (conditional)
   Data-safety section, so it appears only when there's a store.

## Non-goals

- Not a full YAML parser — best-effort regex/awk over the two reliable branch signals. On
  uncertainty it leaves the existing TODO rather than guessing.
- No change to the branch model itself; only to how accurately the brief names the live branch.

## Approach notes

- New `STACK_LIVE_BRANCH` + `extract_wf_branches()` (awk: `refs/heads/<x>` and `branches:` lists).
  Tokens are quote/space-cleaned by the caller; a known-name preference list disambiguates when a
  deploy workflow lists several branches.
- Item 5 is template prose; it benefits from item 1's "keep the Data-safety section" fix — the
  hazard is only useful when the section survives.

## Data / schema impact

None.

## Test / verify plan

- [x] `shellcheck` clean.
- [x] **Block-style fixture** (`ci.yml` on `main`, `deploy.yml` on `production` w/ `refs/heads`
      guard): live branch inferred `production`; threaded into brief's branch model, data-safety
      backup line, and review trigger; confirm TODO emitted.
- [x] **Inline/flow fixture** (`on: { push: { branches: ["release"] } }`): inferred `release`.
- [x] **Deploy-from-integration fixture** (`deploy.yml` on `main`): no distinct branch → unchanged
      behaviour (deploy TODO, live == integration), not a wrong guess.
- [x] **No-workflow regression** (nested-sqlite): Deploy `unknown`, no live-branch line; item-5
      hazard prose present in the generated brief (store detected → section kept).

## Notes / open questions

- The generic `CI/CD (workflow detected)` deploy label reads a little awkwardly in the
  `(branch: X → CI/CD (workflow detected))` line; acceptable with the confirm TODO. Could be
  refined when a richer deploy-target taxonomy lands.
- **Adversarial review** confirmed the awk state machine and the global `<live-branch>` replacement,
  and flagged one latent `set -e` footgun: the fallback `grep -vxF` exits 1 if nothing remains after
  excluding the integration branch, which would abort under `pipefail`. In practice the trailing
  newline kept grep at exit 0, but I added `|| true` to make the safe outcome explicit. Re-verified
  with a `refs/heads/main`-only stress fixture that completes cleanly.
