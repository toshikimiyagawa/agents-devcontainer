# Handoff: hermes-superpowers-bootstrap

## Your scope

Implementation phase only. Do not touch `spec.md`, `plan.md`, or the verify phase.
If the spec needs changes, stop and escalate to a human.

Implement issue #46 using postCreate bootstrap. Do not bind mount or import host `~/.hermes`.

## Done when

- [ ] All tasks in `specs/hermes-superpowers-bootstrap/tasks.md` are complete
- [ ] Every acceptance criterion in `specs/hermes-superpowers-bootstrap/spec.md` has a passing test
- [ ] `bats tests/` passes
- [ ] `for f in .devcontainer/scripts/*; do bash -n "$f"; done` passes

## Reference files

- spec: `specs/hermes-superpowers-bootstrap/spec.md`
- plan: `specs/hermes-superpowers-bootstrap/plan.md`
- tasks: `specs/hermes-superpowers-bootstrap/tasks.md`
- detailed implementation plan: `docs/superpowers/plans/2026-06-19-hermes-superpowers-bootstrap.md`
- issue: `https://github.com/toshikimiyagawa/agents-devcontainer/issues/46`

## If the spec is ambiguous or insufficient

1. Stop immediately.
2. Set `.sdd/tasks.json` status to `"blocked"`.
3. Fill in `blocked_reason`.
4. Wait for a human to escalate before resuming.
