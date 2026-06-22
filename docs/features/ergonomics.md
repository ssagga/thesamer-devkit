# Feature: enforcement honesty & ergonomics (v0.2 group E)

**Status:** built; pending merge
**Branch:** `feat/ergonomics` (stacked on `feat/brief-fidelity`)
**Owner:** orchestrator (Opus)
**Spec written:** 2026-06-22
**Backlog:** [v0.2 hardening](../v0.2-real-world-hardening.md) items 9, 10, 11, 12 (group E).

## Goal

Four ergonomics/honesty quick wins so the installed system tells the truth about enforcement, cuts
needless ceremony, and re-orients fast between sessions.

## Scope

9. **Be honest about enforcement** — `bin/devkit-init.sh` + `CLAUDE.template.md`. New
   `report_enforcement()`: states that the branch model is *enforced* only with branch protection,
   *convention* otherwise; read-only `gh` visibility check (degrades gracefully without gh/remote)
   that reports whether protection is available + how to enable it; writes an **inactive**
   `pre-push.devkit-sample` backstop the human activates with one `mv`. Does **not** auto-mutate
   GitHub settings — ADR [0002](../decisions/0002-enforcement-report-not-auto-apply.md).

10. **Cut status-flip ceremony** — `CLAUDE.template.md` DoD + PR template. States roadmap status
    flips ride the shipping PR (merging ships it); no separate status-only PR.

11. **Read-only `/status` digest skill** — `templates/.claude/skills/status/SKILL.md`. Branch +
    uncommitted work, roadmap now/next, open PRs + CI state, data-safety flags. Pure projection of
    the source of truth; never writes. Installed by the scaffolder + protected by the gitignore
    guard.

12. **Smooth "run & observe"** — `CLAUDE.template.md` Commands section. Documents per-app-type
    launch + screenshot and `PATH` fallbacks (`./node_modules/.bin`, `npx`, venv). The actual
    capability is built later in item 7's preview skill; this is the doc foundation.

## Non-goals

- No auto-applying branch protection (ADR 0002). No interactive prompts in the script.
- Item 11's skill describes behavior; it relies on `gh` at use-time and says so when absent.

## Data / schema impact

None.

## Test / verify plan

- [ ] `shellcheck` clean.
- [ ] Scaffolder installs the new `status` skill (file count 12 → 13); idempotent re-run skips it;
      gitignore guard now protects it too.
- [ ] `report_enforcement` prints the convention/enforced honesty note; with no `gh`/remote it skips
      the visibility check gracefully (no crash); writes an inactive `pre-push.devkit-sample` once
      (idempotent) and does not block pushing.
- [ ] Generated `CLAUDE.md` carries the enforcement-honesty note, the status-update-rides-the-PR DoD
      line, and the run-&-observe note.
- [ ] PR template shows the updated status-flip checklist line.

## Notes / open questions

- The `pre-push` sample is intentionally inactive; activating it is a one-line opt-in so a first
  push is never blocked by surprise.
