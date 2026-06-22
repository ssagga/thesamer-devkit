<!--
  This is the kit's OWN brief — a filled-in instance of CLAUDE.template.md, dogfooding the
  system on itself. It is also a worked example of what `devkit-init` produces in a target repo.
  Keep it lean (~100–150 lines). It points to detail; it does not inline it.
-->

# thesamer.devkit — Agent Brief

**What this is:** A reusable agent-driven development *system* — templates, agent roles, and a
setup routine that install into any target repo so one person can develop it continuously with AI
agents across many sessions without the work degrading. **Not an application.**
**Stack:** Markdown (spec + templates), Bash (`bin/devkit-init.sh`), Claude Code skill + agent defs.
No app runtime, no build step beyond shell lint.
**Persistent state:** none (this kit stores no data; target repos may).
**Deploy:** not deployed. Distributed as a kit; "releases" are git tags (e.g. `v0.1.0`).

> This file is the always-loaded brief. If something here is wrong, fixing it is part of the
> current feature's "done" — stale docs are a defect.

---

## How we work here (read before acting)

1. **The repo is the memory; the conversation is disposable.** Anything that must survive this
   session goes into a file first. Resumability test: *if this chat died now, could a fresh agent
   continue from branch + `docs/` alone?* If no, write the missing state down.
2. **One unit of work = one conversation = one branch.** The §10 backlog items in the spec are the
   feature units; each gets its own `feat/<name>` branch.
3. **Don't re-explore the whole repo.** Use this brief + `docs/roadmap.md`; delegate any search to
   an Explorer sub-agent that returns conclusions, not file dumps.
4. **Match the model to the task** (see Model routing). Authoring/judgment work runs mid/top;
   mechanical scaffolding routes down.
5. **Docs currency is part of done.** Update this file, `docs/roadmap.md`, and the decision log in
   the same PR as the change.

---

## Commands

```bash
shellcheck bin/devkit-init.sh        # lint the scaffolder (the closest thing to a "build")
bash bin/devkit-init.sh --help       # see setup-routine usage
bash bin/devkit-init.sh --dry-run /tmp/sandbox   # smoke-test install into a throwaway dir
```

There is no app to run. "Verify" here = run `devkit-init.sh` against a throwaway repo and confirm
the scaffold lands correctly (see `docs/features/` verify plans).

---

## Architecture (map, not a tour)

- **`agent-dev-system-spec.md`** — the source of truth. The why, principles, agent roles, model
  routing, and the §10 build backlog. Read it before changing system behavior.
- **`CLAUDE.template.md`** (root) — the canonical centerpiece: the installable brief template that
  `devkit-init` copies into a target repo and fills in.
- **`templates/`** — everything else that gets installed: `docs/` tree templates, `.claude/agents/`
  role defs, `.github/` CI + PR template.
- **`install.sh`** (root) — one-command bootstrap: fetches the kit tarball from GitHub and runs
  `bin/devkit-init.sh` against the user's cwd. The `curl … | bash` entry point in the README.
- **`bin/devkit-init.sh`** — deterministic scaffolder: detects stack/deploy/store, copies templates,
  fills what it can, creates the docs tree + branch convention.
- **`.claude/skills/devkit-init/`** — the smart entry point that drives the script + fills `CLAUDE.md`.
- **`docs/`** — this kit's *own* roadmap, decisions, and feature specs (dogfooding).

---

## Conventions

- **Branch model:** `feat/<name>` → PR → `main` (integration truth; CI validates) → human merges.
  Releases are **git tags**, not a branch. **Never force-push or commit straight to `main`.**
  (Decision: [docs/decisions/0001](docs/decisions/0001-branch-model-and-setup-routine.md).)
- **Naming / style:** Markdown matches the spec's voice — lean, imperative, no fluff. Bash is
  POSIX-leaning, `set -euo pipefail`, shellcheck-clean.
- **Ceremony:** trivial (copy/style/isolated fix) → branch → PR. Substantial (new template,
  changing install behavior, new agent role) → write `docs/features/<name>.md` first.
- **Definition of done:** build/lint passes · scaffolder actually run & observed against a sandbox ·
  adversarial review done · this brief + `docs/roadmap.md` updated · decision logged if a real
  trade-off was made · PR merged.

---

## Model routing (delegate by task, don't default to top)

| Tier | Use for | Current model |
|------|---------|---------------|
| Cheap/fast | mechanical, well-specified work (file copies, renames, formatting, log/grep scans, status updates) | Haiku |
| Mid | the bulk of authoring/implementation with a clear spec (script logic, template drafting, tests) | Sonnet |
| Top | architecture, the setup-routine design, tricky judgment, final adversarial review | Opus |

The orchestrator runs mid/top and delegates *down* for mechanical sub-tasks. Final review of the
scaffolder runs top-tier.

---

## Where things are written down

- `docs/roadmap.md` — backlog & status (the §10 build items). "What's next" lives here, not in chat.
- `docs/features/<name>.md` — per-feature specs (from `docs/features/_template.md`).
- `docs/decisions/` — append-only decision log (lightweight ADRs). Append when a real trade-off is made.

---

## Project-specific gotchas

- **Two layers, don't confuse them:** `templates/` + `CLAUDE.template.md` are *installable artifacts*
  (blank/placeholder); the kit's own `CLAUDE.md` + `docs/` are *dogfood instances* (filled, real).
  When editing, know which layer you're in.
- **`bin/devkit-init.sh` must stay idempotent** — re-running in an already-initialized repo must not
  clobber human edits. Test that explicitly.
- The remote (`thesamer-devkit`, private) is created via `gh`; `gh auth login` is a manual human step.
