#!/usr/bin/env bash
# Scaffold a minimal .devcontainer/ that consumes the agents-devcontainer base image.
#
# Usage:
#   bash scaffold.sh [TARGET_DIR]       # defaults to current directory
#
# To pin a specific version:
#   AGENTS_DEVCONTAINER_TAG=v0.1.0 bash scaffold.sh ~/code/myproject
#
# Remote usage:
#   curl -fsSL https://raw.githubusercontent.com/toshikimiyagawa/agents-devcontainer/main/scaffold.sh | bash
set -euo pipefail

TARGET="${1:-$PWD}"
TAG="${AGENTS_DEVCONTAINER_TAG:-latest}"
DC="$TARGET/.devcontainer"

if [[ -e "$DC" ]]; then
  echo "ERROR: $DC already exists. Move or remove it first." >&2
  exit 1
fi

mkdir -p "$DC/dotfiles/.claude" "$DC/dotfiles/.gemini"

cat > "$DC/devcontainer.json" <<JSON
{
  "name": "$(basename "$TARGET")",

  "image": "ghcr.io/toshikimiyagawa/agents-devcontainer:${TAG}",

  "workspaceMount": "source=\${localWorkspaceFolder},target=/workspace,type=bind,consistency=cached",
  "workspaceFolder": "/workspace",

  "initializeCommand": "mkdir -p \"\${localWorkspaceFolder}/.devcontainer/dotfiles/.claude\" \"\${localWorkspaceFolder}/.devcontainer/dotfiles/.gemini\"",

  "mounts": [
    "source=devcontainer-gh-\${devcontainerId},target=/home/ubuntu/.gh-config,type=volume"
  ],

  "remoteEnv": {
    "GH_CONFIG_DIR": "/home/ubuntu/.gh-config",
    "MISE_TRUSTED_CONFIG_PATHS": "/workspace",
    "GIT_AUTHOR_NAME":     "\${localEnv:GIT_AUTHOR_NAME}",
    "GIT_AUTHOR_EMAIL":    "\${localEnv:GIT_AUTHOR_EMAIL}",
    "GIT_COMMITTER_NAME":  "\${localEnv:GIT_AUTHOR_NAME}",
    "GIT_COMMITTER_EMAIL": "\${localEnv:GIT_AUTHOR_EMAIL}"
  },

  "containerUser": "ubuntu",
  "remoteUser":    "ubuntu",

  "postCreateCommand": "agents-post-create",
  "postStartCommand":  "agents-post-start"
}
JSON

cat > "$DC/.gitignore" <<'GITIGNORE'
# Per-project agent state — keep local, never commit.
dotfiles/.claude/
dotfiles/.gemini/
dotfiles/.config/gh/
dotfiles/.ssh/
GITIGNORE

echo "Scaffolded $DC"
echo ""
echo "Next steps:"
echo "  1. Open $TARGET in VS Code -> 'Dev Containers: Reopen in Container'"
echo "     OR: devcontainer up --workspace-folder $TARGET"
echo "  2. Inside the container, run: gh auth login -p https -h github.com -s repo,read:org -w"
echo "     (token persists across rebuilds via the named volume)"
echo ""
echo "To override dotfiles, drop files into $DC/dotfiles/ (e.g., .zshrc, .tmux.conf, .config/)."
echo "To extend .zshrc rather than replace it: source /opt/agents/dotfiles/.zshrc at the top."
echo "To add extra tools: replace 'image' with 'build' and add a Dockerfile FROM the base image."
