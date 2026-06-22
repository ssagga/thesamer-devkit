# Agent-Driven Development System — Build Specification

**Status:** Specification for implementation
**Audience:** An AI coding agent tasked with building this system as a reusable scaffold
**Scope:** Project-agnostic. Designed for small-to-medium web/app projects developed
incrementally by a single human working with AI agents over many sessions.

---

## 0. What you are building

You are not building a feature. You are building a **development operating system** —
a reusable set of files, conventions, and agent roles that can be dropped into any
project so that a human can develop it continuously with AI agents **without** the work
degrading as conversations grow, compact, or end.

The deliverable is a **portable scaffold**: a small set of template files plus a setup
routine (a script, slash-command, or skill) that initializes the system in any repo.
It must work the same on project #1 and project #20.

Treat this document as the source of truth. Where it says "the system must," that is a
requirement. Where it says "recommended," that is a sensible default the human may override.

---

## 1. The problem this solves

Sustained development with an AI agent fails in predictable ways:

1. **Context amnesia.** Every new conversation starts blind and re-derives the project by
   reading files, which itself burns the context budget.
2. **Compaction loss.** Long sessions get summarized; nuance, decisions, and half-finished
   intent are lost mid-task.
3. **Monolithic conversations.** One chat tries to explore, plan, implement, review, and
   deploy — bloating context and entangling unrelated changes.
4. **Top-model-for-everything.** The most expensive model runs trivial mechanical work,
   wasting budget and latency.
5. **Irreversible drift.** Changes land directly on the live branch with no review gate or
   clean revert.
6. **Doc rot.** Documentation, if it exists, goes stale and starts actively misleading.

The system below neutralizes each of these.

---

## 2. Core principles

These are the non-negotiable foundations. Everything else derives from them.

### P1 — The repo is the memory; the conversation is disposable.
Anything that must survive a session gets written to a file **in the repo** before the
session ends. A conversation is a scratchpad, not a database. Design every workflow so
that if the chat vanished right now, the next agent could pick up from files alone.

### P2 — One unit of work = one conversation = one branch.
Features do not share conversations. This keeps context scoped, diffs clean, and reverts
atomic.

### P3 — Documentation currency is part of "done."
A feature is not complete until the always-loaded brief, the roadmap, and (if relevant) the
decision log reflect reality. Stale docs are a defect, fixed in the same PR.

### P4 — Match the model to the task, not to the default.
The main loop should not run the top-tier model on mechanical work. Delegate by cost/skill
(see §6).

### P5 — Separate concerns across agents.
Exploring, planning, implementing, and reviewing are distinct roles with distinct context
needs. Delegate them so the orchestrating thread stays lean (see §5).

### P6 — Every change is reversible and reviewable.
No work reaches the live environment without a diff a human approved and a one-action revert
path (see §7).

---

## 3. Required artifacts (the file system of the system)

The scaffold installs these files into a target repo. Paths are recommendations; names in
**bold** are load-bearing.

| File | Purpose | Lifecycle |
|------|---------|-----------|
| **`CLAUDE.md`** (root) | The always-loaded project brief. Architecture, conventions, commands, deploy model, data-safety rules, and "how we work." Kept lean (~100–150 lines), pointing to detail rather than inlining it. | Updated at the end of any feature that changes architecture or conventions. |
| **`docs/roadmap.md`** | The backlog. Features with status (`idea` / `speced` / `in-progress` / `shipped`). "What's next" lives here, never only in a chat. | Updated when work is queued, started, or shipped. |
| **`docs/decisions/`** | Append-only decision log (lightweight ADRs). One short file per non-obvious choice: context, decision, why, consequences. | Appended whenever a meaningful trade-off is made. Never rewritten. |
| **`docs/features/<name>.md`** | Per-feature spec for substantial work. Goal, scope, non-goals, approach, data/schema impact, test/verify plan. Written **before** building. | Created at planning; reflects what was actually built by merge time. |
| **`docs/features/_template.md`** | The blank spec template. | Static. |
| **`.claude/agents/*`** | Custom agent role definitions (see §5), if the platform supports them. | Updated as roles evolve. |
| **Setup routine** | A script / slash-command / skill that scaffolds all of the above into a fresh repo and fills what it can infer. | The portable entry point. |

> **Platform note:** `CLAUDE.md` and `.claude/agents/` are Claude Code conventions. On other
> agent platforms, substitute the equivalent always-loaded context file and agent-definition
> mechanism. The *principle* (one lean always-loaded brief + role-scoped sub-agents) is
> portable; the filenames are not.

---

## 4. The feature lifecycle

Every unit of work flows through this. Ceremony scales with size (§4.3).

### 4.1 Standard flow

