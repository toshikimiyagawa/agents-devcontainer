#!/usr/bin/env bash
set -euo pipefail

BATS_BIN="${BATS_BIN:-bats}"
GIT_BIN="${GIT_BIN:-git}"
JQ_BIN="${JQ_BIN:-jq}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

fail() { printf '[pre-pr-check] ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '[pre-pr-check] %s\n' "$*"; }

# 1. feature branch 上にいることを確認
branch="$("$GIT_BIN" -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
if [ "$branch" = "main" ]; then
  fail "On main branch. Create a feature branch first."
fi
info "branch: $branch ✓"

# 2. bats tests/
if ! "$BATS_BIN" "$REPO_ROOT/tests/"; then
  fail "bats tests/ failed."
fi
info "bats tests/ ✓"

# 3. bash -n で全スクリプトの構文確認
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

# 4. devcontainer 関連パス変更 → smoke 証跡が必要
# smoke-devcontainer.yml の paths: と同期を保つこと
if ! changed="$("$GIT_BIN" -C "$REPO_ROOT" diff --name-only "origin/main...HEAD" 2>/dev/null)"; then
  info "WARNING: could not reach origin/main, falling back to HEAD diff (may be incomplete)"
  changed="$("$GIT_BIN" -C "$REPO_ROOT" diff --name-only "HEAD" 2>/dev/null)" || true
fi

needs_smoke=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  case "$file" in
    .devcontainer/*|dotfiles/*|scaffold.sh|scaffold/*|\
    scripts/smoke-devcontainer.sh|tests/smoke-devcontainer.bats|\
    .github/workflows/smoke-devcontainer.yml)
      needs_smoke=1
      break
      ;;
  esac
done <<< "$changed"

if [ "$needs_smoke" -eq 1 ]; then
  evidence="$REPO_ROOT/.sdd/smoke-evidence.txt"
  if [ ! -f "$evidence" ]; then
    fail "devcontainer-related changes detected but .sdd/smoke-evidence.txt not found.
Run: mkdir -p .sdd && scripts/smoke-devcontainer.sh 2>&1 | tee .sdd/smoke-evidence.txt"
  fi
  info "smoke evidence ✓"
else
  info "no devcontainer-related changes, smoke not required"
fi

# 5. .sdd/tasks.json に blocked タスクがないことを確認
tasks_json="$REPO_ROOT/.sdd/tasks.json"
if [ -f "$tasks_json" ]; then
  blocked_count="$("$JQ_BIN" '[.[] | select(.status=="blocked")] | length' "$tasks_json")"
  if [ "$blocked_count" -gt 0 ]; then
    fail "$blocked_count blocked task(s) in .sdd/tasks.json. Resolve before creating a PR."
  fi
  info "tasks.json ✓"
fi

info "All pre-PR checks passed. You may now create a PR."
