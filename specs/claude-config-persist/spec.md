# Spec: claude-config-persist

## Intent

devcontainer を `devcontainer up --remove-existing-container` で作り直しても、Claude Code の
ログイン/オンボーディング状態が保持されるようにする。

現状は `~/.claude` ディレクトリのみを workspace 配下へ symlink して永続化しているが、
`$HOME` 直下の `~/.claude.json`（`oauthAccount`・`hasCompletedOnboarding`・trust 状態など）は
symlink 対象外で rebuild ごとに消える。これが再ログイン/再オンボーディングの原因。

対応方針: `remoteEnv` に `CLAUDE_CONFIG_DIR=/home/ubuntu/.claude` を追加し、既存の
`~/.claude → /workspace/dotfiles/.claude`（永続バインドマウント）symlink 経由で Claude の
config（`.claude.json` を含む）を永続ディレクトリへ集約する。

issue #31 に対応する。Tier 1（lightweight spec のみ。plan/tasks は省略）。

## Acceptance Criteria

1. `scaffold/devcontainer.base.json` の `remoteEnv` に
   `"CLAUDE_CONFIG_DIR": "/home/ubuntu/.claude"` が含まれる。
2. `.devcontainer/devcontainer.json`（dogfood）の `remoteEnv` に
   `"CLAUDE_CONFIG_DIR": "/home/ubuntu/.claude"` が含まれる。
3. `scaffold.sh` + `merge.sh` で消費プロジェクトをセットアップすると、生成された
   `.devcontainer/devcontainer.json` の `.remoteEnv.CLAUDE_CONFIG_DIR` が
   `"/home/ubuntu/.claude"` になる（`tests/scaffold.bats` で jq 検証）。
4. dogfood `.devcontainer/devcontainer.json` に `CLAUDE_CONFIG_DIR` が存在する
   ことをテストで検証する（JSONC のため grep ベース）。
5. `bats tests/` が全て通る。
6. 手動検証ゲート（実機）: `devcontainer up --remove-existing-container` の前後で、
   Claude の config（`.claude.json` 相当）が `/workspace/dotfiles/.claude/` 配下に存在し、
   Claude の再ログイン/再オンボーディングが発生しない。既存の `.credentials.json` の
   永続化も壊れていない。
   - ※ `CLAUDE_CONFIG_DIR` が `.claude.json` を当該ディレクトリへ移設する点はドキュメント
     未明記のため本検証に含める。移設されないと判明した場合は spec に立ち返り、`.claude.json`
     を永続化する fallback を追補する（実装中の独断追加はしない）。

## Out of Scope

- `.gemini` / `.codex` の同等対応。
- `CLAUDE_CODE_OAUTH_TOKEN`（`claude setup-token`）方式での認証永続化。
- 既存の永続化機構（gh named volume、ssh のホストマウントコピー）の変更。
- `agents-post-create` 等のスクリプト変更（symlink は既存のものを利用）。
