# External injection for existing devcontainers

Use this path when the target repository already owns its `.devcontainer`
configuration and must not be modified by `agents-devcontainer`.

For new repositories where committing generated `.devcontainer` files is acceptable,
use the scaffold flow in `README.md` instead.

## VS Code: Reopen in Container

For VS Code, inject the agents tooling from user settings with
`dev.containers.defaultFeatures`.

Add this to your VS Code User `settings.json`:

```json
{
  "dev.containers.defaultFeatures": {
    "ghcr.io/toshikimiyagawa/agents-devcontainer/agents:1": {}
  }
}
```

Then open a repository that already has `.devcontainer/devcontainer.json` and run
**Dev Containers: Reopen in Container**.

The Feature is added by VS Code when the container is created. The target
repository does not need a generated `.devcontainer` change for agents tooling.

## Dotfiles

Use VS Code's dotfiles settings when you want personal shell/editor config:

```json
{
  "dotfiles.repository": "your-github-id/your-dotfiles-repo",
  "dotfiles.targetPath": "~/dotfiles",
  "dotfiles.installCommand": "install.sh"
}
```

These settings are user-level settings. They are not committed to the target
repository.

## CLI: adc up

For CLI launches, use `adc up` instead of calling `devcontainer up` directly:

```bash
bin/adc up /path/to/repository
```

To inspect the command without starting a container:

```bash
bin/adc up --dry-run /path/to/repository
```

`adc up` wraps `devcontainer up` and injects:

- `--additional-features` with `ghcr.io/toshikimiyagawa/agents-devcontainer/agents:1`
- a repo-external state volume mounted at `/usr/local/share/agents-devcontainer/state`

## raw devcontainer up limitation

raw devcontainer up does not apply VS Code defaultFeatures.

That means this command starts the repository's normal devcontainer, but does not
inject the agents Feature by itself:

```bash
devcontainer up --workspace-folder /path/to/repository
```

Use `adc up` for CLI launches when you need the same external injection behavior.
Do not replace or shim the upstream `devcontainer` command.

## Repo-clean policy

The target repository must not be modified by external injection.

Do not create or change these files in the target repository:

- `.devcontainer/devcontainer.json`
- `.devcontainer/project-tools.yml`
- `dotfiles/`
- agent config, cache, auth, or state files

Agent state belongs outside the target repository. The initial implementation uses
a named volume mounted at `/usr/local/share/agents-devcontainer/state`.

## Initial support matrix

| Environment | Initial status | Notes |
|---|---:|---|
| Debian/Ubuntu devcontainers | supported | Feature install runs as root and expects Debian-like userspace. |
| Alpine | unsupported | Track separately if needed. |
| Fedora/RHEL | unsupported | Track separately if needed. |
| sudo-less images | unsupported | The initial path assumes normal Dev Container Feature root install. |
| Repositories with existing `.devcontainer` | supported | Use VS Code defaultFeatures or `adc up`. |
| Repositories without `.devcontainer` | use scaffold | The scaffold path remains the simpler new-project flow. |
