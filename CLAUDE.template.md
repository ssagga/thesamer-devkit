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

## Working preferences

How much the agent pauses for you. `devkit-init` asks once at install; edit anytime — the agent
reads these values directly, no tooling required. Every gate in the lifecycle reads this block
instead of hardcoding behavior.

- **Plan gate:** `substantial-only` — present a concrete, approval-ready plan and wait for your
  go/no-go before writing code. Options: `always` · `substantial-only` · `never`. (When `never`,
  planning still happens — it just doesn't stop for sign-off. On Claude Code, `always` /
  `substantial-only` map to plan mode.)
- **Preview gate:** `visual-only` — after BUILD, pause to let you see the change running locally
  before VERIFY. Options: `always` · `visual-only` · `never`.
- **Merge & promote:** **human, always — not configurable.** The agent never merges a PR or promotes
  to `<live-branch>` on its own. This is the one hard gate.

---

## Commands

```bash
<install>      # e.g. pnpm install
<dev>          # e.g. pnpm dev  → http://localhost:3000
<build>        # e.g. pnpm build
<test>         # e.g. pnpm test   (or: "no tests — verify via preview")
<other>        # project-specific scripts worth knowing
```

**Run & observe (don't trust the diff — watch it work).** Before calling a change done, launch the
app and look: web → start `<dev>`, open the URL, screenshot the changed view; CLI/TUI → run it;
mobile → boot the simulator. If the package manager or runtime isn't on `PATH`, fall back to the
local binaries (`./node_modules/.bin/<tool>`, `npx <tool>`, or the venv) rather than giving up.

---

## Architecture (map, not a tour)

- **<area / dir>** — <what lives here, one line>.
- **<area / dir>** — <…>.
- **<area / dir>** — <…>.

Detail lives in `docs/`. Add to the map only what an agent needs to orient; link out for the rest.

---

## Feature lifecycle

Every unit of work flows through this; ceremony scales with size (see Conventions → Ceremony). Two
steps are **gates** that read the Working-preferences block above.

1. **ORIENT** — the brief is already loaded. Read the roadmap + relevant spec if resuming. Don't
   re-explore; delegate search to an Explorer.
2. **SPEC** — for substantial work, write `docs/features/<name>.md` first.
3. **PLAN GATE** — consolidate the Explorer findings, the chosen approach, and the draft spec into
   one approval-ready summary (scope · files to create/change · approach · data/migration impact ·
   verify plan) and **wait for go/no-go before writing code.** Fires per the **plan gate**
   preference; delegate to the `plan-presenter` agent. On Claude Code this maps to plan mode. When
   `never`, planning still happens — it just doesn't stop for sign-off.
4. **BRANCH** — `feat/<name>` from `<integration-branch>`. Never work on `<live-branch>`.
5. **BUILD** — implement on the branch; delegate sub-tasks by model tier.
6. **PREVIEW (optional)** — before verifying, optionally launch the change locally so you can look —
   *especially for visual/UI work* — instead of running straight to the end. Fires per the
   **preview gate** preference; use the `preview` skill. Skipped when `never`, or for non-visual
   changes under `visual-only`.
7. **VERIFY** — run the build, run/observe the app, run the adversarial review pass; fix findings.
8. **DOCUMENT** — update this brief, roadmap status, and the decision log — in the **same PR**.
9. **PR → MERGE** — open a PR into `<integration-branch>`; the **human** reviews and merges.
10. **RELEASE** — promote to `<live-branch>` as a deliberate, separate, **human-only** gate.

---

## Conventions

- **Branch model:** `feat/<name>` → PR → `<integration-branch>` (CI validates) → human merges →
  promote to `<live-branch>` as a deliberate release. **Never commit to `<live-branch>` directly.**
  This is *enforced* only when `<integration-branch>` is branch-protected on the remote (required PR
  + green CI); otherwise it is **convention** the agent and human uphold. (`devkit-init` reports
  which one is in effect and offers a local `pre-push` backstop.)
- **Naming / style:** <project conventions — match surrounding code, formatter, etc.>.
- **Ceremony:** trivial changes (copy/style/isolated fix) → branch → PR. Substantial changes
  (new route, schema change, anything touching data/auth/public behavior) → write
  `docs/features/<name>.md` first, then build.
- **Definition of done:** build passes · app actually run & observed · adversarial review done ·
  this brief + `docs/roadmap.md` updated · decision logged if a real trade-off was made · PR merged.
- **Status updates ride the same PR.** Flip the roadmap row to `shipped` *in the PR that ships the
  work* — merging the PR is what ships it. Never open a separate status-only PR.

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
- **Build-time vs runtime data.** If the build can't see the production store, do **not** statically
  pre-render pages that read it — they bake a build-time snapshot and silently serve stale or seed
  data after every deploy (this exact bug bit in the wild). For any store-backed page, render
  dynamically at request time, or cache at runtime with on-demand invalidation — never freeze store
  reads into the build.

---

## Where things are written down

- `docs/roadmap.md` — backlog & status. "What's next" lives here, never only in a chat.
- `docs/features/<name>.md` — per-feature specs (from `docs/features/_template.md`).
- `docs/decisions/` — append-only decision log (lightweight ADRs). Append when a real trade-off is made.

---

## Project-specific gotchas

- <anything non-obvious that has bitten work before — env quirks, fragile areas, "don't touch X">.
- <…>
