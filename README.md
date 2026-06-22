# thesamer.devkit

A reusable **agent-driven development system** — files, conventions, and agent roles that let
a single person develop projects continuously with AI agents, across many sessions, without the
work degrading as conversations grow, compact, or end.

This is **not** an application. It is the scaffold and methodology that gets installed *into*
other projects.

## What's here

| File | What it is |
|------|------------|
| [`agent-dev-system-spec.md`](agent-dev-system-spec.md) | The full specification. The **why**, the principles, the agent roles, the model-routing strategy, and the build backlog. |
| [`CLAUDE.template.md`](CLAUDE.template.md) | The drop-in artifact. A lean, copy-verbatim `CLAUDE.md` an agent installs into each target repo and fills in. It's the brief loaded every session. |

## For the implementing agent — start here

1. **Read [`agent-dev-system-spec.md`](agent-dev-system-spec.md) in full.** It is the source of truth.
2. **Treat spec §10 ("What the receiving agent should build") as your backlog**, and the
   acceptance criteria in §10 + the Definition of Done in §4.2 as *your* definition of done.
3. **Treat [`CLAUDE.template.md`](CLAUDE.template.md) as the canonical centerpiece** — the system's
   job is to install a filled-in version of it into each target repo.
4. Build the scaffold so it can be installed into any fresh repo in one step (spec §3, §10).

## Core idea (one line)

> The repo is the memory; the conversation is disposable. Everything else follows from that.

## Status

Specification + template authored. Scaffold (setup routine, agent role definitions, CI/review
gates) **not yet built** — that is the next agent's job, per spec §10.
