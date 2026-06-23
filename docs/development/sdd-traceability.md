# Tier 2 SDD traceability

Tier 2 work adds `specs/<feature>/traceability.json` to the frozen `spec.md`,
`plan.md`, and `tasks.md`. Use unique `ISSUE-AC-NNN`, `AC-NNN`, and `TASK-NNN`
identifiers so every implemented Issue criterion maps to at least one spec AC, task,
and exact Bats declaration. A deferred criterion instead needs a non-empty reason and
an HTTPS GitHub follow-up Issue, with no implementation mapping.

Run the repository contract at both boundaries:

```bash
scripts/check-sdd-contract.sh --feature <feature> --mode freeze
scripts/check-sdd-contract.sh --feature <feature> --mode verify \
  --base <pull-request-base-sha> --expected-tier 2
```

Required data, dependencies, JSON parsing, Git base resolution, and consistency
checks fail closed. CI preserves the existing spec, blocked-task,
implement-handoff, and full-Bats gates and adds verify validation only for Tier 2.

## Practical trust boundary

### Machine guarantees

Machine-checked guarantees cover the fixed JSON shape, unique references, frozen
spec/task IDs, state and task consistency, exact test declarations, changed feature,
PR base, and Tier. The validator remains at most 250 lines and its focused Bats file
at most 400 lines.

### Reviewer responsibilities

Independent review compares the source GitHub Issue meaning with traceability and
the frozen spec, reads whether mapped tests actually prove each criterion, judges
scope exclusions and follow-up Issues, and checks completion evidence, commands,
counts, and reviewed SHA. Validator green is insufficient for those judgments. The
reviewer identity is not machine-authenticated. Also, past TDD execution is not machine-authenticated;
the reviewer evaluates available reports, commits, and test results without treating
local assertions as proof.

### Non-goals

This design does not add a JSON Schema interpreter, process evidence, attestation,
or a dedicated Bats wrapper. It does not modify the vendored SDD guide or PR #54
implementation files.

## Finite negative checklist

The focused suite must reject each of these cases:

- dependency or PR base failure: the validator fails closed
- empty, forged, stale, or wrong-HEAD evidence: independent review rejects it;
  #50/PR #54 owns implementation-specific enforcement
- hidden pipeline failure: the existing full-Bats and workflow gates fail closed
- detached HEAD: independent review rejects unverifiable completion evidence;
  #50/PR #54 owns implementation-specific enforcement
- staged or dirty worktree: independent review reports it;
  #50/PR #54 owns implementation-specific enforcement
- malformed, missing, incomplete, or blocked state: validator/orchestration gates reject it
- canonical state/tasks schema violations: the validator rejects unknown fields,
  invalid values and types, and missing required fields
- docs, script, or workflow path drift: policy tests reject it
- malformed or multi-value traceability JSON: the validator rejects it
- untracked or duplicate Issue AC: the validator rejects it
- incomplete implemented mapping or invalid follow-up: the validator rejects it
- missing or orphaned spec AC or task: the validator rejects it
- missing or duplicate exact Bats declaration: the validator rejects it
- unavailable base, changed-feature, state-feature, or expected-Tier mismatch:
  the validator/workflow gate rejects it
- PR #54 inconsistent-state fixture: focused regression coverage rejects both
  orphaned source requirements and state/task inconsistency

Before handoff, run focused and full Bats, shell syntax checks, both line budgets,
the `CLAUDE.md` symlink check, the vendor diff check, and `git diff --check`.
