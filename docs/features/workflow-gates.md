# Feature: workflow & human-in-the-loop gates (v0.2 group C)

**Status:** built; pending merge
**Branch:** `feat/workflow-gates` (stacked on `feat/preferences`)
**Owner:** orchestrator (Opus)
**Spec written:** 2026-06-22
**Backlog:** [v0.2 hardening](../v0.2-real-world-hardening.md) items 6, 7 (group C). Depends on item 0
([preferences](preferences.md)) and item 12 ([ergonomics](ergonomics.md) run-&-observe).

## Goal

Put two human-in-the-loop gates into the lifecycle, both reading the Working-preferences block: a
**plan-presentation gate** that stops for go/no-go before code, and an **optional preview gate** that
lets the human see the change running before it's verified.

## Scope

- **`CLAUDE.template.md`** — added an explicit **`## Feature lifecycle`** section (the template had
  none; the gates had nowhere to attach). It mirrors spec §4 and marks the two gates: **PLAN GATE**
  after SPEC, **PREVIEW (optional)** between BUILD and VERIFY. Both reference the preference that
  controls them.

6. **Plan-presentation gate** — new `templates/.claude/agents/plan-presenter.md` (Opus, read-only).
   Consolidates Explorer findings + Planner approach + draft spec into one approval-ready summary
   (scope · files · approach · data/migration impact · blast radius · verify plan · open questions),
   then **stops for go/no-go**. Fires per the **plan gate** preference; maps to plan mode on Claude
   Code. The kit already had `explorer` + `planner`; this is the missing final consolidation.

7. **Preview gate** — new `templates/.claude/skills/preview/SKILL.md`. Between BUILD and VERIFY,
   optionally launches the change locally (web → dev server + URL/screenshot; CLI/TUI → run; mobile →
   simulator) with `PATH` fallbacks, hands the human a look, then returns to the flow. Fires per the
   **preview gate** preference. Explicitly **not** a replacement for VERIFY.

- **`bin/devkit-init.sh`** — installs both new artifacts and protects them in the gitignore guard
  (install count 13 → 15).

## Non-goals

- The preview skill reuses the project's real launch commands; it does not build a bespoke runner
  (the run-&-observe capability is the item-12 doc foundation; richer automation can come later).
- No change to merge/promote — those stay human-only (the hard gate from item 0).

## Data / schema impact

None.

## Test / verify plan

- [x] `shellcheck` clean.
- [x] Scaffolder installs `plan-presenter.md` + `preview/SKILL.md` (count 13 → 15); idempotent
      re-run; gitignore guard protects both.
- [x] Generated brief carries the `## Feature lifecycle` section with PLAN GATE + PREVIEW steps that
      reference the `plan-presenter` agent, the `preview` skill, and the plan/preview preferences;
      `<integration-branch>`/`<live-branch>` resolve (verified `main`/`production`).
- [x] Agent frontmatter valid (name/description/tools/model); skill frontmatter valid
      (name/description). Both consistent with the existing `planner`/`pre-pr-review` conventions.

## Notes / open questions

- `plan-presenter` is Opus because it's the last gate before code and an incomplete plan is
  expensive — the human approves what it presents. It consolidates rather than re-derives, so cost
  is bounded.
- The lifecycle section is new to the template but canonical (spec §4); it also gives items 10/12's
  prose a structural home.