```
1. ORIENT   New conversation. The always-loaded brief (CLAUDE.md) is already in context.
            Read roadmap + relevant feature spec if resuming. Do NOT re-explore the
            whole repo — delegate any needed search to an Explorer sub-agent (§5).

2. SPEC     For substantial work: write docs/features/<name>.md from the template.
            Get human sign-off on the spec before writing code.

3. BRANCH   Create feat/<name> from the integration branch. Never work on the live branch.

4. BUILD    Implement on the branch. Delegate sub-tasks by model tier (§6).
            Keep the orchestrating context lean — push file-heavy work to sub-agents.

5. VERIFY   Run the build. Run/observe the app. Run the review pass (adversarial diff
            review). Fix findings.

6. DOCUMENT Update CLAUDE.md (if architecture/conventions changed), roadmap status,
            and append a decision-log entry if a real trade-off was made. Same PR.

7. PR       Open a pull request into the integration branch. Human reviews the diff.

8. MERGE    Human approves & merges. Branch deleted.

9. RELEASE  Promote integration → live as a deliberate, separate gate (batch or per-feature).
```

### 4.2 Definition of Done
A feature is done only when **all** hold:
- [ ] Build passes.
- [ ] App was actually run/observed to confirm the change works (not just "the diff looks right").
- [ ] Adversarial review pass completed; findings resolved or consciously deferred.
- [ ] `CLAUDE.md` accurate (updated if needed).
- [ ] `docs/roadmap.md` status updated.
- [ ] Decision-log entry appended if a non-obvious choice was made.
- [ ] Feature spec reflects what was actually built.
- [ ] PR merged; live promotion is a separate, deliberate action.

### 4.3 Ceremony tiers
- **Trivial** (copy edit, style tweak, isolated bug fix): branch → PR → merge. No spec, no decision log.
- **Substantial** (new page/route, schema change, new capability, anything touching data or auth):
  full lifecycle including a spec doc written first.
- The line: *does this change data shape, public behavior, or an architectural assumption?*
  If yes → substantial.

---

## 5. Separation of concerns — the agent roles

The orchestrating conversation (the "main loop") **coordinates**; it does not personally do
everything. It delegates to scoped sub-agents whose context is thrown away when they return,
keeping the main thread lean. Define these roles (as custom agents where supported, or as
delegation patterns otherwise):

| Role | Mandate | Returns | Holds context? |
|------|---------|---------|----------------|
| **Orchestrator** (main loop) | Owns the thread and the plan. Delegates, integrates results, talks to the human, keeps docs current. | The conversation. | Yes — keep it lean. |
| **Explorer** | Read-only search across the codebase. Locates code, maps conventions. | Conclusions and file references — **not** raw file dumps. | No (disposable). |
| **Planner / Architect** | Designs an approach for a substantial feature. Weighs trade-offs. | A plan or draft spec. | No. |
| **Implementer** | Writes code for a well-scoped sub-task on the branch. | A diff / summary of changes. | No. |
| **Reviewer** | Adversarially reviews a diff for correctness, security, and regressions. Tries to *refute* that the change is correct. | A verdict + findings. | No. |

**The rule that makes this work:** file-heavy and search-heavy work goes to Explorer/
Implementer sub-agents so their token noise never enters the orchestrator's context — only
distilled conclusions come back. This is the single biggest lever against context bloat.

For larger efforts (audits, migrations, broad refactors), the orchestrator may run a
**multi-agent workflow**: fan out finders/implementers in parallel, then verify each result
with independent reviewers before integrating. Use this only when the work genuinely exceeds
one context or benefits from parallel independent perspectives — not for routine features.

---

## 6. Model-tier delegation

Do not default to the top model for every action. Route by the nature of the task. Use a
three-tier mental model (current Claude tiers named for reference; substitute equivalents on
other platforms):

| Tier | Use for | Examples | Current model |
|------|---------|----------|---------------|
| **Cheap / fast** | Mechanical, well-specified, low-judgment work. | Renames, boilerplate, formatting, log/grep scanning, simple file edits, status updates. | Haiku |
| **Mid** | The bulk of implementation. Standard features with a clear spec. | Building a CRUD form, wiring a component, routine refactors, writing tests. | Sonnet |
| **Top** | High-judgment, ambiguous, or high-blast-radius work. | Architecture, schema/migration design, tricky debugging, security-sensitive logic, final adversarial review, resolving conflicting requirements. | Opus |

**Routing heuristics:**
- The orchestrator runs at **mid or top**; it delegates *down* for mechanical sub-tasks.
- Cost scales with blast radius: anything touching **data, auth, money, or the live branch**
  gets top-tier judgment, especially on review.
- Reasoning effort is a second dial: raise it for the hardest verify/design steps, lower it
  for cheap mechanical passes.
- When unsure, the default is mid — escalate to top only with a reason.

On Claude Code this maps to the `model` (and `effort`) parameters on the Agent and Workflow
tools. The orchestrator sets the tier per delegated task rather than running one model for
the whole session.

---

## 7. Reversibility and review

### Branch model
```
feat/<name>  →  PR  →  integration branch (CI validates)  →  human approves & merges
                                  ↓  (deliberate release gate)
                        integration → live branch  →  deploys
```
- **Never** commit to the live/deploying branch directly.
- The integration branch is the staging truth; promoting to live is a conscious act, not a
  side effect of a commit.
