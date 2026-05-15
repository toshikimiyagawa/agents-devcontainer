#!/usr/bin/env bash
# Runs on every container start (postStartCommand).
# Writes to /etc/gitconfig (system-level) so settings survive across all repos
# without touching ~/.gitconfig, which is not bind-mounted.
set -euo pipefail

# --- safe.directory (idempotent) ---
git config --system --get-all safe.directory 2>/dev/null | grep -qx /workspace \
  || sudo git config --system --add safe.directory /workspace

# --- credential helper ---
# Wipe the section first so repeated starts don't accumulate duplicate entries,
# then register the in-container gh binary.
sudo git config --system --remove-section credential.https://github.com 2>/dev/null || true
sudo git config --system credential.https://github.com.helper '!/usr/bin/gh auth git-credential'
sudo git config --system --remove-section credential.https://gist.github.com 2>/dev/null || true
sudo git config --system credential.https://gist.github.com.helper '!/usr/bin/gh auth git-credential'

# --- git identity ---
# Prefer host-forwarded env vars (set via remoteEnv in devcontainer.json).
# Fall back to gh API on first run when env is empty but gh is already authenticated.
name="${GIT_AUTHOR_NAME:-}"
email="${GIT_AUTHOR_EMAIL:-}"
if [[ -z "$name" || -z "$email" ]] && gh auth status >/dev/null 2>&1; then
  [[ -z "$name"  ]] && name="$(gh api user --jq .name  2>/dev/null || true)"
  [[ -z "$email" ]] && email="$(gh api user --jq .email 2>/dev/null || true)"
fi
[[ -n "$name"  ]] && sudo git config --system user.name  "$name"
[[ -n "$email" ]] && sudo git config --system user.email "$email"

# --- sensible git defaults ---
sudo git config --system init.defaultBranch main
sudo git config --system pull.rebase true
