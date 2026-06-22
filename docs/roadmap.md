# Roadmap — thesamer.devkit

The backlog for building the kit itself. Status legend: `idea` · `speced` · `in-progress` ·
`shipped`. "What's next" lives here, never only in a chat. Mirrors the spec §10 build order.

## Now / in-progress

| Item | Status | Branch | Notes |
|------|--------|--------|-------|
| Bootstrap dev-system (branch model, kit's own brief + docs) | in-progress | `main` | Dogfood setup. ADR [0001](decisions/0001-branch-model-and-setup-routine.md). |

## Next (the §10 build backlog)

| Item | Status | Spec ref | Notes |
|------|--------|----------|-------|
| Template files (docs tree + seed ADR template + 0001 system ADR) | idea | §10.1, §3 | `CLAUDE.template.md` already exists at root. |
| Agent role definitions (Explorer/Planner/Implementer/Reviewer) | idea | §10.3, §5, §6 | Model-tier defaults baked in. |
| Review + CI gates (adversarial review step, build CI, PR template w/ DoD) | idea | §10.4, §10.5, §7 | CI dormant until remote exists. |
| Setup routine (`bin/devkit-init.sh` + `devkit-init` skill) | idea | §10.2 | The one-step installer; centerpiece delivery. |
| System docs (README rewrite, 5-min onboarding) | idea | §10.6 | |
| GitHub remote + push + activate CI | idea | — | After `gh auth login`. Repo: `thesamer-devkit` (private). |

## Shipped

_(nothing yet)_

## Acceptance criteria (definition of done for the whole scaffold — spec §10)

- [ ] Can be installed into a fresh repo in one step.
- [ ] After install, a new conversation has the project brief loaded automatically.
- [ ] The feature lifecycle (§4) is documented where the agent will follow it.
- [ ] Model-tier routing (§6) is encoded in the agent role defaults, not left to chance.
- [ ] No path exists for a change to reach the live branch without a reviewable diff.
- [ ] Data-safety rules (§8) are present and project-specific.
- [ ] Nothing critical lives only in a conversation — the resumability test (§9) passes.
