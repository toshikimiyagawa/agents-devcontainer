#!/usr/bin/env bash

set -u

usage() { printf 'usage: %s --feature SLUG --mode freeze|verify [--base COMMIT --expected-tier 2]\n' "$0" >&2; exit 2; }
fail() { printf '[sdd-contract] ERROR: %s\n' "$*" >&2; exit 1; }

feature=
mode=
base=
expected_tier=
seen_feature=0
seen_mode=0
seen_base=0
seen_tier=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --feature)
      [ "$seen_feature" -eq 0 ] && [ "$#" -ge 2 ] || usage
      feature=$2; seen_feature=1; shift 2 ;;
    --mode)
      [ "$seen_mode" -eq 0 ] && [ "$#" -ge 2 ] || usage
      mode=$2; seen_mode=1; shift 2 ;;
    --base)
      [ "$seen_base" -eq 0 ] && [ "$#" -ge 2 ] || usage
      base=$2; seen_base=1; shift 2 ;;
    --expected-tier)
      [ "$seen_tier" -eq 0 ] && [ "$#" -ge 2 ] || usage
      expected_tier=$2; seen_tier=1; shift 2 ;;
    *) usage ;;
  esac
done
[ "$seen_feature" -eq 1 ] && [ "$seen_mode" -eq 1 ] || usage
case "$feature" in ''|*[!a-z0-9-]*|-*|*-) usage ;; esac
case "$mode" in
  freeze) [ "$seen_base" -eq 0 ] && [ "$seen_tier" -eq 0 ] || usage ;;
  verify) [ "$seen_base" -eq 1 ] && [ "$seen_tier" -eq 1 ] || usage ;;
  *) usage ;;
esac

REPO_ROOT=${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd -P)}
REPO_ROOT=$(cd "$REPO_ROOT" 2>/dev/null && pwd -P) || fail "repository root unavailable"
GIT_BIN=${GIT_BIN:-git}
JQ_BIN=${JQ_BIN:-jq}
command -v "$GIT_BIN" >/dev/null 2>&1 || fail "git dependency unavailable"
command -v "$JQ_BIN" >/dev/null 2>&1 || fail "jq dependency unavailable"
feature_dir=$REPO_ROOT/specs/$feature
spec=$feature_dir/spec.md
plan=$feature_dir/plan.md
tasks=$feature_dir/tasks.md
trace=$feature_dir/traceability.json
for artifact in "$spec" "$plan" "$tasks" "$trace"; do
  [ -f "$artifact" ] || fail "required artifact missing: ${artifact##*/}"
done

json_single() {
  [ -f "$1" ] || fail "required JSON artifact missing: ${1##*/}"
  "$JQ_BIN" -s -e 'length == 1' "$1" >/dev/null 2>&1 ||
    fail "${1##*/} must contain a single JSON value"
}

