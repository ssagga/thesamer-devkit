# thesamer.devkit

**A development system for building software continuously with AI agents — without the work
degrading as conversations grow, compact, or end.** It's a set of templates, agent roles, and a
one-step installer you drop *into* any repo. Not an application; the scaffold and method you build
*with*.

> **One line:** the repo is the memory; the conversation is disposable. Everything else follows.

## Why I built it

Agentic development is powerful but leaky. A single long session drifts: context fills up and gets
compacted, decisions made in chat evaporate, the agent re-explores the same code every time, and
quality quietly erodes the longer you go. Start a fresh session and the agent has amnesia — it
doesn't know why the last change was made, what's half-finished, or which parts are fragile.

I wanted one person to be able to drive a project across *dozens* of sessions and many months and
have it get **better**, not muddier. That requires treating the conversation as throwaway and the
**repository as the durable memory** — the brief, the roadmap, the decision log, and the diffs are
the state a fresh agent resumes from. This kit encodes that discipline so you don't have to
re-invent it (or remember to follow it) on every project.

## What it serves

- **Solo builders** running a project continuously with AI agents who want it to stay coherent
  across sessions, not rot.
- **Any repo** — it detects your stack (Node/Python/Go/Rust/Ruby), store, and deploy setup and fills
  a project brief accordingly.
- **Resumability** — the test it's built around: *if this chat died right now, could a fresh agent
  continue from the branch + `docs/` alone?* If the answer is ever "no," something belongs in a file.

---

## Install it into a project

**One command** — run it from inside the repo you want to set up:

```bash
curl -fsSL https://raw.githubusercontent.com/ssagga/thesamer-devkit/main/install.sh | bash
```

It downloads the kit to a temp dir and scaffolds the system into the current directory — detecting
your stack and **never clobbering existing files** (safe to re-run). Pass scaffolder options after
`-s --`:

```bash
curl -fsSL .../install.sh | bash -s -- --dry-run                      # preview, write nothing
curl -fsSL .../install.sh | bash -s -- --integration-branch develop   # non-default integration branch
```

> Prefer to read before piping to a shell? `curl -fsSL .../install.sh -o install.sh && less install.sh && bash install.sh`.
> Cloned the kit already? Run the engine directly: `bash bin/devkit-init.sh /path/to/project`.

**Or just ask your agent** — paste this into a Claude Code session opened in your project:

> Set up this repo with the agent-driven dev system from `github.com/ssagga/thesamer-devkit`.
> Run its `install.sh` (or clone it and run `bin/devkit-init.sh`) against this directory, then
> finish `CLAUDE.md` by reading my code and resolving the `TODO` markers.

**Then finish the brief.** Run the `/devkit-init` skill inside Claude Code — it fills what a script
can't (architecture map, gotchas, deploy/live branch), captures your involvement preferences once,
and walks you through review. Commit on a branch and you're working in the system.

---

## The philosophy (five habits that stop the rot)

1. **The repo is the memory; the conversation is disposable.** Anything that must survive the
   session is written to a file first.
2. **One unit of work = one conversation = one branch.** Scoped context, clean diffs, atomic
   reverts.
3. **Don't re-explore the whole repo.** The always-loaded brief orients you; an Explorer sub-agent
   returns *conclusions*, not file dumps, keeping the main context lean.
4. **Match the model to the task.** Mechanical work routes to a cheap model; the top model is for
   architecture, judgment, and final review — not renames.
5. **Docs currency is part of "done."** The brief, roadmap, and decision log update in the *same PR*
   as the change. Stale docs are a defect, fixed as part of the work that made them stale.

The non-negotiable that falls out of these: **no change reaches the live branch without a reviewable
diff and a human approval.**

---

## The agent architecture (roles & separation)

The system is deliberately **decomposed into single-purpose roles** so each stays in its lane and the
orchestrating context stays small. The main loop orchestrates and delegates; it doesn't do
everything itself.

| Role | Tier | Mandate | Boundary |
|------|------|---------|----------|
| **Explorer** | mid | Search broad, return conclusions not file dumps | Read-only; never edits |
| **Planner** | top | Turn a fuzzy goal into a concrete approach / draft spec | Designs; never implements |
| **Plan-presenter** | top | Consolidate exploration + approach into one approval-ready plan, then **stop for go/no-go** | Read-only; the gate before code |
| **Implementer** | mid | Build to a clear spec on the branch | Stays scoped to the unit of work |
| **Reviewer** | top | Adversarial diff review — *assume the change is wrong until shown otherwise* | Hunts bugs/regressions/data-safety; doesn't rubber-stamp |

