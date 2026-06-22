# 0001 — Adopt the agent-driven development system

**Status:** accepted
**Date:** <YYYY-MM-DD — set at install>

## Context

This project is developed continuously by one person working with AI agents across many sessions.
Without structure, that mode of work fails in predictable ways: every new conversation starts blind
and re-derives the project (burning context), long sessions get summarized and lose in-flight
intent, one chat tries to do everything, the top model runs trivial work, changes land straight on
the deploy branch with no review, and docs rot until they mislead.

## Decision

Adopt the agent-driven development system. Concretely, this repo now carries:

- **`CLAUDE.md`** — a lean, always-loaded brief (architecture, commands, conventions, model
  routing, data-safety rules, definition of done). It is the first thing every session reads.
- **`docs/roadmap.md`** — the single source of "what's next."
- **`docs/features/<name>.md`** — a spec written *before* building anything substantial.
- **`docs/decisions/`** — this append-only log.
- **`.claude/agents/`** — scoped sub-agent roles (Explorer, Planner, Implementer, Reviewer) with
  model-tier defaults, so the orchestrating thread stays lean and cheap work routes to cheap models.
- A **branch + review model** where no change reaches the live branch without a reviewable diff.

The governing principle: **the repo is the memory; the conversation is disposable.** Anything that
must survive a session is written to a file before the session ends.

## Why

- It makes work **resumable from files alone** — a fresh agent can continue from branch + docs even
  if the chat is gone, which neutralizes context amnesia and compaction loss.
- It keeps **diffs atomic and reversible** (one unit of work = one branch = one PR).
- It **matches model cost to task**, so the expensive model is not wasted on renames and formatting.
- It treats **doc currency as part of "done,"** so the brief stays trustworthy instead of rotting.

## Consequences

- Every substantial change starts with a short spec and ends with updated docs in the same PR —
  slightly more ceremony per change, far less rework and re-discovery over the project's life.
- The full rationale and the operating manual live in the kit's `agent-dev-system-spec.md`; this
  entry only records the local decision to adopt it. Future trade-offs get their own ADRs here.
