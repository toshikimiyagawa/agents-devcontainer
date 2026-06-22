# Devcontainer Rebuild Smoke Tasks

Implement in order. Use RED-GREEN discipline and end each task with the listed focused
commit. Do not run the real full smoke from inside a devcontainer; it belongs to the
host verify phase.

## Task 1: Provide the in-container Bats runtime

**Files:** Modify `tests/devcontainer.bats` and `.devcontainer/Dockerfile.base`.

**Produces:** The locally built base image contains `bats` without smoke-time installs.

- [ ] Add this RED test to `tests/devcontainer.bats`:

```bash
@test "base image installs bats for in-container smoke tests" {
  run awk '
    /apt-get install -y --no-install-recommends/ { in_install = 1 }
    in_install && /^[[:space:]]*bats([[:space:]\\]|$)/ { found = 1 }
    in_install && /rm -rf \/var\/lib\/apt\/lists/ { in_install = 0 }
    END { exit(found ? 0 : 1) }
  ' "$BATS_TEST_DIRNAME/../.devcontainer/Dockerfile.base"
  [ "$status" -eq 0 ]
}
```

- [ ] Run `bats tests/devcontainer.bats`; confirm the new test fails.
- [ ] Add `bats` to the first existing `apt-get install -y --no-install-recommends`
  package list in `.devcontainer/Dockerfile.base`; do not add another install layer.
- [ ] Run `bats tests/devcontainer.bats`; expect all tests to pass.
- [ ] Commit:

```bash
git add .devcontainer/Dockerfile.base tests/devcontainer.bats
git commit -m "build(devcontainer-rebuild-smoke): install bats in base image"
```

## Task 2: Add the host smoke orchestrator and unit tests

**Files:** Create `scripts/smoke-devcontainer.sh` and
`tests/smoke-devcontainer.bats`.

**Consumes:** The base image provides `bats` from Task 1.

**Produces:** `scripts/smoke-devcontainer.sh`, the sole full-smoke entrypoint.

### Script interface

The script accepts no arguments. The test harness may override command names through:

```bash
BATS_BIN="${BATS_BIN:-bats}"
DOCKER_BIN="${DOCKER_BIN:-docker}"
DEVCONTAINER_BIN="${DEVCONTAINER_BIN:-devcontainer}"
GIT_BIN="${GIT_BIN:-git}"
JQ_BIN="${JQ_BIN:-jq}"
```

Its stages are `host-tests`, `base-image-build`, `derive-config`,
`devcontainer-up`, `container-tests`, `tool-checks`, and `hermes-check`, in that
order.

- [ ] Create a Bats harness that copies the script into a temporary repo, creates fake
  `bats`, `docker`, `devcontainer`, `git`, and `jq` executables under `$TMPDIR/bin`,
  prepends it to `PATH`, and records calls in `$TMPDIR/calls`. The fake
  `devcontainer read-configuration` emits:

```json
{
  "configuration": {
    "name": "smoke-test",
    "build": {"context": "..", "dockerfile": "../.devcontainer/Dockerfile", "options": ["--pull"]},
    "workspaceFolder": "/workspace",
    "postCreateCommand": "agents-post-create",
    "postStartCommand": "agents-post-start"
  }
}
```

The fake git returns `$FAKE_GIT_STATUS` for
`status --porcelain=v1 --untracked-files=all`. Fake Docker accepts `info` and records
`build`. Fake Dev Container CLI records `up` and `exec`; it fails when
`FAKE_DEVCONTAINER_FAIL` matches the subcommand. Fake jq may delegate to the real jq
path captured before `PATH` changes.

- [ ] Add RED tests with these exact names:

```text
rejects execution inside a devcontainer
reports each missing host prerequisite before building
fails before building when Docker is unusable
runs host tests before building the current checkout
derives a temporary config from the tracked dogfood config
uses the local image config and remove-existing-container for up
propagates devcontainer lifecycle failure
runs Bats and required tool checks inside the container
warns without failing when Hermes provider configuration is absent
fails when the Hermes persistence layout check fails
removes temporary files after success and failure
fails when smoke changes the working tree
preserves the original failure when cleanup also detects a tree change
can be launched outside the repository root
```

Call assertions must cover these exact fragments:

