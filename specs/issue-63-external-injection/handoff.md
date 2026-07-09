# Handoff: issue-63-external-injection

## Your scope

Implementation phase only. Do not touch `spec.md`, `plan.md`, or the verify phase.
If the spec needs changes, stop and escalate to a human.

Implement the external-injection path for #63:

- Dev Container Feature skeleton for agents tooling
- `adc up` wrapper for CLI injection
- documentation for VS Code `Reopen in Container` and CLI usage
- tests proving the acceptance criteria

## Done when

- [ ] All tasks in `specs/issue-63-external-injection/tasks.md` are complete
- [ ] Every acceptance criterion in `specs/issue-63-external-injection/spec.md` has a passing test
- [ ] Existing scaffold and merge tests still pass
- [ ] Test suite relevant to this feature passes

## Reference files

- spec:  `specs/issue-63-external-injection/spec.md`
- plan:  `specs/issue-63-external-injection/plan.md`
- tasks: `specs/issue-63-external-injection/tasks.md`

## If the spec is ambiguous or insufficient

1. Stop immediately.
2. Set `.sdd/tasks.json` status to `"blocked"`.
3. Fill in `blocked_reason`.
4. Wait for a human to escalate before resuming.

