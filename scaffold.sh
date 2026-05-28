#!/usr/bin/env bash
# Scaffold a minimal .devcontainer/ that consumes the agents-devcontainer base image,
# and optionally set up ai-sdd-guide (Spec-Driven Development) via git submodule.
#
# Usage:
#   bash scaffold.sh [TARGET_DIR]       # defaults to current directory
#
# To pin a specific version:
#   AGENTS_DEVCONTAINER_TAG=v0.1.0 bash scaffold.sh ~/code/myproject
#
# To skip SDD setup:
#   AGENTS_DEVCONTAINER_SDD=0 bash scaffold.sh ~/code/myproject
#
# Remote usage:
#   curl -fsSL https://raw.githubusercontent.com/toshikimiyagawa/agents-devcontainer/main/scaffold.sh | bash
set -euo pipefail

TARGET="${1:-$PWD}"
TAG="${AGENTS_DEVCONTAINER_TAG:-latest}"
DC="$TARGET/.devcontainer"
SDD="${AGENTS_DEVCONTAINER_SDD:-1}"
SDD_URL="${AGENTS_SDD_GUIDE_URL:-https://github.com/toshikimiyagawa/ai-sdd-guide.git}"
SDD_DIR="$TARGET/vendor/ai-sdd-guide"

# --- devcontainer setup --------------------------------------------------------

if [[ -e "$DC" ]]; then
  echo "SKIP: $DC already exists. Skipping devcontainer setup." >&2
else
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

# --- SDD (ai-sdd-guide) setup -------------------------------------------------

if [[ "$SDD" == "0" ]]; then
  echo "SKIP: SDD setup disabled (AGENTS_DEVCONTAINER_SDD=0)." >&2
elif ! git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "SKIP: $TARGET is not a git repository. SDD setup requires git." >&2
  echo "      Run 'git init' first, then re-run this script to set up SDD." >&2
else
  # Submodule
  if [[ -e "$SDD_DIR" ]]; then
    echo "SKIP: $SDD_DIR already exists. Skipping submodule add." >&2
  else
    git -C "$TARGET" submodule add "$SDD_URL" vendor/ai-sdd-guide
    echo "Added ai-sdd-guide submodule at vendor/ai-sdd-guide"
  fi

  # Integration files (copy only if not already present)
  INTEGRATION="$SDD_DIR/integration"
  if [[ -d "$INTEGRATION" ]]; then
    if [[ ! -f "$TARGET/CLAUDE.md" ]] && [[ -f "$INTEGRATION/CLAUDE.md.example" ]]; then
      cp "$INTEGRATION/CLAUDE.md.example" "$TARGET/CLAUDE.md"
      echo "Copied CLAUDE.md"
    fi

    if [[ ! -f "$TARGET/AGENTS.md" ]] && [[ -f "$INTEGRATION/AGENTS.md.example" ]]; then
      cp "$INTEGRATION/AGENTS.md.example" "$TARGET/AGENTS.md"
      echo "Copied AGENTS.md"
    fi

    if [[ ! -f "$TARGET/.claude/settings.json" ]] && [[ -f "$INTEGRATION/settings.json.example" ]]; then
      mkdir -p "$TARGET/.claude"
      cp "$INTEGRATION/settings.json.example" "$TARGET/.claude/settings.json"
      echo "Copied .claude/settings.json"
    fi

    if [[ ! -d "$TARGET/.claude/agents" ]] && [[ -d "$INTEGRATION/agents" ]]; then
      mkdir -p "$TARGET/.claude"
      cp -r "$INTEGRATION/agents" "$TARGET/.claude/agents"
      echo "Copied .claude/agents/"
    fi

    if [[ ! -f "$TARGET/.github/workflows/sdd-check.yml" ]] && [[ -f "$INTEGRATION/ci/sdd-check.yml" ]]; then
      mkdir -p "$TARGET/.github/workflows"
      cp "$INTEGRATION/ci/sdd-check.yml" "$TARGET/.github/workflows/sdd-check.yml"
      echo "Copied .github/workflows/sdd-check.yml"
    fi
  fi

  echo ""
  echo "SDD (ai-sdd-guide) setup complete."
fi

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
