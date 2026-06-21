# Devcontainer Rebuild Smoke Specification

## Status

- Feature: `devcontainer-rebuild-smoke`
- Tier: 2
- Phase: spec
- Related issue: GitHub #49

## Intent

Prevent devcontainer changes from being treated as complete when only unit tests or
an image build have passed. Maintainers must be able to rebuild the dogfood
devcontainer from the current branch's local base image and verify that its lifecycle
commands and required tools work in the resulting container.

## Scope

This feature adds:

- a host-only `scripts/smoke-devcontainer.sh` entrypoint;
- automated tests for the script's orchestration and failure behavior;
- a GitHub Actions full-smoke job for pull requests that touch relevant paths; and
- maintainer documentation defining the pre-PR smoke gate.

The smoke workflow covers the repository's dogfood `.devcontainer/devcontainer.json`,
not a generated consumer-project configuration.

## Non-goals

- Importing host Hermes provider, model, or secret configuration.
- Requiring Hermes to be configured in a newly created container.
- Replacing the existing Bats or multi-architecture image build workflows.
- Providing a generic smoke framework for downstream repositories.
- Preserving an existing dogfood container when the full smoke is run against the
  same workspace.

## Design

### Host smoke entrypoint

`scripts/smoke-devcontainer.sh` must be launched from the host, from any working
directory. It resolves the repository root from its own location and rejects execution
when it detects that it is already running inside a devcontainer. It fails before any
build when `bats`, `docker`, or `devcontainer` is unavailable or Docker is not usable.

The script runs these stages in order and exits non-zero on the first failure:

1. Run `bats tests/` on the host.
2. Build the current checkout with:
   `docker build -t agents-devcontainer:pr -f .devcontainer/Dockerfile.base .`.
3. Create a temporary smoke directory outside the repository.
4. Generate a smoke Dockerfile whose base is `agents-devcontainer:pr` and a temporary
   devcontainer override derived from the dogfood configuration. The override keeps
   the dogfood lifecycle commands, workspace mount, environment, and runtime user,
   but builds from the temporary smoke Dockerfile and does not use `--pull`.
5. Run `devcontainer up --workspace-folder <repo> --config <temporary-config>
   --remove-existing-container`. A successful command is the proof that
   `postCreateCommand` and `postStartCommand` completed successfully; neither command
   may be skipped.
6. Use `devcontainer exec` against the same workspace/config to run `bats tests/`.
7. Use `devcontainer exec` to require `codex`, `gemini`, `claude`, `hermes`, `gh`, and
   `yq` through `command -v`.
8. Inspect the persisted Hermes configuration paths. Missing provider/model
   configuration prints a clearly labelled warning and does not fail the smoke. A
   missing `hermes` command or an invalid expected Hermes persistence layout fails.
   The expected layout is: `~/.hermes/config.yaml`, `~/.hermes/.env`, and
   `~/.hermes/memories` are symlinks into `/workspace/dotfiles/.hermes/`, while
   `~/.hermes/skills` is a real directory rather than a symlink.

The script installs nothing and does not modify tracked repository configuration.
Temporary files are removed on normal exit and failure. It compares `git status
--porcelain` before and after the smoke and fails if the workflow itself changes the
working tree. Pre-existing changes are allowed and must remain unchanged.

Because `--remove-existing-container` targets the current workspace, the script must
print a warning before rebuild that it may replace the maintainer's existing dogfood
container. Interactive confirmation is not required so the same entrypoint can run in
CI.

### Temporary configuration

The temporary configuration is generated mechanically from
`.devcontainer/devcontainer.json`; the implementation must not maintain a second
hand-written copy of the dogfood configuration. Only the build definition is replaced:

- build context points at the repository root;
- Dockerfile points at the temporary Dockerfile based on
  `agents-devcontainer:pr`; and
- build options do not contain `--pull`.

The generated file and Dockerfile live under a `mktemp` directory. Tracked
`.devcontainer/Dockerfile` and `.devcontainer/devcontainer.json` are never rewritten.

### GitHub Actions gate

