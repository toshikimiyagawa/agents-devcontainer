# Design: Codex CLI Config Persistence

**Date:** 2026-05-30  
**Feature:** codex-persist  
**Tier:** 1 (small, localized change)

## Intent

Persist OpenAI Codex CLI (`~/.codex/`) configuration and credentials across devcontainer rebuilds, following the same dotfiles symlink pattern used for `.claude` and `.gemini`.

## Acceptance Criteria

- After a devcontainer rebuild, `~/.codex/` exists and points to `/workspace/.devcontainer/dotfiles/.codex/`.
- Credentials and config written by the Codex CLI survive a rebuild without any user action.
- Nothing under `.devcontainer/dotfiles/.codex/` is committed to git.
- The `agents-post-create` log reports `linked .codex -> ...` on first create.

## Design

Follow the existing `.claude` / `.gemini` pattern exactly:

### Files changed

| File | Change |
|---|---|
| `.devcontainer/dotfiles/.codex/.gitignore` | New file: ignore `*`, keep `.gitignore` |
| `.devcontainer/.gitignore` | Add `dotfiles/.codex/` |
| `.devcontainer/scripts/agents-post-create` | Add `.codex` to the for loop (section 2) |
| `.devcontainer/devcontainer.json` | Add `dotfiles/.codex` to `initializeCommand` mkdir |

### How it works

1. `initializeCommand` runs `mkdir -p .devcontainer/dotfiles/.codex` before the container starts.
2. `agents-post-create` section 2 symlinks `~/.codex → /workspace/.devcontainer/dotfiles/.codex`.
3. `.devcontainer/.gitignore` prevents credentials from being committed.
4. The `.gitignore` inside the directory keeps the directory itself tracked (so the symlink target always exists).

## Out of scope

- API key forwarding via `remoteEnv` (user can set `OPENAI_API_KEY` in host shell if preferred).
- Named Docker volume approach (not needed; workspace bind mount is sufficient).
