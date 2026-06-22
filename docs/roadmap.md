# Roadmap — thesamer.devkit

The backlog for building the kit itself. Status legend: `idea` · `speced` · `in-progress` ·
`shipped`. "What's next" lives here, never only in a chat. Mirrors the spec §10 build order.

## Now / in-progress

| Item | Status | Branch | Notes |
|------|--------|--------|-------|
| Setup routine (`bin/devkit-init.sh` + `devkit-init` skill) | in-progress | `feat/setup-routine` | Built & verified; spec [setup-routine](features/setup-routine.md). Pending merge. |

## Next (the §10 build backlog)

| Item | Status | Spec ref | Notes |
|------|--------|----------|-------|
| System docs (README rewrite, 5-min onboarding) | speced | §10.6 | Last build item before remote. |
| GitHub remote + push + activate CI | idea | — | After `gh auth login`. Repo: `thesamer-devkit` (private). |

## Shipped

| Item | Shipped | Notes |
|------|---------|-------|
| Bootstrap dev-system (branch model, kit's brief + docs) | 2026-06-22 | ADR [0001](decisions/0001-branch-model-and-setup-routine.md). |
| Template files (docs tree + seed ADR) | 2026-06-22 | `templates/docs/`; `CLAUDE.template.md` at root. |
| Agent role definitions | 2026-06-22 | `templates/.claude/agents/` with §6 model-tier defaults. |
| Review + CI gates | 2026-06-22 | `templates/.github/` CI + PR template; `pre-pr-review` skill. |

## Acceptance criteria (definition of done for the whole scaffold — spec §10)

- [ ] Can be installed into a fresh repo in one step.
- [ ] After install, a new conversation has the project brief loaded automatically.
- [ ] The feature lifecycle (§4) is documented where the agent will follow it.
- [ ] Model-tier routing (§6) is encoded in the agent role defaults, not left to chance.
- [ ] No path exists for a change to reach the live branch without a reviewable diff.
- [ ] Data-safety rules (§8) are present and project-specific.
- [ ] Nothing critical lives only in a conversation — the resumability test (§9) passes.