```bash
grep -F "bats $REPO/tests/" "$CALLS"
grep -F "docker build -t agents-devcontainer:pr -f $REPO/.devcontainer/Dockerfile.base $REPO" "$CALLS"
grep -F "devcontainer read-configuration --workspace-folder $REPO --config $REPO/.devcontainer/devcontainer.json" "$CALLS"
grep -F "devcontainer up --workspace-folder $REPO --config " "$CALLS"
grep -F -- "--remove-existing-container" "$CALLS"
grep -F "bats tests/" "$CALLS"
for tool in codex gemini claude hermes gh yq; do
  grep -F "$tool" "$CALLS"
done
```

The derived-config fake copies the config and Dockerfile before cleanup. Assert:

```bash
[ "$(jq -r '.build.context' "$CAPTURED")" = "$REPO" ]
[ "$(jq -r '.build.options | length' "$CAPTURED")" -eq 0 ]
grep -F 'ARG BASE_IMAGE=agents-devcontainer:pr' "$CAPTURED_DOCKERFILE"
grep -F 'FROM ${BASE_IMAGE}' "$CAPTURED_DOCKERFILE"
[ "$(jq -r '.postCreateCommand' "$CAPTURED")" = "agents-post-create" ]
[ "$(jq -r '.postStartCommand' "$CAPTURED")" = "agents-post-start" ]
```

- [ ] Run `bats tests/smoke-devcontainer.bats`; confirm RED because the script is
  absent.
- [ ] Implement the script with `#!/usr/bin/env bash`, `set -euo pipefail`, and:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
```

Reject execution when `REMOTE_CONTAINERS` is non-empty or `/.dockerenv` exists.
Validate `bats`, `docker`, `devcontainer`, `git`, and `jq` with `command -v`; run
`docker info` before tests or builds.

- [ ] Snapshot the tree with:

```bash
initial_status="$($GIT_BIN -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all)"
```

Print the destructive rebuild warning. Run `bats "$REPO_ROOT/tests/"`, then:

```bash
"$DOCKER_BIN" build -t agents-devcontainer:pr \
  -f "$REPO_ROOT/.devcontainer/Dockerfile.base" "$REPO_ROOT"
```

Create the temporary directory only after the build succeeds.

- [ ] Install an EXIT trap that disables itself, preserves the incoming status,
  removes the temporary directory, compares final git status, upgrades success to
  status 1 when the tree changed, and never masks an earlier failure.
- [ ] Create the temporary Dockerfile exactly as:

```dockerfile
ARG BASE_IMAGE=agents-devcontainer:pr
FROM ${BASE_IMAGE}
```

Derive the config exactly through:

```bash
"$DEVCONTAINER_BIN" read-configuration \
  --workspace-folder "$REPO_ROOT" \
  --config "$REPO_ROOT/.devcontainer/devcontainer.json" \
  > "$tmp_dir/resolved.json"

"$JQ_BIN" --arg root "$REPO_ROOT" --arg dockerfile "$tmp_dir/Dockerfile" '
  .configuration
  | .build = {context: $root, dockerfile: $dockerfile, options: []}
' "$tmp_dir/resolved.json" > "$tmp_dir/devcontainer.json"
```

- [ ] Run `devcontainer up` with workspace, temporary config, and
  `--remove-existing-container`. Never pass lifecycle-skipping flags.
- [ ] Run container tests through:

```bash
"$DEVCONTAINER_BIN" exec --workspace-folder "$REPO_ROOT" \
  --config "$tmp_dir/devcontainer.json" \
  bash -lc 'cd /workspace && bats tests/'