json_single "$trace"
trace_error=$("$JQ_BIN" -r '
  def exact($x): (keys | sort) == ($x | sort);
  def nonempty: type == "string" and length > 0;
  def is_unique: length == (unique | length);
  if type != "object" or (exact(["source","criteria"]) | not)
     or (.source | type != "object" or (exact(["url"]) | not))
     or (.source.url | type != "string" or (test("^https://github\\.com/[^/]+/[^/]+/issues/[1-9][0-9]*$") | not))
     or (.criteria | type != "array") then "traceability.json contract"
  elif (.criteria | length) == 0 then "Issue criteria are required"
  elif ([.criteria[].issue_ac] | is_unique | not) then "duplicate Issue criterion"
  elif any(.criteria[]; (.issue_ac | type != "string" or (test("^ISSUE-AC-[0-9]{3}$") | not)) or (.text | nonempty | not)) then "traceability.json criterion"
  elif any(.criteria[]; .disposition != "implemented" and .disposition != "follow_up") then "traceability.json disposition"
  elif any(.criteria[] | select(.disposition == "implemented");
       (exact(["issue_ac","text","disposition","spec_acs","tasks","tests"]) | not)
       or (.spec_acs | type != "array" or length == 0 or (is_unique | not) or any(.[]; type != "string" or (test("^AC-[0-9]{3}$") | not)))
       or (.tasks | type != "array" or length == 0 or (is_unique | not) or any(.[]; type != "string" or (test("^TASK-[0-9]{3}$") | not)))
       or (.tests | type != "array" or length == 0 or (is_unique | not)
           or any(.[]; type != "object" or (exact(["file","name"]) | not)
             or (.file | type != "string" or (test("^tests/(?!.*(?:^|/)\\.\\.(?:/|$))[^/].*\\.bats$") | not))
             or (.name | nonempty | not)))) then "implemented mapping"
  elif any(.criteria[] | select(.disposition == "follow_up");
       (.follow_up | type != "string" or (test("^https://github\\.com/[^/]+/[^/]+/issues/[1-9][0-9]*$") | not))) then "follow_up GitHub Issue URL"
  elif any(.criteria[] | select(.disposition == "follow_up");
       (exact(["issue_ac","text","disposition","reason","follow_up"]) | not) or (.reason | nonempty | not)) then "follow_up mapping"
  else "" end
' "$trace") || fail "traceability.json parse failure"
[ -z "$trace_error" ] || fail "$trace_error"

extract_spec_ids() {
  sed -n 's/^- \[[ x]\] \(AC-[0-9][0-9][0-9]\): .*/\1/p' "$spec"
}
extract_task_ids() {
  sed -n 's/^### \(TASK-[0-9][0-9][0-9]\): .*/\1/p' "$tasks"
}
mapped_spec=$("$JQ_BIN" -r '[.criteria[] | select(.disposition == "implemented") | .spec_acs[]] | unique[]' "$trace") || fail "spec AC mapping"
mapped_tasks=$("$JQ_BIN" -r '[.criteria[] | select(.disposition == "implemented") | .tasks[]] | unique[]' "$trace") || fail "task mapping"
spec_ids_raw=$(extract_spec_ids)
task_ids_raw=$(extract_task_ids)
[ -z "$(printf '%s\n' "$spec_ids_raw" | sort | awk 'seen[$0]++ { print; exit }')" ] || fail "duplicate spec AC definition"
[ -z "$(printf '%s\n' "$task_ids_raw" | sort | awk 'seen[$0]++ { print; exit }')" ] || fail "duplicate task definition"
spec_ids=$(printf '%s\n' "$spec_ids_raw" | sort -u)
task_ids=$(printf '%s\n' "$task_ids_raw" | sort -u)
[ -n "$spec_ids" ] || fail "spec AC definitions missing"
[ -n "$task_ids" ] || fail "task definitions missing"
if [ "$(printf '%s\n' "$mapped_spec" | sort -u)" != "$spec_ids" ]; then
  while IFS= read -r id; do
    printf '%s\n' "$spec_ids" | grep -qx "$id" || fail "unknown spec AC reference: $id"
  done <<EOF
$mapped_spec
EOF
  fail "orphaned spec AC"
fi
if [ "$(printf '%s\n' "$mapped_tasks" | sort -u)" != "$task_ids" ]; then
  while IFS= read -r id; do
    printf '%s\n' "$task_ids" | grep -qx "$id" || fail "unknown task reference: $id"
  done <<EOF
$mapped_tasks
EOF
  fail "orphaned task"
fi
[ "$mode" = freeze ] && exit 0

state=$REPO_ROOT/.sdd/state.json
task_state=$REPO_ROOT/.sdd/tasks.json
json_single "$state"
"$JQ_BIN" -e '
  def allowed: ["feature","tier","phase","spec","note"];
  type == "object" and has("tier") and has("phase") and has("feature")
  and all(keys[]; IN(allowed[]))
  and (.feature | type == "string" and test("^[a-z0-9][a-z0-9-]*$"))
  and (.tier | type == "number" and floor == . and IN(0,1,2))
  and (.phase | type == "string" and IN("brainstorm","spec","plan","tasks","implement","verify","done"))
  and ((has("spec") | not) or (.spec | type == "string"))
  and ((has("note") | not) or (.note | type == "string"))
' "$state" >/dev/null || fail "state.json shape"
state_feature=$("$JQ_BIN" -r .feature "$state")
state_tier=$("$JQ_BIN" -r .tier "$state")
state_phase=$("$JQ_BIN" -r .phase "$state")
[ "$state_feature" = "$feature" ] || fail "state feature mismatch"
[ "$state_tier" = 2 ] || fail "state tier must be 2"
[ "$state_phase" = verify ] || fail "state phase must be verify"

json_single "$task_state"
"$JQ_BIN" -e '
  def allowed: ["id","phase","status","assigned_agent","handoff","blocked_reason"];
  type == "array" and all(.[]; type == "object"
    and has("id") and has("phase") and has("status") and all(keys[]; IN(allowed[]))
    and (.id | type == "string" and test("^[a-z0-9][a-z0-9-]*$"))
    and (.phase | type == "string" and IN("brainstorm","spec","plan","tasks","implement","verify","done"))
    and (.status | type == "string" and IN("pending","in_progress","completed","blocked"))
    and ((has("assigned_agent") | not) or (.assigned_agent | IN("claude","codex","gemini",null)))
    and ((has("handoff") | not) or (.handoff == null or (.handoff | type == "string")))
    and ((has("blocked_reason") | not) or (.blocked_reason == null or (.blocked_reason | type == "string"))))
' "$task_state" >/dev/null || fail "canonical tasks.json"
task_count=$("$JQ_BIN" --arg feature "$feature" '[.[] | select(.id == $feature)] | length' "$task_state")
[ "$task_count" -gt 0 ] || fail "feature task missing"
[ "$task_count" -eq 1 ] || fail "duplicate feature task"
[ "$("$JQ_BIN" -r --arg feature "$feature" '.[] | select(.id == $feature) | .phase' "$task_state")" = verify ] || fail "feature task phase"
[ "$("$JQ_BIN" -r --arg feature "$feature" '.[] | select(.id == $feature) | .status' "$task_state")" = completed ] || fail "feature status must be completed"
[ "$("$JQ_BIN" '[.[] | select(.status == "blocked")] | length' "$task_state")" -eq 0 ] || fail "blocked task exists"

"$JQ_BIN" -r '.criteria[] | select(.disposition == "implemented") | .tests[] | [.file,.name] | @tsv' "$trace" |
while IFS="$(printf '\t')" read -r file name; do
  test_path=$REPO_ROOT/$file
  [ ! -L "$test_path" ] && [ -f "$test_path" ] || fail "test file is missing or not regular: $file"
  parent=$(cd -P "$(dirname "$test_path")" 2>/dev/null && pwd -P) || fail "test file parent unavailable: $file"
  case "$parent/" in "$REPO_ROOT"/*) ;; *) fail "test file escapes repository: $file" ;; esac
  target='@test "'"$name"'" {'
  count=$(awk -v target="$target" '{ line=$0; sub(/^[[:space:]]*/, "", line); sub(/[[:space:]]*$/, "", line); if (line == target) n++ } END { print n+0 }' "$test_path") || fail "cannot read test file: $file"
  [ "$count" -eq 1 ] || fail "Bats declaration must appear exactly once: $name"
done || exit 1

"$GIT_BIN" -C "$REPO_ROOT" rev-parse --verify "$base^{commit}" >/dev/null 2>&1 || fail "base commit unavailable"
diff_file=$(mktemp "${TMPDIR:-/tmp}/sdd-contract.XXXXXX") || fail "cannot create temporary file"
trap 'rm -f "$diff_file"' EXIT HUP INT TERM
"$GIT_BIN" -C "$REPO_ROOT" diff --name-only -z "$base"...HEAD -- specs > "$diff_file" || fail "base diff failed"
changed_features=
while IFS= read -r -d '' path; do
  case "$path" in
    specs/*/*) changed=${path#specs/}; changed=${changed%%/*} ;;
    *) fail "changed feature path is invalid: $path" ;;
  esac
  case " $changed_features " in *" $changed "*) ;; *) changed_features="$changed_features $changed" ;; esac
done < "$diff_file"
changed_features=${changed_features# }
[ "$changed_features" = "$feature" ] || fail "changed feature mismatch"
[ "$state_feature" = "$feature" ] || fail "state feature mismatch"
[ "$expected_tier" = "$state_tier" ] || fail "expected tier mismatch"
