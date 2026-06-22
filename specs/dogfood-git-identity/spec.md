# Dogfood Git Identity Specification

## Status

- Feature: `dogfood-git-identity`
- Tier: 1
- Phase: spec
- Related issue: GitHub #51
- Blocks: GitHub #49

## Intent

Prevent the dogfood devcontainer from injecting empty Git author and committer
environment variables. A host without Git identity environment variables must still
be able to create and start the devcontainer, run the repository tests, and use an
explicit Git configuration without empty environment variables overriding it.

## Scope

- Remove `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`, and
  `GIT_COMMITTER_EMAIL` from the dogfood `.devcontainer/devcontainer.json`.
- Keep `agents-post-start` support for non-empty identity variables explicitly
  supplied by another configuration.
- Fill missing name or email from `gh api user` when GitHub CLI is authenticated.
- Never write an empty identity value to Git config.
- After setup, warn without failing when the effective Git name or email is still
  missing. The warning must identify the missing setting and explain how to set it.
- Update the README and `.devcontainer/Agents.md` to describe the actual behavior.
- Keep the dogfood and consumer base configurations aligned: neither configuration
  forwards the four Git identity variables by default.

## Behavior

`agents-post-start` resolves identity as follows:

1. Use a non-empty `GIT_AUTHOR_NAME` or `GIT_AUTHOR_EMAIL` if one was explicitly
   supplied to the container.
2. When either value is missing and `gh` is authenticated, request only the missing
   values from `gh api user`.
3. Write only non-empty resolved values to system Git config.
4. Inspect the effective Git configuration after the attempted setup. Existing valid
   Git configuration satisfies the check and is not replaced with an empty value.
5. If name or email remains missing, print a non-fatal warning with the missing key
   and configuration guidance.

This change does not add conditional devcontainer interpolation, mount the host
`.gitconfig`, or modify the #49 smoke workflow.

## Acceptance Criteria

1. The dogfood and consumer base devcontainer configurations do not define any of
   the four Git author/committer forwarding keys by default.
2. With host identity variables unset and `gh` unauthenticated,
   `agents-post-start` exits successfully and does not write empty Git config values.
3. Authenticated `gh api user` values populate missing system `user.name` and
   `user.email` values.
4. Explicit non-empty identity variables remain supported, and a missing counterpart
   can be filled from `gh` without replacing the explicit value.
5. Existing valid Git configuration prevents an unnecessary missing-identity warning.
6. If the effective name or email is still absent, startup succeeds and a warning
   names the missing setting and provides a configuration action.
7. With the default dogfood configuration, command-local `git -c user.name=... -c
   user.email=...` can create a commit when host identity variables are unset.
8. Automated Bats tests cover criteria 1–7 and the complete host `bats tests/` suite
   passes.
9. README and `.devcontainer/Agents.md` no longer claim that dogfood automatically
   forwards host Git identity variables.
10. The change is submitted from a feature branch with the `sdd:tier-1` label and CI
    passes before completion is reported.

## Test Mapping

- AC1: JSON assertions for both dogfood and consumer base configurations.
- AC2–6: mocked `agents-post-start` Bats cases for unauthenticated, authenticated,
  partial, explicit, and preconfigured identity states.
- AC7: a real temporary Git repository commit test with all four identity environment
  variables unset.
- AC8: focused Bats tests followed by `bats tests/`.
- AC9: documentation assertions or exact text review in the relevant Bats suite.
- AC10: branch, PR label, and GitHub Actions verification.

## Out of Scope

- A new secrets or identity-management mechanism.
- Automatically mounting the host global Git configuration.
- Changing the #49 smoke script or weakening its checks.
- The repository-wide development-rule redesign tracked by #50.
