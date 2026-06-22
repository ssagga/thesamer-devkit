<!--
  CLAUDE.template.md — copy this to a target repo's root as CLAUDE.md and fill in <PLACEHOLDERS>.
  This file is loaded into the agent's context EVERY session. Keep it lean (~100–150 lines).
  It points to detail; it does not inline it. A bloated brief defeats its own purpose.
  Companion: agent-dev-system-spec.md (the full system spec this template embodies).
-->

# <PROJECT NAME> — Agent Brief

**What this is:** <one-sentence description of the project and who it's for>.
**Stack:** <framework + language + styling + notable libs>.
**Persistent state:** <database / volume / uploads — or "none">.
**Deploy:** <how it ships — branch, CI, target>.

> This file is the always-loaded brief. If something here is wrong, fixing it is part of the
> current feature's "done" — stale docs are a defect.

---

## How we work here (read before acting)

1. **The repo is the memory; the conversation is disposable.** Anything that must survive this
   session goes into a file before it ends. Resumability test: *if this chat died now, could a
   fresh agent continue from branch + docs alone?* If no, write the missing state down.
2. **One unit of work = one conversation = one branch.** Don't build multiple features in one chat.
3. **Don't re-explore the whole repo.** Use this brief; delegate any search to an Explorer
   sub-agent that returns conclusions, not file dumps.
4. **Match the model to the task** (see Model routing below). The main loop does not run the top
   model on mechanical work.
5. **Docs currency is part of done.** Update this file, the roadmap, and the decision log in the
   same PR as the change.

---

## Commands

```bash
<install>      # e.g. pnpm install
<dev>          # e.g. pnpm dev  → http://localhost:3000
<build>        # e.g. pnpm build
<test>         # e.g. pnpm test   (or: "no tests — verify via preview")
<other>        # project-specific scripts worth knowing
```

---

## Architecture (map, not a tour)

- **<area / dir>** — <what lives here, one line>.
- **<area / dir>** — <…>.
- **<area / dir>** — <…>.

Detail lives in `docs/`. Add to the map only what an agent needs to orient; link out for the rest.

---

## Conventions

- **Branch model:** `feat/<name>` → PR → `<integration-branch>` (CI validates) → human merges →
  promote to `<live-branch>` as a deliberate release. **Never commit to `<live-branch>` directly.**
- **Naming / style:** <project conventions — match surrounding code, formatter, etc.>.
- **Ceremony:** trivial changes (copy/style/isolated fix) → branch → PR. Substantial changes
  (new route, schema change, anything touching data/auth/public behavior) → write
  `docs/features/<name>.md` first, then build.
- **Definition of done:** build passes · app actually run & observed · adversarial review done ·
  this brief + `docs/roadmap.md` updated · decision logged if a real trade-off was made · PR merged.

---

## Model routing (delegate by task, don't default to top)

| Tier | Use for | Current model |
|------|---------|---------------|
| Cheap/fast | mechanical, well-specified work (renames, boilerplate, formatting, log/grep scans, status updates) | Haiku |
| Mid | the bulk of implementation with a clear spec | Sonnet |
| Top | architecture, schema/migration design, tricky debugging, security-sensitive logic, final review | Opus |

Anything touching **data, auth, money, or `<live-branch>`** gets top-tier judgment, especially on review.

---

## Data safety <!-- delete this whole section if the project has no persistent state -->

Store: **<the persistent store>**.
- **Additive-only** schema changes by default (`IF NOT EXISTS`, nullable / defaulted). Never drop
  or rename in the same change that ships.
- **Forward-only, versioned migrations** that run deterministically on <boot/deploy>.
- **Back up `<the store>` before any schema change reaches `<live-branch>`.** Hard rule, not best-effort.
- Destructive changes are a two-step ritual: ship additive + migrate first; remove the old shape
  in a later, separately-approved change.

---

## Where things are written down

- `docs/roadmap.md` — backlog & status. "What's next" lives here, never only in a chat.
- `docs/features/<name>.md` — per-feature specs (from `docs/features/_template.md`).
- `docs/decisions/` — append-only decision log (lightweight ADRs). Append when a real trade-off is made.

---

## Project-specific gotchas

- <anything non-obvious that has bitten work before — env quirks, fragile areas, "don't touch X">.
- <…>