**Why separate them?** Each role has a different goal, a different blast radius, and a different
right model. Exploration should be cheap and read-only; planning is high-judgment and shouldn't
touch code; review must be adversarial and independent of the author. Folding them together is how
you get confident-but-wrong work. Keeping them apart keeps context lean and quality honest.

**Standing skills** (installed into every project):

- **`pre-pr-review`** — the standing adversarial review gate; runs before every PR.
- **`status`** — read-only re-orientation digest (branch, roadmap, open PRs + CI, data-safety flags).
- **`preview`** — optional local look at a running change between BUILD and VERIFY (especially UI).
- **`devkit-update`** — safely pull newer kit-owned files without clobbering your project's content.

**Model-tier routing** (encoded in each role's defaults, not left to chance): cheap (Haiku) for
mechanical work, mid (Sonnet) for the bulk of implementation, top (Opus) for architecture, tricky
judgment, and final review.

---

## The lifecycle (ceremony scales with size)

```
ORIENT → SPEC → [PLAN GATE] → BRANCH → BUILD → [PREVIEW] → VERIFY → DOCUMENT → PR → MERGE → RELEASE
```

Two steps are **human-in-the-loop gates** controlled by a `## Working preferences` block in the
brief (so you tune involvement once, per project):

- **Plan gate** — present exactly what will be done and wait for go/no-go before code
  (`always` / `substantial-only` / `never`).
- **Preview gate** — pause to see the change running locally before it's verified
  (`always` / `visual-only` / `never`).
- **Merge & promote stay human, always** — the one non-configurable gate. The agent never merges a
  PR or promotes to the live branch on its own.

Trivial changes skip the spec and gates (branch → PR → merge); substantial ones — anything touching
data shape, public behavior, or an architectural assumption — get the full lifecycle.

---

## Staying current

Each install records provenance (`.claude/devkit.json`: source, version, date). As the kit improves,
`devkit-init.sh --check-updates` shows what's new and `--update` refreshes **only** kit-owned
methodology files — never your filled `CLAUDE.md`, your `docs/`, or generated files. The split
between kit-owned, project-owned, and generated files is what makes updates safe (see
[ADR 0003](docs/decisions/0003-devkit-update-merge-strategy.md)); the [`CHANGELOG`](CHANGELOG.md)
gives you something to read.

---

## What's in this repo

| Path | What it is |
|------|------------|
| [`agent-dev-system-spec.md`](agent-dev-system-spec.md) | **The source of truth** — the why, the principles, the agent roles, the model-routing and data-safety discipline. |
| [`CLAUDE.template.md`](CLAUDE.template.md) | The centerpiece: the lean, always-loaded brief the installer fills into each target repo. |
| [`install.sh`](install.sh) · [`bin/devkit-init.sh`](bin/devkit-init.sh) | One-command bootstrap and the deterministic scaffolder engine it runs. |
| [`.claude/skills/devkit-init/`](.claude/skills/devkit-init/SKILL.md) | The smart entry point — runs the script, then fills the semantic gaps a regex can't. |
| [`templates/`](templates/) | Everything the installer copies in: docs tree, agent roles, the four skills, CI + PR template. |
| [`CLAUDE.md`](CLAUDE.md) · [`docs/`](docs/) | This kit's *own* brief and docs — it's built with its own methodology (dogfooding). |

**Two layers, don't confuse them:** *installable artifacts* (`CLAUDE.template.md`, `templates/`,
`bin/`, the `devkit-init` skill) are blank/placeholder and get copied into targets; *dogfood
instances* (this repo's own `CLAUDE.md` + `docs/`) are filled and real — the proof the system works
on itself.

---

## Status

Built, dogfooded, and shipped. v0.1 delivered the scaffold; **v0.2** hardened it from a real
deployment — recursive store detection, runnable CI, live-branch inference, the plan/preview gates,
enforcement honesty, and update-awareness. Every change here went through `feat/* → PR → CI → merge`.
Backlog and history live in [`docs/roadmap.md`](docs/roadmap.md) and [`CHANGELOG.md`](CHANGELOG.md).

## License

[MIT](LICENSE) © 2026 Samer Al-Saqqa. Use it, fork it, adapt it into your own projects.
