# Dotfiles Sync Design

## Goal

Let consuming projects automatically receive upstream dotfiles improvements for files
they have **not** overridden, while never clobbering files they **have** customized.
Also clarify the dotfiles lifecycle in the docs (current README is partially stale).

Addresses issue #25.

## Background

After `scaffold.sh` runs in a consuming project:

- Base dotfiles (`.zshrc`, `.tmux.conf`, `.config/*`) are copied **once** from
  `vendor/agents-devcontainer/dotfiles/` into the project's `dotfiles/` and force-committed.
- `agents-post-create` symlinks `~/<name>` → `/workspace/dotfiles/<name>` on container create.
- Later updates in `vendor/agents-devcontainer/dotfiles/*` (after a submodule bump) are
  **never** reflected — the initial copy is the end of the story.

Problems:

1. To adopt an upstream dotfile improvement, users must manually copy/merge from the submodule.
2. There is no way to tell which project files are intentional overrides vs untouched copies.
3. README still references removed paths (`.devcontainer/dotfiles/`, `/opt/agents/dotfiles/.zshrc`)
   from before the dotfiles-unification change, and does not document the update flow.

## Proposed Design

### Managed base set (derived, not hardcoded)

The set of files the sync manages is computed dynamically as every regular file under the
upstream `dotfiles/` directory, **excluding** runtime/personal entries:

- Excluded: `.claude/`, `.gemini/`, `.codex/`, `.ssh/`, `.zsh_history`, `.gitignore`

Everything else (currently `.zshrc`, `.tmux.conf`, `.config/starship.toml`,
`.config/nvim/init.lua`, `.config/nvim/lazy-lock.json`, `.config/lazygit/config.yml`,
`.config/yazi/yazi.toml`, `.config/yazi/keymap.toml`, `.config/git/ignore`) is a managed
base file. New base files added upstream are picked up automatically — `.config/` is tracked
per-file, so editing one file there does not block updates to its siblings.

### Provenance manifest

`dotfiles/.agents-dotfiles.lock` — committed in the consuming project (force-added, because
`dotfiles/.gitignore` is `*` + `!.gitignore`). Format: one line per managed path:

```
<relpath> <sha256>
```

The recorded hash is the **upstream version last synced** (the baseline). A project file is
considered *not overridden* when its current hash equals the manifest baseline.

### Sync script `agents-dotfiles-sync`

Baked into the image at `/usr/local/bin/agents-dotfiles-sync` (source:
`.devcontainer/scripts/agents-dotfiles-sync`), following the `agents-tools-install` pattern.

Paths are overridable via env so tests can point at fixtures:

- `UPSTREAM_DIR` (default `/workspace/vendor/agents-devcontainer/dotfiles`)
- `PROJECT_DIR` (default `/workspace/dotfiles`)
- manifest lives at `$PROJECT_DIR/.agents-dotfiles.lock`

Behavior: idempotent; if `UPSTREAM_DIR` is absent or empty, log `skip` and exit 0 (non-fatal).

#### Per-file 3-way decision

For each managed path `p`, with `base` = manifest hash, `proj` = hash of `$PROJECT_DIR/p`,
`up` = hash of `$UPSTREAM_DIR/p`:

| Condition | Action |
|---|---|
| `proj == base` and `up != base` (untouched, upstream advanced) | **auto-update**: copy up→proj, set manifest = up |
| `proj == base` and `up == base` | no-op |
| `proj != base` and `up == base` (overridden, upstream unchanged) | keep project file |
| `proj != base` and `up != base` and `proj == up` | set manifest = up (already reconciled, no warning) |
| `proj != base` and `up != base` and `proj != up` | **conflict**: skip + warn |
| `p` not in manifest, `proj` absent (new upstream file) | copy up→proj, set manifest = up |
| `p` not in manifest, `proj == up` | set manifest = up (record baseline only) |
| `p` not in manifest, `proj != up` | **conflict**: skip + warn (existing-project migration) |
| `proj` absent (but in manifest) / `up` absent / other | skip + warn (non-destructive) |

The conflict cases are non-destructive: the project file is never overwritten by the sync.

#### Conflict output

On a conflict, the sync:

