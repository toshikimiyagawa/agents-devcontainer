#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

SCRIPT="$BATS_TEST_DIRNAME/../scripts/pre-pr-check.sh"

setup() {
  REPO="$(mktemp -d)"
  BIN="$(mktemp -d)"
  mkdir -p "$REPO/.devcontainer/scripts" "$REPO/scripts" "$REPO/tests" "$REPO/.sdd"

  # bash -n が通る正常スクリプト
  printf '#!/usr/bin/env bash\necho ok\n' > "$REPO/.devcontainer/scripts/good-script"
  printf '#!/usr/bin/env bash\necho ok\n' > "$REPO/scripts/good.sh"

  # canonical path list（hermetic な fixture）
  PATHS_FILE="$REPO/scripts/devcontainer-paths.txt"
  cat > "$PATHS_FILE" <<'EOF'
# comment
.devcontainer/scripts/**
dotfiles/**
scaffold.sh
.github/workflows/smoke-devcontainer.yml
EOF

  HEAD_SHA="1111111111111111111111111111111111111111"

  export REPO BIN PATHS_FILE HEAD_SHA
  export REPO_ROOT="$REPO"
  export GIT_BIN="$BIN/git"
  export BATS_BIN="$BIN/bats"
  JQ_BIN="$(command -v jq)"
  export JQ_BIN

  # default scenario: feature branch, clean tree, no changes, origin/main present
  export BRANCH="feature-branch"
  export DIRTY=""
  export CHANGED=""
  export NO_ORIGIN_MAIN=""
  export DIFF_FAIL=""
  export GIT_FAIL_STATUS=""
  export BATS_STATUS=0

  _make_git
  _make_bats
}

teardown() {
  rm -rf "$REPO" "$BIN"
}

_make_git() {
  cat > "$BIN/git" <<'SH'
#!/usr/bin/env bash
args="$*"
case "$args" in
  *"rev-parse --abbrev-ref HEAD"*) printf '%s\n' "${BRANCH:-feature-branch}"; exit 0 ;;
  *"status --porcelain"*)
    [ -n "${GIT_FAIL_STATUS:-}" ] && exit 1
    [ -n "${DIRTY:-}" ] && printf '%s\n' "${DIRTY}"
    exit 0 ;;
  *"rev-parse --verify --quiet origin/main"*)
    [ -n "${NO_ORIGIN_MAIN:-}" ] && exit 1
    printf 'originmainsha\n'; exit 0 ;;
  *"diff --name-only origin/main...HEAD"*)
    [ -n "${DIFF_FAIL:-}" ] && exit 1
    [ -n "${CHANGED:-}" ] && printf '%s\n' "${CHANGED}"
    exit 0 ;;
  *"rev-parse HEAD"*) printf '%s\n' "${HEAD_SHA:-deadbeef}"; exit 0 ;;
esac
printf 'fake-git: unexpected call: %s\n' "$args" >&2
exit 1
SH
  chmod +x "$BIN/git"
}

_make_bats() {
  cat > "$BIN/bats" <<'SH'
#!/usr/bin/env bash
exit "${BATS_STATUS:-0}"
SH
  chmod +x "$BIN/bats"
}

# evidence を成功証跡として書く（COMMIT は HEAD_SHA に一致）
_write_good_evidence() {
  cat > "$REPO/.sdd/smoke-evidence.txt" <<EOF
SMOKE_RESULT=pass
COMMIT=$HEAD_SHA
DATE=2026-06-22T00:00:00Z
HOST=test
DOCKER=test
EOF
}

run_check() {
  run env \
    REPO_ROOT="$REPO" GIT_BIN="$GIT_BIN" BATS_BIN="$BATS_BIN" JQ_BIN="$JQ_BIN" \
    PATHS_FILE="$PATHS_FILE" \
    BRANCH="$BRANCH" DIRTY="$DIRTY" CHANGED="$CHANGED" \
    NO_ORIGIN_MAIN="$NO_ORIGIN_MAIN" DIFF_FAIL="$DIFF_FAIL" \
    GIT_FAIL_STATUS="$GIT_FAIL_STATUS" HEAD_SHA="$HEAD_SHA" BATS_STATUS="$BATS_STATUS" \
    bash "$SCRIPT"
}

# --- branch / worktree gates (fail-closed) ---

@test "exits 1 when on main branch" {
  export BRANCH="main"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "main" ]]
}

@test "exits 1 when on master branch" {
  export BRANCH="master"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "master" ]]
}

@test "exits 1 on detached HEAD" {
  export BRANCH="HEAD"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "detached" ]]
}

@test "exits 1 when working tree is dirty (unstaged)" {
  export DIRTY=" M dotfiles/.zshrc"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "dirty" ]]
}

@test "exits 1 when working tree has staged changes" {
  export DIRTY="M  scripts/foo.sh"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "dirty" ]]
}

@test "exits 1 when working tree has untracked files" {
  export DIRTY="?? newfile"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "dirty" ]]
}

@test "exits 1 when git status itself fails (fail-closed)" {
  export GIT_FAIL_STATUS=1
  run_check
  [ "$status" -eq 1 ]
}

# --- bats / bash -n ---

@test "exits 1 when bats tests fail" {
  export BATS_STATUS=1
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "bats" ]]
}

@test "exits 1 when a script has a syntax error" {
  printf '#!/usr/bin/env bash\nif\n' > "$REPO/.devcontainer/scripts/bad-script"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "syntax error" ]]
}

# --- base ref resolution (fail-closed) ---

@test "exits 1 when origin/main cannot be resolved (fail-closed, no narrow fallback)" {
  export NO_ORIGIN_MAIN=1
  export CHANGED="README.md"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "origin/main" ]]
}

@test "exits 1 when git diff against origin/main fails" {
  export DIFF_FAIL=1
  run_check
  [ "$status" -eq 1 ]
}

# --- no devcontainer change ---

@test "exits 0 when no devcontainer changes and no tasks.json" {
  export CHANGED="README.md"
  run_check
  [ "$status" -eq 0 ]
}

# --- smoke evidence content verification ---

@test "exits 1 when devcontainer change detected but no smoke evidence" {
  export CHANGED=".devcontainer/scripts/new-script"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "smoke-evidence.txt" ]]
}

@test "exits 1 when smoke evidence is empty" {
  export CHANGED=".devcontainer/scripts/new-script"
  : > "$REPO/.sdd/smoke-evidence.txt"
  run_check
  [ "$status" -eq 1 ]
}

@test "exits 1 when smoke evidence is forged (no success marker)" {
  export CHANGED="dotfiles/.zshrc"
  printf 'COMMIT=%s\nlooks legit\n' "$HEAD_SHA" > "$REPO/.sdd/smoke-evidence.txt"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "marker" ]]
}

@test "exits 1 when smoke evidence is stale / wrong-HEAD" {
  export CHANGED="dotfiles/.zshrc"
  cat > "$REPO/.sdd/smoke-evidence.txt" <<EOF
SMOKE_RESULT=pass
COMMIT=0000000000000000000000000000000000000000
DATE=2026-06-22T00:00:00Z
EOF
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "stale" ]]
}

@test "exits 1 when smoke evidence has success marker but missing COMMIT" {
  export CHANGED="dotfiles/.zshrc"
  printf 'SMOKE_RESULT=pass\n' > "$REPO/.sdd/smoke-evidence.txt"
  run_check
  [ "$status" -eq 1 ]
}

@test "exits 0 when devcontainer change detected and evidence matches HEAD" {
  export CHANGED=".devcontainer/scripts/new-script"
  _write_good_evidence
  run_check
  [ "$status" -eq 0 ]
}

@test "matches a deep path under a ** glob entry" {
  export CHANGED=".devcontainer/scripts/sub/deeply/nested"
  _write_good_evidence
  run_check
  [ "$status" -eq 0 ]
}

@test "exact-match entry triggers smoke requirement" {
  export CHANGED="scaffold.sh"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "smoke-evidence.txt" ]]
}

# --- tasks.json schema / state ---

@test "exits 1 when tasks.json has blocked tasks" {
  export CHANGED="README.md"
  printf '[{"id":"foo","phase":"implement","status":"blocked","blocked_reason":"x"}]\n' \
    > "$REPO/.sdd/tasks.json"
  run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "blocked" ]]
}

@test "exits 1 when tasks.json is malformed JSON (fail-closed)" {
  export CHANGED="README.md"
  printf '{ not json\n' > "$REPO/.sdd/tasks.json"
  run_check
  [ "$status" -eq 1 ]
}

@test "exits 0 when tasks.json has no blocked tasks" {
  export CHANGED="README.md"
  printf '[{"id":"foo","phase":"implement","status":"completed"}]\n' \
    > "$REPO/.sdd/tasks.json"
  run_check
  [ "$status" -eq 0 ]
}

# --- path-list drift detection (single source of truth) ---

@test "real path list: workflow matches canonical source (no drift)" {
  canon="$BATS_TEST_DIRNAME/../scripts/devcontainer-paths.txt"
  wf="$BATS_TEST_DIRNAME/../.github/workflows/smoke-devcontainer.yml"
  [ -f "$canon" ]
  [ -f "$wf" ]
  want="$(grep -vE '^[[:space:]]*(#|$)' "$canon" | sort)"
  got="$(grep -oE "^[[:space:]]*-[[:space:]]*'[^']+'" "$wf" | sed -E "s/^[[:space:]]*-[[:space:]]*'//; s/'$//" | sort)"
  [ "$want" = "$got" ]
}
