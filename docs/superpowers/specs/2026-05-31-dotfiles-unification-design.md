# Dotfiles Unification Design

## Goal

Unify dotfiles management under `/workspace/dotfiles/` with a gitignore-by-default model. Remove the `/opt/agents/dotfiles/` baked fallback from the base image.

## Background

Currently dotfiles exist in two places:

| Path | Role |
|---|---|
| `/workspace/.devcontainer/dotfiles/` | Project overrides (git-tracked) |
| `/opt/agents/dotfiles/` | Baked image defaults (root-owned, read-only) |

`agents-post-create` layers these with a fallback: workspace takes precedence, else `/opt/agents`. This causes confusion:
- Editing `~/.tmux.conf` inside the container fails with a permission error when the symlink resolves to `/opt/agents` (root-owned 644).
- Two sources of truth make it unclear which version is active.
- After editing workspace dotfiles, users must know to run `agents-post-create` or manually fix symlinks.

## Proposed Design

### Directory structure

```
/workspace/
  dotfiles/
    .gitignore        # tracked: `*\n!.gitignore`
    .zshrc            # force-committed base
    .tmux.conf        # force-committed base
    .config/          # force-committed base (gh/ excluded)
    .ssh/             # gitignored — personal keys and config
    .claude/          # gitignored — runtime state
    .gemini/          # gitignored — runtime state
    .codex/           # gitignored — runtime state
    .zsh_history      # gitignored — runtime state
```

`/workspace/.devcontainer/dotfiles/` is removed. `.devcontainer/.gitignore` no longer needs dotfiles entries.

### gitignore model

`dotfiles/.gitignore` contains `*` and `!.gitignore`. All files are ignored by default. Base dotfiles are committed once with `git add -f`. After the initial commit, git tracks them normally — changes show in `git status` and `git diff`. Personal/local files added to `dotfiles/` (SSH keys, local overrides) remain silently untracked.

### `agents-post-create`

Remove `BAKED` variable and the entire fallback logic. `PROJECT` changes to `/workspace/dotfiles`. `link_one` checks only `$PROJECT`:

```bash
PROJECT="/workspace/dotfiles"

link_one() {
  local name="$1"
  if [[ ! -e "$PROJECT/$name" ]]; then
    log "skip $name (no source)"; return 0
  fi
  rm -rf "$HOME/$name"
  ln -sfn "$PROJECT/$name" "$HOME/$name"
  log "linked $name -> $PROJECT/$name"
}
```

Runtime state dirs (`.claude`, `.gemini`, `.codex`) are created inside `$PROJECT` if missing, then symlinked to `$HOME`. SSH is copied from `$PROJECT/.ssh` with correct permissions.

### `devcontainer.json`

`initializeCommand` creates state dirs in the new location:

```
mkdir -p "${localWorkspaceFolder}/dotfiles/.claude" \
         "${localWorkspaceFolder}/dotfiles/.gemini" \
         "${localWorkspaceFolder}/dotfiles/.codex"
```

### `Dockerfile.base`

Remove the `COPY` of dotfiles to `/opt/agents/dotfiles/` and the associated `RUN` (chown/chmod). The three runtime scripts (`agents-post-create`, `agents-post-start`, `agents-tools-install`) remain baked into `/usr/local/bin/`.

### `scaffold.sh`

For new consuming projects, create `dotfiles/` at the project root (not inside `.devcontainer/`), copy base dotfiles from `vendor/agents-devcontainer/dotfiles/`, and force-commit them:

```bash
DOTFILES="$TARGET/dotfiles"
mkdir -p "$DOTFILES/.claude" "$DOTFILES/.gemini" "$DOTFILES/.codex" "$DOTFILES/.ssh"
printf '*\n!.gitignore\n' > "$DOTFILES/.gitignore"
cp "$ADC_DIR/dotfiles/.zshrc"     "$DOTFILES/.zshrc"
cp "$ADC_DIR/dotfiles/.tmux.conf" "$DOTFILES/.tmux.conf"
cp -r "$ADC_DIR/dotfiles/.config" "$DOTFILES/.config"
git -C "$TARGET" add -f "$DOTFILES/.zshrc" "$DOTFILES/.tmux.conf" "$DOTFILES/.config"
```

Generated `devcontainer.json` and `.devcontainer/.gitignore` are updated to remove all `dotfiles/` references.

## Acceptance Criteria

1. Inside the container, `~/.zshrc` and `~/.tmux.conf` symlink to `/workspace/dotfiles/` (not `/opt/agents/`).
2. `/workspace/dotfiles/.tmux.conf` is editable by the `ubuntu` user without `sudo`.
3. `git status` does not show `.claude/`, `.gemini/`, `.codex/`, `.ssh/`, `.zsh_history` as untracked.
4. `git add -f dotfiles/.zshrc` succeeds (gitignore is set up correctly).
5. `/opt/agents/dotfiles/` does not exist in the built image.
6. `scaffold.sh` creates `dotfiles/` at the project root with `.gitignore`, `.zshrc`, `.tmux.conf`, `.config/` committed.
7. All existing `scaffold.bats` tests pass after the change.
