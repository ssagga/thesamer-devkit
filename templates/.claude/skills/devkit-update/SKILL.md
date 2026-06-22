---
name: devkit-update
description: Check whether this project has drifted from the devkit it was installed from, and safely pull in newer kit-owned files (agent defs, skills, methodology) without clobbering project-authored content. Use when asked to "update the devkit", "check for devkit updates", "refresh the agent system", or to see what changed since install.
---

# devkit-update — keep this project current with the kit

This project was scaffolded by `thesamer.devkit`. Over time the kit improves; this skill pulls those
improvements in **safely**. The contract (devkit ADR 0003): only **kit-owned** files are refreshed;
**project-authored** files (`CLAUDE.md`, `docs/roadmap.md`, your specs + decisions) and **generated**
files (`.github/workflows/ci.yml`, the PR template, the `_template` docs) are never auto-clobbered.

## Step 1 — Read provenance

Read `.claude/devkit.json` for `devkit_source` and `devkit_version`. If it's missing, this project
predates provenance — tell the human; a one-time normal `devkit-init.sh` run records it.

## Step 2 — Fetch the latest kit

Clone or download the devkit to a temp dir (the human authorizes network use):

```bash
git clone --depth 1 <devkit_source> /tmp/devkit-latest    # or curl the release tarball
```

Compare `/tmp/devkit-latest/VERSION` to the recorded `devkit_version`.

## Step 3 — Show what changed

- Summarize the relevant `/tmp/devkit-latest/CHANGELOG.md` entries **since** the recorded version.
- Run the kit's own dry report against this project:
  ```bash
  bash /tmp/devkit-latest/bin/devkit-init.sh --check-updates .
  ```
  It lists kit-owned files that differ or are new. Show the human this list.

## Step 4 — Apply, with consent

- For a clean refresh of kit-owned files, **preview then apply**:
  ```bash
  bash /tmp/devkit-latest/bin/devkit-init.sh --update --dry-run .   # preview
  bash /tmp/devkit-latest/bin/devkit-init.sh --update .             # apply (after human OK)
  ```
  This refreshes only `KIT_OWNED_PURE` files and bumps `.claude/devkit.json`.
- For **generated/ambiguous** files (`ci.yml`, PR template, `_template`s) the updater does **not**
  touch them. If the CHANGELOG says they changed and the human wants them, `diff` the kit version
  against the project's and let the human accept hunks by hand — never blind-overwrite.
- **Never** overwrite `CLAUDE.md` or `docs/` content. If the methodology changed in a way that
  affects the brief's prose, surface the diff and let the human merge it deliberately.

## Step 5 — Verify & record

- Re-run `--check-updates .` to confirm everything intended now matches.
- Note the version bump in the PR that carries the update (status updates ride the same PR).

## Rules

- **Consent before applying.** Show the diff/summary first; apply only on go-ahead.
- **Kit-owned vs project-owned is the safety line** — when unsure which a file is, treat it as
  project-owned and diff-and-confirm rather than overwrite.
- Clean up the temp clone when done.
