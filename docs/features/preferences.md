# Feature: involvement-preferences mechanism (v0.2 item 0 — keystone)

**Status:** built; pending merge
**Branch:** `feat/preferences` (stacked on `feat/ergonomics`)
**Owner:** orchestrator (Opus)
**Spec written:** 2026-06-22
**Backlog:** [v0.2 hardening](../v0.2-real-world-hardening.md) item 0 (cross-cutting). Unblocks items
6 and 7 (group C).

## Goal

One place the installed system reads involvement preferences from, captured once at install, so the
later plan-gate (item 6) and preview-gate (item 7) read a single source instead of each hardcoding
behavior.

## Decision: a `## Working preferences` block in `CLAUDE.md` (not `.claude/devkit.json`)

The spec offered either. I chose the human-readable Markdown block because:

- The agent already loads `CLAUDE.md` every session and reads it natively — **no parser, no tool
  call** to consult preferences.
- It's editable by hand in the one file the human already curates.
- It keeps the "repo is the memory" principle: the preference lives next to the methodology it
  governs, not in a side file that can drift.

A JSON file would force every gate to shell out and parse, and split the source of truth.

## Scope

- **`CLAUDE.template.md`** — new `## Working preferences` section with three gates and defaults:
  - **Plan gate:** `substantial-only` (options `always` / `substantial-only` / `never`).
  - **Preview gate:** `visual-only` (options `always` / `visual-only` / `never`).
  - **Merge & promote:** human, always — **not configurable** (the one hard gate).
  Reuses the existing `<live-branch>` fill.
- **`.claude/skills/devkit-init/SKILL.md`** — new "Step 3 — Capture working preferences (ask once)"
  that asks the human whether the defaults fit and writes their answers into the block; renumbered
  the later steps. Also aligned the now-stale "delete the Data safety section" instruction with the
  shipped "never delete on a false negative" behavior (group A).

## Non-goals

- The deterministic script stays non-interactive; it ships the defaults. The interactive *skill*
  asks the one-time question. No new script flags.
- Items 6 and 7 (the gates that consume this) are separate PRs (group C).

## Data / schema impact

None.

## Test / verify plan

- [x] `shellcheck` clean.
- [x] Generated `CLAUDE.md` carries the `## Working preferences` block with defaults, and
      `<live-branch>` resolved (verified `production` via a deploy-workflow fixture — composes with
      group B's inference).
- [x] No new script placeholders introduced; existing generation/idempotency unaffected.

## Notes / open questions

- Defaults match the kit's existing posture: `substantial-only` mirrors the ceremony rule; merge/
  promote-stay-human mirrors ADR 0001 + 0002.
