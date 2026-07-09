#!/usr/bin/env bats

setup() {
  REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)
  TMP_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TMP_DIR"
}

assert_contains() {
  grep -F -- "$2" "$REPO_ROOT/$1" >/dev/null
}

section() {
  awk -v heading="$2" '$0 == heading { found=1; next }
    found && /^##/ { exit } found { print } END { if (!found) exit 1 }' "$1"
}

assert_text() {
  printf '%s\n' "$1" | tr '\n' ' ' | grep -F -- "$2" >/dev/null
}

must() {
  "$@" || check_failed=1
}

check_workflow() {
  local workflow=$1 tier2 state reverse guard label_count validator check_failed=0
  must grep -Fq 'types: [opened, synchronize, reopened, labeled, unlabeled]' "$workflow"
  must grep -Fq 'src="$(echo "$changed" | grep -vE' "$workflow"
  must grep -Fq "if ! ls specs/*/spec.md" "$workflow"
  must grep -Fq "blocked=\$(jq '[.[] | select(.status==\"blocked\")] | length'" "$workflow"
  must grep -Fq 'select(.phase=="implement" and (.status=="in_progress" or .status=="pending"))' "$workflow"
  must grep -Fq 'run: bats tests/' "$workflow"
  must grep -Fq 'state_tier=$(jq -er' "$workflow"
  must grep -Fq 'state_phase=$(jq -er' "$workflow"
  must grep -Fq 'has_tier2_label=$(jq -r' "$workflow"
  must grep -Fq 'index("sdd:tier-2") != null' "$workflow"
  must grep -Fq 'if [ "$state_tier" != 2 ] && [ "$has_tier2_label" = true ]; then' "$workflow"
  must grep -Fq 'PR Tier label sdd:tier-2 does not match lower-tier state.' "$workflow"
  tier2=$(awk '/if \[ "\$state_tier" = 2 \]; then/ { in_block=1 }
    in_block && /^      - name:/ { exit } in_block { print }' "$workflow")
  must assert_text "$tier2" 'test("^sdd:tier-[012]$")'
  must assert_text "$tier2" 'tier_count=$(printf'
  must assert_text "$tier2" '[ "$tier_count" -ne 1 ]'
  must assert_text "$tier2" 'Tier label must be exactly one recognized sdd:tier-{0,1,2} label'
  must assert_text "$tier2" '[ "$tier" != 2 ]'
  must assert_text "$tier2" 'PR Tier label must be sdd:tier-2 for Tier 2 state.'
  must assert_text "$tier2" 'scripts/check-sdd-contract.sh \'
  must assert_text "$tier2" '--feature "$(jq -r .feature .sdd/state.json)" \'
  must assert_text "$tier2" 'case "$state_phase" in'
  must assert_text "$tier2" 'implement)'
  must assert_text "$tier2" '--mode freeze'
  must assert_text "$tier2" 'verify)'
  must assert_text "$tier2" '--mode verify \'
  must assert_text "$tier2" '--base "${{ github.event.pull_request.base.sha }}" \'
  must assert_text "$tier2" '--expected-tier 2'
  must assert_text "$tier2" 'Tier 2 PR state phase must be implement or verify.'
  state=$(grep -nF 'state_tier=$(jq -er' "$workflow" | cut -d: -f1)
  reverse=$(grep -nF 'if [ "$state_tier" != 2 ] && [ "$has_tier2_label" = true ]; then' "$workflow" | cut -d: -f1)
  guard=$(grep -nF 'if [ "$state_tier" = 2 ]; then' "$workflow" | cut -d: -f1)
  label_count=$(grep -nF 'tier_count=$(printf' "$workflow" | cut -d: -f1)
  validator=$(grep -nF 'case "$state_phase" in' "$workflow" | cut -d: -f1)
  must test "$(grep -cF 'tier_count=$(printf' "$workflow")" -eq 1
  must test "$state" -lt "$reverse"
  must test "$reverse" -lt "$guard"
  must test "$guard" -lt "$label_count"
  must test "$label_count" -lt "$validator"
  [ "$check_failed" -eq 0 ]
}

run_tier_gate() {
  local workflow=$1 state_tier=$2 labels=$3 phase=${4:-verify}
  local root=$TMP_DIR/gate-$state_tier-$phase
  rm -rf "$root"
  mkdir -p "$root/.sdd" "$root/scripts"
  printf '{"feature":"fixture","tier":%s,"phase":"%s"}\n' "$state_tier" "$phase" > "$root/.sdd/state.json"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" > validator-args' > "$root/scripts/check-sdd-contract.sh"
  chmod +x "$root/scripts/check-sdd-contract.sh"
  awk -v labels="$labels" '
    /- name: Tier 2 traceability gate/ { found=1; next }
    found && /run: \|/ { body=1; next }
    body && /^      - name:/ { exit }
    body {
      sub(/^          /, "")
      if (index($0, "${{ toJSON(github.event.pull_request.labels.*.name) }}")) print labels
      else if (index($0, "${{ github.event.pull_request.base.sha }}")) print "        --base \"base-sha\" \\"
      else print
    }' "$workflow" > "$root/gate.sh"
  run bash -e -c 'cd "$1" && bash -e gate.sh' _ "$root"
}

@test "workflow preserves existing gates and adds the Tier 2 validator" {
  workflow="$REPO_ROOT/.github/workflows/sdd-check.yml"
  check_workflow "$workflow"

  sed 's/if \[ "$state_tier" = 2 \]; then/if [ "$state_tier" = 1 ]; then/' "$workflow" > "$TMP_DIR/wrong-condition.yml"
  run check_workflow "$TMP_DIR/wrong-condition.yml"
  [ "$status" -ne 0 ]

  sed 's@case "\$state_phase" in@true # validator moved@' "$workflow" > "$TMP_DIR/moved.yml"
  printf '%s\n' 'scripts/check-sdd-contract.sh --mode verify' >> "$TMP_DIR/moved.yml"
  run check_workflow "$TMP_DIR/moved.yml"
  [ "$status" -ne 0 ]

  sed 's/\[ "$tier_count" -ne 1 \]/[ "$tier_count" -gt 1 ]/' "$workflow" > "$TMP_DIR/missing-label.yml"
  run check_workflow "$TMP_DIR/missing-label.yml"
  [ "$status" -ne 0 ]

  sed 's/\[ "$tier" != 2 \]/[ -z "$tier" ]/' "$workflow" > "$TMP_DIR/wrong-state.yml"
  run check_workflow "$TMP_DIR/wrong-state.yml"
  [ "$status" -ne 0 ]

  awk '{ print } /state_tier=\$\(jq -er/ { print "          tier_count=$(printf outside-tier-2)" }' "$workflow" > "$TMP_DIR/tier01-enforced.yml"
  run check_workflow "$TMP_DIR/tier01-enforced.yml"
  [ "$status" -ne 0 ]

  sed 's/if \[ "$state_tier" != 2 \] && \[ "$has_tier2_label" = true \]; then/if false; then/' "$workflow" > "$TMP_DIR/reverse-mismatch.yml"
  run check_workflow "$TMP_DIR/reverse-mismatch.yml"
  [ "$status" -ne 0 ]

  run_tier_gate "$workflow" 0 '[]'
  [ "$status" -eq 0 ]
  run_tier_gate "$workflow" 0 '["sdd:tier-0"]'
  [ "$status" -eq 0 ]
  run_tier_gate "$workflow" 1 '["sdd:tier-1"]'
  [ "$status" -eq 0 ]
  run_tier_gate "$workflow" 1 '["sdd:tier-2"]'
  [ "$status" -eq 1 ]
  [[ "$output" == *"PR Tier label sdd:tier-2 does not match lower-tier state."* ]]

  run_tier_gate "$workflow" 2 '["sdd:tier-2"]' implement
  [ "$status" -eq 0 ]
  grep -F -- '--mode freeze' "$TMP_DIR/gate-2-implement/validator-args" >/dev/null
  ! grep -F -- '--base' "$TMP_DIR/gate-2-implement/validator-args" >/dev/null

  run_tier_gate "$workflow" 2 '["sdd:tier-2"]' verify
  [ "$status" -eq 0 ]
  grep -F -- '--mode verify' "$TMP_DIR/gate-2-verify/validator-args" >/dev/null
  grep -F -- '--base' "$TMP_DIR/gate-2-verify/validator-args" >/dev/null
}

@test "reviewer compares source meaning and completion evidence" {
  reviewer="$REPO_ROOT/.claude/agents/sdd-reviewer.md"
  source_contract=$(section "$reviewer" "## Source comparison")
  assert_text "$source_contract" "GitHub Issue"
  assert_text "$source_contract" "traceability.json"
  assert_text "$source_contract" "frozen spec"
  assert_text "$source_contract" "validator green is insufficient"
  evidence_contract=$(section "$reviewer" "## Completion evidence")
  assert_text "$evidence_contract" "commands and test counts"
  assert_text "$evidence_contract" "reviewed SHA"
  assert_text "$evidence_contract" "PASS/FAIL"
  assert_text "$evidence_contract" "reviewer identity is not machine-authenticated"
  assert_text "$evidence_contract" "past TDD execution is not machine-authenticated"
}

@test "docs define the practical trust boundary" {
  docs="$REPO_ROOT/docs/development/sdd-traceability.md"
  machine=$(section "$docs" "### Machine guarantees")
  assert_text "$machine" "fixed JSON shape"
  assert_text "$machine" "state and task consistency"
  assert_text "$machine" "changed feature"
  reviewer=$(section "$docs" "### Reviewer responsibilities")
  assert_text "$reviewer" "source GitHub Issue meaning"
  assert_text "$reviewer" "mapped tests actually prove"
  assert_text "$reviewer" "reviewer identity is not machine-authenticated"
  assert_text "$reviewer" "past TDD execution is not machine-authenticated"
  non_goals=$(section "$docs" "### Non-goals")
  assert_text "$non_goals" "JSON Schema interpreter"
  assert_text "$non_goals" "process evidence"
  assert_text "$non_goals" "attestation"
  checklist=$(section "$docs" "## Finite negative checklist")
  for contract in "dependency or PR base failure" "empty, forged, stale, or wrong-HEAD evidence" \
    "hidden pipeline failure" "detached HEAD" "staged or dirty worktree" \
    "malformed, missing, incomplete, or blocked state" "canonical state/tasks schema" \
    "docs, script, or workflow path drift" "untracked or duplicate Issue AC" \
    "missing or orphaned spec AC or task" "missing or duplicate exact Bats declaration" \
    "PR #54 inconsistent-state fixture" "#50/PR #54 owns implementation-specific enforcement"; do
    assert_text "$checklist" "$contract"
  done
}

@test "implementation plan requires RED before GREEN" {
  tasks="$REPO_ROOT/specs/issue-55-sdd-minimal/tasks.md"
  task3=$(awk '/^### TASK-003:/ { found=1 } /^### TASK-004:/ { exit } found { print }' "$tasks")
  red=$(printf '%s\n' "$task3" | grep -n 'policy tests.*RED' | cut -d: -f1)
  implementation=$(printf '%s\n' "$task3" | grep -n 'workflow.*Tier 2 validator' | cut -d: -f1)
  green=$(printf '%s\n' "$task3" | grep -n 'policy tests.*GREEN' | cut -d: -f1)
  [ "$red" -lt "$implementation" ]
  [ "$implementation" -lt "$green" ]
  grep -F '実装reportへcommand/resultを記録' "$REPO_ROOT/specs/issue-55-sdd-minimal/spec.md" >/dev/null
  grep -F '独立reviewerが' "$REPO_ROOT/specs/issue-55-sdd-minimal/spec.md" >/dev/null
}

@test "enforces validator and test size budgets" {
  [ "$(wc -l < "$REPO_ROOT/scripts/check-sdd-contract.sh")" -le 250 ]
  [ "$(wc -l < "$REPO_ROOT/tests/check-sdd-contract.bats")" -le 400 ]
  assert_contains AGENTS.md "250 lines"
  assert_contains AGENTS.md "400 lines"
  assert_contains docs/development/sdd-traceability.md "250 lines"
  assert_contains docs/development/sdd-traceability.md "400 lines"
}

@test "vendored SDD guide remains unchanged" {
  grep -A4 -F 'uses: actions/checkout@v4' "$REPO_ROOT/.github/workflows/test.yml" |
    grep -F 'fetch-depth: 0' >/dev/null
  git -C "$REPO_ROOT" diff --quiet --submodule=short origin/main...HEAD -- vendor/ai-sdd-guide
  git -C "$REPO_ROOT" diff --quiet --submodule=short -- vendor/ai-sdd-guide
}
