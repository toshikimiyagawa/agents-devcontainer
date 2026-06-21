# Devcontainer Rebuild Smoke Implementation Plan

> **For agentic workers:** Execute only `tasks.md`, task by task. Do not alter the
> frozen spec. If a task cannot satisfy the spec, mark the SDD task blocked and stop.

**Goal:** Add a host and CI gate that rebuilds the dogfood devcontainer from the
current checkout and proves its lifecycle, tests, tools, and Hermes persistence layout.

**Architecture:** A single host shell entrypoint owns orchestration. It builds the
local base image, asks `devcontainer read-configuration` to parse and resolve the
tracked JSONC config, rewrites only the build block into a temporary JSON config, then
uses that config for `up` and `exec`. Bats unit tests replace external commands with
recording fakes; GitHub Actions runs the real entrypoint.

**Tech Stack:** Bash 3.2-compatible shell, Bats, Docker, Dev Container CLI, jq,
GitHub Actions.

## Global constraints

- The full smoke runs on the host, never from inside a devcontainer.
- The current checkout is the Docker build context.
- Tracked `.devcontainer` files are never temporarily rewritten.
- The smoke installs or downloads no test tooling.
- Existing working-tree state remains equivalent according to
  `git status --porcelain=v1 --untracked-files=all`.
- Hermes provider/model absence is a warning; missing command or invalid persistence
  layout is an error.
- Implementation does not modify `spec.md`, this plan, or `tasks.md`.

## File map

| File | Responsibility |
|---|---|
| `.devcontainer/Dockerfile.base` | Provide `bats` inside the rebuilt container |
| `scripts/smoke-devcontainer.sh` | Host preflight, build, temporary config, rebuild, and runtime checks |
| `tests/devcontainer.bats` | Assert the image definition provides Bats |
| `tests/smoke-devcontainer.bats` | Unit-test smoke orchestration with fake commands |
| `.github/workflows/smoke-devcontainer.yml` | Run the real full smoke on relevant PRs |
| `README.md` | Define the maintainer gate and disclosure policy |
| `.sdd/tasks.json` | Track implementation completion only |

## Configuration derivation

Do not parse JSONC manually. Run `devcontainer read-configuration` with the tracked
config, select `.configuration` with jq, and replace `.build` with an absolute
repository context, an absolute temporary Dockerfile, and empty options. This retains
resolved mounts, lifecycle commands, users, and environment without a duplicate
configuration.

## Process isolation

The smoke operates on the current workspace identity and passes
`--remove-existing-container`. It warns before doing so. A `mktemp -d` directory holds
the derived JSON and Dockerfile; an EXIT trap removes it and compares final git status
while preserving any earlier failure.

## CI

Use an independent path-filtered PR workflow. The runner installs Bats and
`@devcontainers/cli`, ensures `~/.ssh` exists for the tracked bind mount, and invokes
the shared script. Do not duplicate smoke stages in YAML or push images.

## Alternatives rejected

- Manual-only full smoke: cannot enforce the gate when a PR author omits it.
- CI subset only: does not prove lifecycle hooks or runtime state.
- A second tracked smoke config: drifts from the dogfood configuration.
- Installing Bats during smoke: tests a mutated, network-dependent runtime.

## Risks and controls

- Full image rebuilds are slow: retain Docker layer caching and path-filter the job.
- Rebuild can replace the active dogfood container: warn before build and document it.
- Lifecycle hooks may alter tracked dotfiles: compare pre/post git status and fail.
- GitHub runners may lack `~/.ssh`: create the empty directory before smoke.
- JSONC parsing can drift: use the Dev Container CLI parser, not regex.

## Verification boundary

Implementation finishes after shell syntax and Bats pass and changes are committed.
The separate verify phase runs these commands from the host:

```bash
bats tests/
scripts/smoke-devcontainer.sh
```

It then runs `sdd-reviewer` and checks GitHub Actions before completion is reported.
