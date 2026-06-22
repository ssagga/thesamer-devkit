---
name: devkit-init
description: Install the agent-driven development system into a target repo in one step. Use when setting up a new (or existing) project to be developed continuously with AI agents — "set up the dev system here", "scaffold CLAUDE.md and the docs tree", "init the devkit", "onboard this repo to the agent workflow". Runs the deterministic scaffolder, then fills the parts a script can't infer and walks the human through review.
---

# devkit-init — install the agent-dev system

You are installing this system (the kit at `thesamer.devkit`) into a target repo. The script does
the deterministic 80%; you do the semantic 20% that a regex cannot, then hand a clean draft to the
human. **The generated `CLAUDE.md` is a draft — never present it as authoritative until reviewed.**

## Step 1 — Run the scaffolder

From the kit, run the deterministic engine against the target repo:

```bash
bash <kit>/bin/devkit-init.sh [--integration-branch NAME] /path/to/target
```

It copies `CLAUDE.md`, `docs/`, `.claude/agents/`, `.claude/skills/pre-pr-review/`, and `.github/`
into the target, fills the unambiguous placeholders (project name, stack, commands, branch model,
CI commands), and prints a list of `TODO`s plus the "how we work here" summary. It never clobbers
existing files unless `--force`. Read its output — the printed TODOs are your work-list.

## Step 2 — Fill what the script couldn't

The script leaves `<!-- TODO: ... -->` markers for everything that needs judgment. Resolve them by
**inspecting the repo** — delegate the search to an Explorer sub-agent so you don't bloat context:

- **One-sentence description** — what the project is and who it's for.
- **Architecture map** — the 3–6 load-bearing directories/areas, one line each. A map to orient an
  agent, not a tour. Don't inline detail; point to `docs/`.
- **Stack line** — refine the script's guess (styling, notable libs, language version).
- **Conventions / gotchas** — formatter, naming, fragile areas, "don't touch X", env quirks.
- **Deploy + live branch** — if a deploy target was detected, confirm the real live branch name and
  fix the `<live-branch>` TODO. If the project does **not** deploy, the live branch is the
  integration branch.
- **Data safety** — if a store was detected, name it precisely and confirm the backup/migration
  rules fit it. If the script reported **no store**, delete the entire `## Data safety` section.

Keep `CLAUDE.md` lean (~100–150 lines). If you're inlining detail, move it to `docs/` and link.

## Step 3 — Set up the branch model

The script auto-initializes a **fresh** repo on the integration branch (and leaves an existing
repo's branches untouched — it only advises there). It never auto-commits. Confirm the human
understands the model: `feat/<name>` → PR → integration (CI validates) → human merges; live
promotion is a separate gate. **Do not create a GitHub remote or push** unless the human explicitly
authorizes it.

## Step 4 — Hand off for review

- List every TODO you resolved and every one still open.
- Tell the human: this brief is now loaded every session; if anything in it is wrong, fixing it is
  part of the next change's "done" — stale docs are a defect.
- Point them to `agent-dev-system-spec.md` (in the kit) for the full operating manual, and to
  `docs/roadmap.md` as the place "what's next" now lives.

## Guardrails

- **Idempotent:** safe to re-run; it skips existing files. Use `--force` only when intentionally
  regenerating, and review the diff.
- **No data loss:** the script only reads the target's store signals; it never touches data.
- **Don't invent facts.** If you can't determine something by inspecting the repo, leave the TODO
  and ask the human rather than guessing — a confidently-wrong brief is worse than an honest gap.
