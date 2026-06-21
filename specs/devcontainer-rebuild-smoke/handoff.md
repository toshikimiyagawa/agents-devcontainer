# Handoff: devcontainer-rebuild-smoke

## Your scope

Implementation phase only. Implement `tasks.md` exactly. Do not modify `spec.md`,
`plan.md`, `.sdd/state.json`, or orchestration rules. Do not run the full smoke from
inside a devcontainer. If frozen artifacts are ambiguous or insufficient, stop and
mark the task blocked instead of redesigning.

## Done when

- [ ] Tasks 1-5 in `specs/devcontainer-rebuild-smoke/tasks.md` are complete
- [ ] Every implementation-phase acceptance criterion has a passing Bats test
- [ ] `bash -n scripts/smoke-devcontainer.sh` passes
- [ ] `bats tests/` passes
- [ ] `.sdd/tasks.json` status is `completed`
- [ ] Implementation is committed and kanban output is reported

The real host rebuild smoke, independent SDD review, CI confirmation, push, and PR are
verify/publish work and require later explicit human instruction.

## Reference files

- spec: `specs/devcontainer-rebuild-smoke/spec.md`
- plan: `specs/devcontainer-rebuild-smoke/plan.md`
- tasks: `specs/devcontainer-rebuild-smoke/tasks.md`
- issue: `https://github.com/toshikimiyagawa/agents-devcontainer/issues/49`

## If the spec is ambiguous or insufficient

1. Stop immediately.
2. Set this feature's `.sdd/tasks.json` status to `"blocked"`.
3. Fill in `blocked_reason` with the concrete mismatch.
4. Display kanban and wait for a human decision.
