# Roadmap — thesamer.devkit

The backlog for building the kit itself. Status legend: `idea` · `speced` · `in-progress` ·
`shipped`. "What's next" lives here, never only in a chat. Mirrors the spec §10 build order.

## Now / in-progress

| Item | Status | Branch | Notes |
|------|--------|--------|-------|
| System docs (README rewrite, 5-min onboarding) | in-progress | `feat/system-docs` | Last build item before remote. |

## Next

| Item | Status | Spec ref | Notes |
|------|--------|----------|-------|
| GitHub remote + push + activate CI | idea | — | After `gh auth login`. Repo: `thesamer-devkit` (private). Then make CI a required check on `main`. |

## Shipped

| Item | Shipped | Notes |
|------|---------|-------|
| Bootstrap dev-system (branch model, kit's brief + docs) | 2026-06-22 | ADR [0001](decisions/0001-branch-model-and-setup-routine.md). |
| Template files (docs tree + seed ADR) | 2026-06-22 | `templates/docs/`; `CLAUDE.template.md` at root. |
| Agent role definitions | 2026-06-22 | `templates/.claude/agents/` with §6 model-tier defaults. |
| Review + CI gates | 2026-06-22 | `templates/.github/` CI + PR template; `pre-pr-review` skill. |
| Setup routine (`devkit-init` script + skill) | 2026-06-22 | Verified Node/empty/dry-run/force/idempotent. Spec [setup-routine](features/setup-routine.md). |

## Acceptance criteria (definition of done for the whole scaffold — spec §10)

- [x] Can be installed into a fresh repo in one step. — `bin/devkit-init.sh /path` (verified).
- [x] After install, a new conversation has the project brief loaded automatically. — `CLAUDE.md`
      is installed at the target root, which Claude Code loads every session.
- [x] The feature lifecycle (§4) is documented where the agent will follow it. — `CLAUDE.md`
      "How we work" + ceremony + DoD; reinforced in the PR template and README.
- [x] Model-tier routing (§6) is encoded in the agent role defaults, not left to chance. —
      `model:` frontmatter in each `.claude/agents/*` + the routing table in `CLAUDE.md`.
- [x] No path exists for a change to reach the live branch without a reviewable diff. — branch
      model + CI gate + PR template; "never commit to live directly." (Enforced fully once branch
      protection is enabled on the remote — see the remote item above.)
- [x] Data-safety rules (§8) are present and project-specific. — `CLAUDE.md` Data-safety section,
      filled with the detected store (e.g. Prisma) or removed when none.
- [x] Nothing critical lives only in a conversation — the resumability test (§9) passes. — all
      state lives in `CLAUDE.md`, `docs/roadmap.md`, `docs/features/`, `docs/decisions/`.
