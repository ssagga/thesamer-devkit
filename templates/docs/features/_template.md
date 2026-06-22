# Feature: <name>

**Status:** draft · in-progress · shipped
**Branch:** `feat/<name>`
**Owner:** <human / agent>
**Spec written:** <YYYY-MM-DD>

> Write this BEFORE building (for substantial work). By merge time, edit it to reflect what was
> actually built — a spec that lies about the result is worse than none.

## Goal

<One or two sentences: what this enables and for whom. The "why now."">

## Scope

- <In: the concrete things this change includes.>
- <In: …>

## Non-goals

- <Out: things deliberately not done here, to keep the diff atomic.>
- <Out: …>

## Approach

<The plan. Key files/areas touched, the shape of the solution, notable trade-offs. Link any
decision-log entry. Keep it short — this is a map, not an essay.>

## Data / schema impact <!-- delete if none -->

- Store: <db / volume / uploads>.
- Change: <new column/table/migration — additive-only? backup needed before live?>.
- Migration: <forward-only, runs on boot/deploy? destructive step deferred to a later change?>.

## Test / verify plan

- [ ] Build passes.
- [ ] <How the change is actually run & observed — preview URL, screenshot, manual steps.>
- [ ] <Specific scenarios to check, including edge cases.>
- [ ] Adversarial review pass; findings resolved or consciously deferred.

## Notes / open questions

- <Anything unresolved, deferred, or worth flagging to the human.>
