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
ADC_URL="${AGENTS_DEVCONTAINER_URL:-https://github.com/toshikimiyagawa/agents-devcontainer.git}"
ADC_DIR="$TARGET/vendor/agents-devcontainer"

# --- agents-devcontainer submodule (git only) ---------------------------------

if git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ -e "$ADC_DIR" ]]; then
    echo "SKIP: $ADC_DIR already exists. Skipping agents-devcontainer submodule add." >&2
  else
    git -C "$TARGET" submodule add "$ADC_URL" vendor/agents-devcontainer
    echo "Added agents-devcontainer submodule at vendor/agents-devcontainer"
  fi
fi

# --- devcontainer setup -------------------------------------------------------

if [[ -e "$DC" ]]; then
  echo "SKIP: $DC already exists. Skipping devcontainer setup." >&2
else
  mkdir -p "$DC/dotfiles/.claude" "$DC/dotfiles/.gemini"

  # Generate devcontainer.project.json (project-specific overrides)
  if [[ "$TAG" != "latest" ]]; then
    cat > "$DC/devcontainer.project.json" <<JSON
{
  "name": "$(basename "$TARGET")",
  "image": "ghcr.io/toshikimiyagawa/agents-devcontainer:${TAG}"
}
JSON
  else
    cat > "$DC/devcontainer.project.json" <<JSON
{
  "name": "$(basename "$TARGET")"
}
JSON
  fi

  # Generate devcontainer.json: via merge.sh if submodule is present, else static fallback
  if [[ -x "$ADC_DIR/scaffold/merge.sh" ]]; then
    "$ADC_DIR/scaffold/merge.sh" "$TARGET"
  else
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
  fi

  cat > "$DC/.gitignore" <<'GITIGNORE'
# Per-project agent state — keep local, never commit.
dotfiles/.claude/
dotfiles/.gemini/
dotfiles/.config/gh/
dotfiles/.ssh/
dotfiles/.zsh_history
GITIGNORE

  cat > "$DC/project-tools.yml" << 'TOOLS'
# Project-specific tools — installed automatically on devcontainer creation.
# Uncomment or add entries as needed. Versions are optional (omit for latest).
#
# apt:
#   - postgresql-client
#   - redis-tools
#
# pip:
#   - awscli==1.32.0
#   - ruff
#
# npm:
#   - prettier
#   - eslint@9
#
# binary:
#   - name: terraform
#     url: "https://releases.hashicorp.com/terraform/1.8.0/terraform_1.8.0_linux_${ARCH}.zip"
#   # Available variables: ${ARCH} (amd64|arm64), ${ARCH_ALT} (x86_64|aarch64)
#
# post_install:
#   - name: setup config
#     run: |
#       mkdir -p ~/.config/mytool
#       cp .devcontainer/config/mytool.toml ~/.config/mytool/
#
# For complex setup, you can also create .devcontainer/post-install.sh (must be executable).
TOOLS

  echo "Scaffolded $DC"
fi

echo ""
echo "Next steps:"
echo "  1. Open $TARGET in VS Code -> 'Dev Containers: Reopen in Container'"
echo "     OR: devcontainer up --workspace-folder $TARGET"
echo "  2. Inside the container, run: gh auth login -p https -h github.com -s repo,read:org -w"
echo "     (token persists across rebuilds via the named volume)"
echo ""
echo "To update devcontainer config from agents-devcontainer:"
echo "  git submodule update --remote vendor/agents-devcontainer"
echo "  vendor/agents-devcontainer/scaffold/merge.sh"
echo ""
echo "To override dotfiles, drop files into $DC/dotfiles/ (e.g., .zshrc, .tmux.conf, .config/)."
echo "To extend .zshrc rather than replace it: source /opt/agents/dotfiles/.zshrc at the top."
echo "To add extra tools: replace 'image' with 'build' and add a Dockerfile FROM the base image."