- Leaves the project file untouched.
- Writes `$PROJECT_DIR/<relpath>.agents-upstream` (the current upstream version) next to the
  file so the user can `diff`. These sidecars match `dotfiles/.gitignore`'s `*`, so they never
  show up in `git status`. Each run overwrites the sidecar; resolving the conflict removes it
  on the next run.
- Collects all conflicted paths and prints a single "needs manual review" summary at the end.

#### Resolution command

`agents-dotfiles-sync --accept <path>...` advances the manifest baseline for the given paths
to the current upstream hash, **without** changing the project file. Meaning: "I reviewed this
upstream change and intend to keep my local override." This stops the recurring warning while
preserving the customization. The default (no args) runs the full sync described above.

### `agents-post-create` integration

Invoke `agents-dotfiles-sync` near the top of `agents-post-create` (before the symlink steps),
guarded by `command -v` and non-fatal. On every container create/rebuild, untouched base files
fast-forward to upstream and surface as a normal `git diff` in `dotfiles/`; conflicts are warned.

### `scaffold.sh`

After the initial base-file copy, seed `dotfiles/.agents-dotfiles.lock` with the upstream
hashes of the copied files, then `git add -f` and commit it alongside the base files. New
projects therefore start with a correct baseline so the first post-bump sync behaves cleanly.

### Documentation (README)

Rewrite the "dotfiles のカスタマイズ" section to document the full lifecycle and fix stale paths:

- **Source of truth**: `vendor/agents-devcontainer/dotfiles/*` (upstream base), copied into the
  project `dotfiles/` at scaffold time.
- **Initial copy timing**: `scaffold.sh` copies + force-commits base files and seeds the manifest.
- **`agents-post-create` behavior**: symlinks `~/<name>` → `/workspace/dotfiles/<name>`.
- **Update procedure** after `git submodule update --remote vendor/agents-devcontainer`: on the
  next rebuild, `agents-dotfiles-sync` auto-updates non-overridden files (visible as a `git diff`
  to commit) and warns on overridden-and-changed files; `--accept` acknowledges a conflict while
  keeping the local override.
- **How override works**: simply editing a base file diverges it from the manifest baseline, which
  protects it from future auto-updates.
- Remove stale references to `.devcontainer/dotfiles/` (line 204) and `/opt/agents/dotfiles/.zshrc`
  (lines 208, 219).

## Acceptance Criteria

1. `agents-dotfiles-sync` exists, is executable, and is baked into the image at
   `/usr/local/bin/agents-dotfiles-sync`.
2. When a managed file is unchanged from the manifest baseline and upstream has advanced, the sync
   overwrites the project file with the upstream version and updates the manifest hash.
3. When a managed file has been overridden (differs from baseline) and upstream has also changed,
   the sync leaves the project file untouched, writes a `<relpath>.agents-upstream` sidecar, and
   reports the path in a conflict summary. The sync still exits 0 (so it is safe to call from
   `agents-post-create` under `set -e`); conflicts are advisory warnings, not failures.
4. When a managed file is overridden but upstream is unchanged, the sync makes no change.
5. A new upstream file not present in the project is copied in and recorded in the manifest.
6. `agents-dotfiles-sync --accept <path>` advances the manifest baseline for `<path>` to the
   current upstream hash without modifying the project file, and the subsequent run produces no
   conflict warning for that path.
7. The sync exits 0 and changes nothing when `UPSTREAM_DIR` is missing.
8. The managed set is derived from upstream and excludes `.claude/`, `.gemini/`, `.codex/`,
   `.ssh/`, `.zsh_history`, `.gitignore`.
9. `agents-post-create` invokes `agents-dotfiles-sync` (non-fatal).
10. `scaffold.sh` seeds `dotfiles/.agents-dotfiles.lock` with upstream hashes and force-commits it.
11. README documents source of truth, initial copy timing, `agents-post-create` behavior, the
    post-bump update procedure, and how overrides are protected; no stale `.devcontainer/dotfiles/`
    or `/opt/agents/dotfiles/` references remain.
12. `bats tests/` passes, including a new `tests/dotfiles-sync.bats` covering criteria 2–8.
