# thesamer.devkit

A reusable **agent-driven development system** — templates, agent roles, and a one-step installer
that let a single person develop projects continuously with AI agents, across many sessions,
**without the work degrading** as conversations grow, compact, or end.

This is **not** an application. It is the scaffold and methodology you install *into* other repos.

> **Core idea (one line):** The repo is the memory; the conversation is disposable.
> Everything else follows from that.

---

## Install it into a project

**One command** — run it from inside the repo you want to set up:

```bash
curl -fsSL https://raw.githubusercontent.com/ssagga/thesamer-devkit/main/install.sh | bash
```

It downloads the kit to a temp dir and scaffolds the system into the current directory —
**without clobbering existing files** (safe to re-run). Pass scaffolder options after `-s --`:

```bash
curl -fsSL https://raw.githubusercontent.com/ssagga/thesamer-devkit/main/install.sh | bash -s -- --dry-run
curl -fsSL https://raw.githubusercontent.com/ssagga/thesamer-devkit/main/install.sh | bash -s -- --integration-branch develop
```

> Prefer to read before you pipe to a shell? Download it first:
> `curl -fsSL https://raw.githubusercontent.com/ssagga/thesamer-devkit/main/install.sh -o install.sh && less install.sh && bash install.sh`
>
> While this repo is **private**, the `curl` URL won't resolve — clone with `gh` instead:
> `gh repo clone ssagga/thesamer-devkit /tmp/devkit && (cd your-project && bash /tmp/devkit/bin/devkit-init.sh)`

**Or just ask your agent** — paste this into a Claude Code session opened in your project:

> Set up this repo with the agent-driven dev system from `github.com/ssagga/thesamer-devkit`.
> Run its `install.sh` (or clone it and run `bin/devkit-init.sh`) against this directory, then
> finish `CLAUDE.md` by reading my code and resolving the `TODO` markers.

Either path scaffolds:

- `CLAUDE.md` — the always-loaded brief, with detected stack/commands/branch model filled in and
  `TODO` markers left wherever it couldn't infer.
- `docs/` — `roadmap.md`, `features/_template.md`, `decisions/` (+ a seed ADR explaining the system).
- `.claude/agents/` — Explorer, Planner, Implementer, Reviewer, with model-tier defaults.
- `.claude/skills/pre-pr-review/` — the standing adversarial review gate.
- `.github/` — a build-validation CI workflow + a PR template embedding the Definition of Done.

**Then finish the brief.** Inside a Claude Code session, run the `/devkit-init` skill — it fills the
parts a script can't (architecture map, gotchas, deploy/live branch) and walks you through review.
Commit the result on a branch and you're working in the system.

> **Cloned the kit for local/dev use?** Skip the download and run the engine directly:
> `bash bin/devkit-init.sh /path/to/project` (options: `--integration-branch NAME · --dry-run · --force · --no-git`).

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
| [`install.sh`](install.sh) | One-command bootstrap: fetches the kit from GitHub and runs the scaffolder against your repo. |
| [`bin/devkit-init.sh`](bin/devkit-init.sh) | The deterministic scaffolder engine (what `install.sh` runs). |
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