- Every feature is one PR — a clean diff to read and a one-click revert.

### Review gates (standing, automated where possible)
- **CI on the integration branch** validates that the build passes before merge is allowed.
- **An adversarial review pass** runs before every PR (a Reviewer sub-agent, or a review
  command). It defaults to skepticism: assume the change is wrong until shown otherwise.
- **Human approval** is the final gate. For a solo developer the PR is not about consensus —
  it is the reversible, readable record and the approval moment.

### Seeing changes before they ship
A visual/product project needs a way to *see* a change before it's live. In order of cost:
1. **Local preview** — the agent runs the app and provides screenshots/observations per change.
2. **Staging deploy** — a second environment tracking the integration branch, so "approve"
   means looking at the real thing on a real URL.
Pick the cheapest that gives enough confidence; escalate only if reviewing-by-diff keeps
missing things.

---

## 8. Data safety (generalized migration discipline)

The most genuinely irreversible risk in agent-driven development is **data loss on a live
store**. Wherever a project has persistent state (a database, a volume, user uploads):

- **Additive-only by default.** New columns/tables are added with `IF NOT EXISTS`, nullable
  or with defaults. Never drop or rename in the same change that ships.
- **Versioned, forward-only migrations** that run deterministically on boot/deploy.
- **Back up the live store before any schema change reaches production.** This is a hard rule
  in `CLAUDE.md`, not a best-effort.
- **Destructive changes are a two-step ritual:** ship the additive change, migrate data, and
  only remove the old shape in a later, separate, explicitly-approved change.

State this discipline in the target project's `CLAUDE.md` with the project's specific store.

---

## 9. Conversation-agnostic practices (context hygiene)

These habits keep the system resilient to compaction and session boundaries:

- **Resumability test:** at any moment, ask "if this chat died now, could a fresh agent
  continue from the branch + spec + roadmap alone?" If no, write the missing state to a file.
- **`/clear` (or new session) between features** so context resets and the brief reloads clean.
- **Delegate to keep the thread lean** — never read ten files into the main context when an
  Explorer can return the three relevant lines.
- **Write decisions down as they happen**, not at the end when they've been forgotten.
- **Keep the brief lean.** `CLAUDE.md` points to detail; it does not inline it. A bloated
  brief defeats its own purpose.
- **Chapter long sessions** into coherent phases (explore → plan → build → verify) so the
  structure survives summarization.

---

## 10. What the receiving agent should build

Concrete implementation order for the scaffold:

1. **Template files.** Author `CLAUDE.md` (with placeholders), `docs/roadmap.md`,
   `docs/decisions/` with a seed ADR explaining the system itself, `docs/features/_template.md`.
2. **Setup routine.** A single command/script/skill that, run in any repo:
   - detects stack, deploy model, and persistent stores by inspecting the project;
   - generates a filled-in `CLAUDE.md` draft for human review;
   - creates the docs tree and the integration/live branch convention if absent;
   - prints a short "how we work here" summary.
3. **Agent role definitions** for Explorer, Planner, Implementer, Reviewer (where the platform
   supports custom agents), each with the model-tier defaults from §6.
4. **Review + verify hooks.** A standing pre-PR adversarial review step and a build-validation
   CI gate on the integration branch.
5. **A "definition of done" checklist** (§4.2) embedded where the agent will see it each
   feature (e.g. in `CLAUDE.md` or a PR template).
6. **Documentation** of the system itself, so a human onboarding to a new project understands
   the workflow in five minutes.

### Acceptance criteria for the scaffold
- [ ] Can be installed into a fresh repo in one step.
- [ ] After install, a new conversation has the project brief loaded automatically.
- [ ] The feature lifecycle (§4) is documented where the agent will follow it.
- [ ] Model-tier routing (§6) is encoded in the agent role defaults, not left to chance.
- [ ] No path exists for a change to reach the live branch without a reviewable diff.
- [ ] Data-safety rules (§8) are present and project-specific.
- [ ] Nothing critical lives only in a conversation — the resumability test (§9) passes.

---

## 11. Anti-patterns to reject

- One mega-conversation that builds several features. → Split per feature.
- Re-exploring the whole codebase at the start of every session. → That's what the brief and
  Explorer sub-agents are for.
- Running the top model on formatting and renames. → Route down (§6).
- Committing straight to the deploying branch "just this once." → No exceptions.
- Updating docs "later." → Later never comes; it's part of done.
- A 600-line `CLAUDE.md`. → It must stay lean to stay loaded and read.
- Dropping/renaming columns in a feature change. → Additive-only; destructive changes are a
  separate ritual.

---

*End of specification. An implementing agent should treat §10 as the build backlog and §4.2 /
§10 acceptance criteria as the definition of done for the scaffold itself.*

---

## Appendix A — Companion files

- **`CLAUDE.template.md`** (sibling of this spec) — a lean, copy-verbatim `CLAUDE.md` template
  the receiving agent installs into each target repo and fills in. It embodies §3–§9 in the
  form the agent will actually load every session. Treat it as the canonical starting brief.
