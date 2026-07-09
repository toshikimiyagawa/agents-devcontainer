# Issue 63 external injection design

- Issue: #63
- Child issue for this phase: #64
- Date: 2026-07-10
- Status: approved for SDD contract creation

## Problem

`agents-devcontainer` currently assumes that a consuming repository accepts generated `.devcontainer` files and repo-local `dotfiles/` state. That model is still useful for new projects, but it is wrong for repositories that already own their devcontainer configuration and should not be modified by agent tooling.

The project needs a second consumption path: inject agent tooling from outside the target repository while preserving the target repository's existing devcontainer definition.

## Recommended approach

Use two explicit entrypoints:

1. VS Code `Reopen in Container` uses a published Dev Container Feature through the user's `dev.containers.defaultFeatures` setting.
2. CLI usage goes through a project-owned wrapper named `adc up`, which calls `devcontainer up` with `--additional-features` and repo-external state mounts.

This keeps the target repository clean and avoids hiding behavior behind a `devcontainer` command shim.

## Initial scope

The first implementation should build the minimum viable external-injection path, not a complete replacement for the existing base image.

- Add a Dev Container Feature skeleton for agent tooling.
- Add an `adc up` wrapper that can inject that Feature when invoking `devcontainer up`.
- Document the VS Code and CLI paths.
- Test that command generation and repository-clean behavior are explicit and stable.

## Deliberate constraints

- Debian/Ubuntu containers are the initial supported target.
- `install.sh` runs as root, following Dev Container Feature conventions.
- Raw `devcontainer up` is not expected to apply VS Code `defaultFeatures`.
- The existing scaffold/submodule path remains supported and separate.
- Target repositories must not receive generated agent config, cache, state, or auth files.
- Full parity with the existing `ghcr.io/toshikimiyagawa/agents-devcontainer` base image is not part of the first implementation.

## Alternatives considered

### Extend scaffold

This would continue generating files in the target repository. It is compatible with the current code, but it directly conflicts with #63's goal.

### Shim `devcontainer`

Replacing or shadowing the user's `devcontainer` command could make raw `devcontainer up` behave like `adc up`, but the hidden behavior would be hard to debug and surprising for users who expect upstream CLI semantics.

### Feature plus explicit wrapper

This makes both entrypoints explicit. VS Code uses documented user settings; CLI users run `adc up`. The tradeoff is one new command, but the behavior remains inspectable and testable.

## Resulting implementation boundary

#64 creates the SDD contract only. Implementation should be split across the child issues:

- #65: Feature skeleton and install path
- #66: `adc up` wrapper
- #67: documentation
- #68: verification and regression tests

