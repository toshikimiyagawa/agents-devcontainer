#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../scripts/pre-pr-check.sh"

setup() {
  REPO="$(mktemp -d)"
  BIN="$(mktemp -d)"
  mkdir -p "$REPO/.devcontainer/scripts" "$REPO/scripts" "$REPO/tests" "$REPO/.sdd"

  # bash -n チェック用の正常スクリプト
  printf '#!/usr/bin/env bash\necho ok\n' > "$REPO/.devcontainer/scripts/good-script"
  printf '#!/usr/bin/env bash\necho ok\n' > "$REPO/scripts/good.sh"

  export REPO BIN
  export REPO_ROOT="$REPO"
  export GIT_BIN="$BIN/git"
  export BATS_BIN="$BIN/bats"
  JQ_BIN="$(command -v jq)"
  export JQ_BIN

  _make_git "feature-branch" ""
  _make_bats 0
}

teardown() {
  rm -rf "$REPO" "$BIN"
}

_make_git() {
  local branch="$1" changed="$2"
  cat > "$BIN/git" <<SH
#!/usr/bin/env bash
for arg in "\$@"; do
  case "\$arg" in
    --abbrev-ref) printf '%s\n' "$branch"; exit 0 ;;
    --name-only)  printf '%s\n' "$changed"; exit 0 ;;
  esac
done
SH
  chmod +x "$BIN/git"
}

_make_bats() {
  local code="$1"
  printf '#!/usr/bin/env bash\nexit %s\n' "$code" > "$BIN/bats"
  chmod +x "$BIN/bats"
}

@test "exits 1 when on main branch" {
  _make_git "main" ""
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "main branch" ]]
}

@test "exits 1 when bats tests fail" {
  _make_bats 1
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "bats" ]]
}

@test "exits 1 when a script has a syntax error" {
  printf '#!/usr/bin/env bash\nif\n' > "$REPO/.devcontainer/scripts/bad-script"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "syntax error" ]]
}

@test "exits 0 when no devcontainer changes and no tasks.json" {
  _make_git "feature-branch" "README.md"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "exits 1 when devcontainer change detected but no smoke evidence" {
  _make_git "feature-branch" ".devcontainer/scripts/new-script"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "smoke-evidence.txt" ]]
}

@test "exits 0 when devcontainer change detected and smoke evidence present" {
  _make_git "feature-branch" ".devcontainer/scripts/new-script"
  printf 'smoke passed\n' > "$REPO/.sdd/smoke-evidence.txt"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "exits 1 when tasks.json has blocked tasks" {
  printf '[{"id":"foo","status":"blocked","blocked_reason":"test"}]\n' \
    > "$REPO/.sdd/tasks.json"
  _make_git "feature-branch" "README.md"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "blocked" ]]
}

@test "exits 0 when tasks.json has no blocked tasks" {
  printf '[{"id":"foo","status":"implementation_complete"}]\n' \
    > "$REPO/.sdd/tasks.json"
  _make_git "feature-branch" "README.md"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}