```

- [ ] Run one exec command looping over `codex gemini claude hermes gh yq`; emit
  `missing required tool: <name>` and fail on the first absence.
- [ ] Run one Hermes command requiring symlinks for `config.yaml`, `.env`, and
  `memories`, and a non-symlink directory for `skills`. When `config.yaml` is empty
  and `.env` has no non-comment assignment, print exactly
  `WARNING: Hermes provider/model configuration is not configured` and succeed.
- [ ] Make the script executable. Run `bash -n scripts/smoke-devcontainer.sh` and
  `bats tests/smoke-devcontainer.bats`; expect GREEN.
- [ ] Commit:

```bash
git add scripts/smoke-devcontainer.sh tests/smoke-devcontainer.bats
git commit -m "feat(devcontainer-rebuild-smoke): add host smoke orchestrator"
```

## Task 3: Add the pull-request full-smoke workflow

**Files:** Create `.github/workflows/smoke-devcontainer.yml`; modify
`tests/smoke-devcontainer.bats`.

- [ ] Add RED tests named `workflow covers every required smoke path` and
  `workflow installs prerequisites and invokes the shared smoke script`. Assert every
  exact path from the spec plus `actions/checkout@v4`,
  `bats-core/bats-action@3.0.0`, `npm install -g @devcontainers/cli`,
  `mkdir -p "$HOME/.ssh"`, and `scripts/smoke-devcontainer.sh`. Assert no
  `docker push`, registry login, or package write permission.
- [ ] Run the focused Bats file and confirm RED.
- [ ] Create one path-filtered `pull_request` workflow job named `smoke` on
  `ubuntu-latest`. Include checkout, Bats install, Dev Container CLI install,
  SSH-directory creation, and shared script invocation. Do not publish images.
- [ ] Run the focused Bats file; expect GREEN.
- [ ] Commit:

```bash
git add .github/workflows/smoke-devcontainer.yml tests/smoke-devcontainer.bats
git commit -m "ci(devcontainer-rebuild-smoke): run full smoke on pull requests"
```

## Task 4: Document and test the maintainer gate

**Files:** Modify `README.md` and `tests/smoke-devcontainer.bats`.

- [ ] Add a RED test named `README defines the host-only devcontainer smoke gate`.
  Assert exact script path, host execution, Bats-alone insufficiency,
  `--remove-existing-container`, Hermes warning policy, PR disclosure rule, and every
  relevant path category from the spec.
- [ ] Run the focused Bats file and confirm RED.
- [ ] Add `PR 前の devcontainer smoke` under the dogfood maintainer section. Include
  the command; prerequisites (`bats`, Docker, `devcontainer`, `git`, `jq`, host
  `~/.ssh`); relevant paths; destructive warning; Hermes policy; and the rule that an
  unexecuted host smoke is disclosed and incomplete until author or CI full smoke
  succeeds.
- [ ] Run the focused Bats file; expect GREEN.
- [ ] Commit:

```bash
git add README.md tests/smoke-devcontainer.bats
git commit -m "docs(devcontainer-rebuild-smoke): define pre-PR smoke gate"
```

## Task 5: Complete implementation checks and tracking

**Files:** Modify only this feature's `status` in `.sdd/tasks.json`.

- [ ] Run `bash -n scripts/smoke-devcontainer.sh`; expect exit 0.
- [ ] Run `bats tests/devcontainer.bats tests/smoke-devcontainer.bats`; expect GREEN.
- [ ] Run `bats tests/`; expect GREEN.
- [ ] Set `devcontainer-rebuild-smoke.status` to `completed`; do not change its phase,
  handoff, `.sdd/state.json`, or any frozen file.
- [ ] Run `bash vendor/ai-sdd-guide/orchestration/tools/kanban.sh` and report output.
- [ ] Commit:

```bash
git add .sdd/tasks.json
git commit -m "chore(devcontainer-rebuild-smoke): complete implementation tasks"
```

- [ ] Stop. Do not verify, invoke `sdd-reviewer`, push, or open a PR until the human
  explicitly starts the verify phase.

## Acceptance criteria mapping

| AC | Evidence |
|---|---|
| 1 | Frozen artifacts, `.sdd/state.json`, orchestration CI |
| 2 | Bats container rejection, prerequisites, outside-root invocation |
| 3 | Bats ordering and exact current-checkout build arguments |
| 4 | Bats derived config, cleanup, and pre-existing git-status preservation |
| 5 | Bats up flags/failure propagation; verify-phase full smoke |
| 6 | Dockerfile test, recorded container Bats, verify-phase full smoke |
| 7 | Bats tool loop; verify-phase full smoke |
| 8 | Bats Hermes warning/layout cases; verify-phase full smoke |
| 9 | `bats tests/` |
| 10 | Workflow Bats tests and GitHub Actions result |
| 11 | README Bats test and documentation |
| 12 | Verify-phase host Bats, host full smoke, and GitHub Actions |
| 13 | Feature branch, commits, and PR in verify/publish phase |
