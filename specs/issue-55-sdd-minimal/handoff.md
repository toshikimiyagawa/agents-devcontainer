# Handoff: issue-55-sdd-minimal

## Your scope

Implementation phase only. Do not touch `spec.md`, `plan.md`, `tasks.md`,
`traceability.json`, `.sdd/state.json`, or the verify phase. Do not copy code
from `feat/issue-55-sdd-traceability`.

## Done when

- [ ] All tasks in `specs/issue-55-sdd-minimal/tasks.md` are complete
- [ ] Every acceptance criterion has the mapped passing test
- [ ] Full Bats and shell syntax checks pass
- [ ] Validator and focused tests remain within the frozen size budgets

## Reference files

- spec: `specs/issue-55-sdd-minimal/spec.md`
- plan: `specs/issue-55-sdd-minimal/plan.md`
- tasks: `specs/issue-55-sdd-minimal/tasks.md`
- traceability: `specs/issue-55-sdd-minimal/traceability.json`
- design: `docs/superpowers/specs/2026-06-24-issue-55-sdd-minimal-design.md`

## If the spec is ambiguous or insufficient

1. Stop immediately.
2. Set this feature's `.sdd/tasks.json` status to `blocked`.
3. Fill in `blocked_reason` with the affected AC and ambiguity.
4. Wait for a human decision before resuming.
