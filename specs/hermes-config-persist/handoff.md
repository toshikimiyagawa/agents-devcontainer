# Handoff: hermes-config-persist

## Your scope

Implementation phase only. Do not touch `spec.md`, `plan.md`, or the verify phase.
If the spec needs changes, stop and escalate to a human.

Implement issue #44 using the `dotfiles/.hermes` persistence approach. Do not bind mount or import host `~/.hermes`.

## Done when

- [ ] All tasks in `specs/hermes-config-persist/tasks.md` are complete
- [ ] Every acceptance criterion in `specs/hermes-config-persist/spec.md` has a passing test
- [ ] `bats tests/` passes
- [ ] `for f in .devcontainer/scripts/*; do bash -n "$f"; done` passes

## Reference files

- spec: `specs/hermes-config-persist/spec.md`
- plan: `specs/hermes-config-persist/plan.md`
- tasks: `specs/hermes-config-persist/tasks.md`
- detailed implementation plan: `docs/superpowers/plans/2026-06-18-hermes-config-persist.md`
- issue: `https://github.com/toshikimiyagawa/agents-devcontainer/issues/44`

## If the spec is ambiguous or insufficient

1. Stop immediately.
2. Set `.sdd/tasks.json` status to `"blocked"`.
3. Fill in `blocked_reason`.
4. Wait for a human to escalate before resuming.
