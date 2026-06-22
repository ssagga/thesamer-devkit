# 0002 — Installer reports enforcement, it does not auto-apply branch protection

**Status:** accepted
**Date:** 2026-06-22

## Context

v0.2 hardening item 9 ("be honest about enforcement") was motivated by the kit claiming "no
unreviewed change reaches live" when, on a private free-tier GitHub repo, branch protection isn't
available (the API returns `403 — Upgrade to Pro or make public`). The backlog item's wording was
"detect visibility/plan, **set protection when possible**, else print the exact options."

Taken literally, "set protection when possible" means `devkit-init` would mutate the user's GitHub
repository settings during a scaffold run.

## Decision

`devkit-init` **reports** enforcement reality and **offers** a local backstop; it does **not**
auto-apply branch protection.

- It checks repo visibility read-only (via `gh`, only if `gh` + an `origin` remote exist) and prints
  whether protection is available, plus the exact path to enable it (Settings → Branches, or a
  `gh api … /protection` command).
- It writes an **inactive** `pre-push.devkit-sample` hook (convention-only backstop) that the human
  activates with one `mv`. It is never installed active, so it can't block a first push by surprise.
- The brief and README state plainly that the branch model is *enforced* only with protection and
  *convention* otherwise.

## Why

- Setting branch protection is an outward-facing, account-affecting mutation of the user's repo. It
  belongs to the same class of actions the kit already refuses to do silently: ADR
  [0001](0001-branch-model-and-setup-routine.md) and `CLAUDE.md` establish "never auto-commit, push,
  or create remotes; `gh auth login` is a manual human step." Auto-enabling protection would break
  that consistency and could surprise a user who wanted different settings.
- The installer must stay **offline-safe and non-interactive**. A read-only visibility check that
  degrades gracefully (no `gh`, no remote → skip) preserves that; a write would not.
- An inactive sample hook honors "offer a backstop" without imposing blocking behavior the user
  didn't ask for.

## Consequences

- The honesty goal of item 9 is met (the user always learns whether the gate is enforced or
  convention), but the human performs the one-time protection step themselves.
- If a future flag like `--enforce` is wanted for power users who *do* want auto-protection, it can
  be added opt-in without changing the safe default.