A pull-request workflow runs the same full host script on `ubuntu-latest`. It installs
`bats-core` and `@devcontainers/cli`; the runner-provided Docker daemon performs the
build and container lifecycle. The job is triggered when a pull request changes any
of these areas:

- `.devcontainer/Dockerfile.base`
- `.devcontainer/Dockerfile`
- `.devcontainer/devcontainer.json`
- `.devcontainer/scripts/**`
- `dotfiles/**`
- `scaffold.sh`
- `scaffold/**`
- `scripts/smoke-devcontainer.sh`
- `tests/smoke-devcontainer.bats`
- `.github/workflows/smoke-devcontainer.yml`

The workflow does not publish `agents-devcontainer:pr`. Existing image-build and Bats
jobs remain in place; this job adds runtime verification rather than replacing them.

### Documentation gate

The README maintainer section states:

- implementation and unit tests may run inside a devcontainer;
- final smoke must be launched from the host;
- green `bats tests/` alone is not completion for devcontainer-related changes;
- which paths require `scripts/smoke-devcontainer.sh`;
- the command may replace the current dogfood container;
- Hermes being unconfigured is a warning by design; and
- an unexecuted host smoke must be disclosed with its reason in the PR description and
  remains incomplete until either the author or the full-smoke CI job succeeds.

## Error handling

- Every required stage returns a non-zero status on failure and identifies the failed
  stage in stderr.
- Cleanup runs through a shell trap without masking the original exit status.
- A lifecycle-command failure from `devcontainer up` is propagated as a smoke failure.
- A required tool missing inside the container identifies the missing command.
- Hermes provider/model absence is the only expected warning; it must not turn other
  Hermes layout failures into warnings.

## Test strategy

Shell-level Bats tests use fake `bats`, `docker`, `devcontainer`, and `git` executables
on `PATH` to verify prerequisites, stage ordering, arguments, failure propagation,
temporary-file cleanup, working-tree preservation, tool checks, and the non-fatal
Hermes-unconfigured warning. Tests must not require Docker or create a real
devcontainer.

The full integration proof is the host execution of
`scripts/smoke-devcontainer.sh`. Completion requires recording both the host Bats
result and the host devcontainer rebuild smoke result. GitHub Actions is additionally
checked before merge.

## Acceptance criteria

1. `specs/devcontainer-rebuild-smoke/` contains the approved Tier 2 SDD artifacts and
   `.sdd/state.json` identifies this feature and phase.
2. `scripts/smoke-devcontainer.sh` exists, rejects execution inside a devcontainer,
   validates host prerequisites, and can be invoked outside the repository root.
3. The script runs host `bats tests/` before building
   `.devcontainer/Dockerfile.base` as `agents-devcontainer:pr` from the current
   checkout.
4. The script creates its config and Dockerfile under a temporary directory, uses the
   local image for a fresh dogfood `devcontainer up`, and leaves all pre-existing
   working-tree state unchanged.
5. A successful `devcontainer up` runs both configured lifecycle commands; any
   `postCreateCommand` or `postStartCommand` failure fails the smoke.
6. The script runs `bats tests/` inside the rebuilt devcontainer.
7. The script verifies `codex`, `gemini`, `claude`, `hermes`, `gh`, and `yq` inside the
   rebuilt devcontainer and fails with the missing command's name.
8. A missing Hermes provider/model configuration produces a visible warning without
   failing, while a missing Hermes command or invalid persistence layout fails.
9. Automated Bats tests cover the script behavior without requiring Docker and pass
   together with all existing tests.
10. A pull-request GitHub Actions job runs the full smoke for the listed relevant
    paths and does not publish the local smoke image.
11. README documentation defines the host-only pre-PR gate, relevant paths,
    destructive rebuild warning, Hermes warning policy, and disclosure requirement
    when host smoke has not run.
12. Before completion is reported, `bats tests/` and
    `scripts/smoke-devcontainer.sh` have both succeeded when launched from the host;
    GitHub Actions has passed or its unavailable result is explicitly reported as
    incomplete.
13. The work is committed on a feature branch and submitted through a pull request,
    never pushed directly to `main`.
