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

Machine-checked guarantees cover the fixed JSON shape, unique references, frozen
spec/task IDs, state and task consistency, exact test declarations, changed feature,
PR base, and Tier. The validator remains at most 250 lines and its focused Bats file
at most 400 lines.

Independent review compares the source GitHub Issue meaning with traceability and
the frozen spec, reads whether mapped tests actually prove each criterion, judges
scope exclusions and follow-up Issues, and checks completion evidence, commands,
counts, and reviewed SHA. Validator green is insufficient for those judgments. The
reviewer identity is not machine-authenticated. Also, past TDD execution is not machine-authenticated;
the reviewer evaluates available reports, commits, and test results without treating
local assertions as proof.

This design does not add a JSON Schema interpreter, process evidence, attestation,
or a dedicated Bats wrapper. It does not modify the vendored SDD guide or PR #54
implementation files.

## Finite negative checklist

The focused suite must reject each of these cases:

- malformed or multi-value JSON
- untracked or duplicate Issue AC
- incomplete implemented mapping
- invalid follow-up reason or Issue URL
- missing or orphaned spec AC or task
- state feature, tier, or phase mismatch
- missing, duplicate, blocked, incomplete, or noncanonical task state
- missing or duplicate exact Bats declaration
- unavailable base or feature mismatch
- expected Tier mismatch
- PR #54 inconsistent-state fixture

Before handoff, run focused and full Bats, shell syntax checks, both line budgets,
the `CLAUDE.md` symlink check, the vendor diff check, and `git diff --check`.
