# thesamer.devkit

A reusable **agent-driven development system** — templates, agent roles, and a one-step installer
that let a single person develop projects continuously with AI agents, across many sessions,
**without the work degrading** as conversations grow, compact, or end.

This is **not** an application. It is the scaffold and methodology you install *into* other repos.

> **Core idea (one line):** The repo is the memory; the conversation is disposable.
> Everything else follows from that.

---

## Install it into a project (one step)

From this kit, point the installer at any target repo:

```bash
bash bin/devkit-init.sh /path/to/your-project
# options: --integration-branch NAME · --dry-run · --force · --no-git
```

It scaffolds the whole system into the target and **never clobbers existing files** (re-runnable):

- `CLAUDE.md` — the always-loaded brief, with detected stack/commands/branch model filled in and
  `TODO` markers left wherever it couldn't infer.
- `docs/` — `roadmap.md`, `features/_template.md`, `decisions/` (+ a seed ADR explaining the system).
- `.claude/agents/` — Explorer, Planner, Implementer, Reviewer, with model-tier defaults.
- `.claude/skills/pre-pr-review/` — the standing adversarial review gate.
- `.github/` — a build-validation CI workflow + a PR template embedding the Definition of Done.

**Inside an agent session**, run the `/devkit-init` skill instead — it runs the script, then fills
the parts a script can't (architecture map, gotchas, deploy/live branch) and walks you through
review. Then commit the result on a branch and you're working in the system.

---

## How the workflow works (the 5-minute version)

Every unit of work is **one branch → one PR → one merge**, and flows through a lifecycle whose
ceremony scales with size:

```
ORIENT → SPEC (substantial only) → BRANCH → BUILD → VERIFY → DOCUMENT → PR → MERGE → RELEASE
```

The habits that keep it from degrading across sessions:

1. **Repo is the memory.** Anything that must survive the session is written to a file first.
   Resumability test: *if this chat died now, could a fresh agent continue from branch + docs alone?*
2. **One unit of work = one conversation = one branch.** Scoped context, clean diffs, atomic reverts.
3. **Don't re-explore the whole repo.** The brief orients you; an Explorer sub-agent returns
   conclusions, not file dumps.
4. **Match the model to the task.** Mechanical work routes to a cheap model; the top model is for
   architecture, tricky judgment, and final review — not renames.
5. **Docs currency is part of "done."** The brief, roadmap, and decision log are updated in the same
   PR as the change. Stale docs are a defect.

No change reaches the live branch without a reviewable diff and a human approval.

---

## What's in this repo

| Path | What it is |
|------|------------|
| [`agent-dev-system-spec.md`](agent-dev-system-spec.md) | **The source of truth.** The why, the principles, the agent roles, the model-routing strategy, the data-safety discipline. Read this to understand the system. |
| [`CLAUDE.template.md`](CLAUDE.template.md) | The canonical centerpiece — the lean, always-loaded brief the installer fills into each target repo. |
| [`bin/devkit-init.sh`](bin/devkit-init.sh) | The deterministic one-step installer. |
| [`.claude/skills/devkit-init/`](.claude/skills/devkit-init/SKILL.md) | The smart entry point (runs the script + fills semantic gaps). |
| [`templates/`](templates/) | Everything the installer copies into a target: docs tree, agent roles, CI + PR template, review skill. |
| [`CLAUDE.md`](CLAUDE.md) · [`docs/`](docs/) | This kit's *own* brief and docs — it is built using its own methodology (dogfooding). |

---

## Two layers (don't confuse them)

- **Installable artifacts** — `CLAUDE.template.md` + `templates/` + `bin/` + the `devkit-init` skill.
  These are blank/placeholder; they get copied into target repos.
- **Dogfood instances** — this repo's own `CLAUDE.md` + `docs/`. Filled, real, and the proof the
  system works on itself.

---

## Status

Scaffold **built and dogfooded**: template files, agent roles, review + CI gates, the `devkit-init`
script + skill, and this documentation are in place. The installer is verified against Node, empty,
dry-run, force, and idempotent-rerun cases. Next: wire up the GitHub remote so CI activates and PRs
become real (see [`docs/roadmap.md`](docs/roadmap.md)).
