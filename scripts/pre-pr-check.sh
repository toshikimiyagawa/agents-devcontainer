#!/usr/bin/env bash
set -euo pipefail

# Pre-PR gate. All checks are fail-closed: any error or unverifiable state exits non-zero.

BATS_BIN="${BATS_BIN:-bats}"
GIT_BIN="${GIT_BIN:-git}"
JQ_BIN="${JQ_BIN:-jq}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PATHS_FILE="${PATHS_FILE:-$SCRIPT_DIR/devcontainer-paths.txt}"

fail() { printf '[pre-pr-check] ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '[pre-pr-check] %s\n' "$*"; }

# 1. branch must be a feature branch (not main/master, not detached)
branch="$("$GIT_BIN" -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)" \
  || fail "cannot determine current branch"
if [ "$branch" = "HEAD" ]; then
  fail "detached HEAD. Check out a named feature branch first."
fi
if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  fail "on $branch branch. Create a feature branch first."
fi
info "branch: $branch ✓"

# 2. working tree must be clean (no staged / unstaged / untracked changes)
worktree_status="$("$GIT_BIN" -C "$REPO_ROOT" status --porcelain)" \
  || fail "git status failed"
if [ -n "$worktree_status" ]; then
  fail "working tree is dirty (staged/unstaged/untracked changes). Commit or stash first."
fi
info "clean worktree ✓"

# 3. bats tests/
if ! "$BATS_BIN" "$REPO_ROOT/tests/"; then
  fail "bats tests/ failed."
fi
info "bats tests/ ✓"

# 4. bash -n for all shell scripts
bash_n_failed=0
for f in "$REPO_ROOT/.devcontainer/scripts/"* "$REPO_ROOT/scripts/"*.sh; do
  [ -f "$f" ] || continue
  if ! bash -n "$f"; then
    printf '[pre-pr-check] ERROR: syntax error in %s\n' "$f" >&2
    bash_n_failed=1
  fi
done
[ "$bash_n_failed" -eq 0 ] || fail "bash -n check found syntax errors."
info "bash -n ✓"

# 5. determine changed files vs origin/main — fail closed, never narrow-fallback
if ! "$GIT_BIN" -C "$REPO_ROOT" rev-parse --verify --quiet origin/main >/dev/null; then
  fail "cannot resolve origin/main. Run 'git fetch origin main'. Refusing to guess the diff base."
fi
changed="$("$GIT_BIN" -C "$REPO_ROOT" diff --name-only origin/main...HEAD)" \
  || fail "git diff against origin/main failed"

# 6. devcontainer-related change detection from the canonical path list
[ -f "$PATHS_FILE" ] || fail "missing canonical path list: $PATHS_FILE"
needs_smoke=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  while IFS= read -r pat; do
    [ -z "$pat" ] && continue
    case "$pat" in \#*) continue ;; esac
    # shellcheck disable=SC2254
    if [[ "$file" == $pat ]]; then
      needs_smoke=1
      break
    fi
  done < "$PATHS_FILE"
  [ "$needs_smoke" -eq 1 ] && break
done <<< "$changed"

# 7. smoke evidence content verification (not mere existence)
if [ "$needs_smoke" -eq 1 ]; then
  evidence="$REPO_ROOT/.sdd/smoke-evidence.txt"
  if [ ! -s "$evidence" ]; then
    fail "devcontainer-related changes detected but .sdd/smoke-evidence.txt is missing or empty.
Run: scripts/smoke-devcontainer.sh   (it writes verified evidence on success)"
  fi
  if ! grep -q '^SMOKE_RESULT=pass$' "$evidence"; then
    fail "smoke evidence has no success marker (SMOKE_RESULT=pass). Re-run scripts/smoke-devcontainer.sh"
  fi
  ev_commit="$(sed -n 's/^COMMIT=//p' "$evidence" | head -1)"
  [ -n "$ev_commit" ] || fail "smoke evidence is missing COMMIT. Re-run scripts/smoke-devcontainer.sh"
  head_commit="$("$GIT_BIN" -C "$REPO_ROOT" rev-parse HEAD)" || fail "cannot resolve HEAD"
  if [ "$ev_commit" != "$head_commit" ]; then
    fail "smoke evidence is stale (recorded $ev_commit, HEAD is $head_commit). Re-run smoke at current HEAD."
  fi
  info "smoke evidence verified ✓"
else
  info "no devcontainer-related changes, smoke not required"
fi

# 8. .sdd/tasks.json: valid JSON, no blocked tasks (fail closed on malformed)
tasks_json="$REPO_ROOT/.sdd/tasks.json"
if [ -f "$tasks_json" ]; then
  if ! "$JQ_BIN" -e . "$tasks_json" >/dev/null 2>&1; then
    fail ".sdd/tasks.json is not valid JSON."
  fi
  blocked_count="$("$JQ_BIN" '[.[] | select(.status=="blocked")] | length' "$tasks_json")"
  if [ "$blocked_count" -gt 0 ]; then
    fail "$blocked_count blocked task(s) in .sdd/tasks.json. Resolve before creating a PR."
  fi
  info "tasks.json ✓"
fi

info "All pre-PR checks passed. You may now create a PR."
