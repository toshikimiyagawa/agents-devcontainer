# Design: claude-config-persist

- Date: 2026-06-11
- Issue: #31
- Tier: 1（軽量 spec のみ。plan/tasks は省略）

## 背景・問題

devcontainer を `devcontainer up --remove-existing-container`（= `docker rm -f` 相当）で
作り直すと、Claude Code の再ログイン/再オンボーディングが時々発生する。

現状の永続化は `~/.claude`「ディレクトリ」を workspace 配下へ symlink することで実現している:

- `agents-post-create:34-39` — `~/.claude` → `/workspace/dotfiles/.claude`
  （バインドマウント＝ホスト上なのでコンテナ削除後も残る）
- これにより `~/.claude/.credentials.json`（OAuth トークン本体）や `projects/` は永続化される

しかし Claude Code はトップレベルに **`~/.claude.json` という別ファイル**も使う。これは
`~/.claude` ディレクトリの「中」ではなく `$HOME` 直下の兄弟ファイルで、**symlink 対象外**。

```
$HOME/.claude        → /workspace/dotfiles/.claude   （永続）
$HOME/.claude.json   → コンテナの ephemeral 層（rebuild で消える）★
```

`~/.claude.json` には `oauthAccount`・`hasCompletedOnboarding`・プロジェクトの trust 状態
などが入る。トークン本体（`.credentials.json`）は永続側に残るため毎回ではなく**時々**、
`.claude.json` 欠落時に Claude がログイン状態を見失う／再オンボーディングを促すと考えられる。

## 根本原因

永続化対象が `~/.claude` ディレクトリのみで、`$HOME` 直下の `~/.claude.json` が
永続化経路に含まれていない。

## 検討した方針

- **A（採用）: `CLAUDE_CONFIG_DIR` を永続ディレクトリへ向ける。**
  `remoteEnv` に `CLAUDE_CONFIG_DIR=/home/ubuntu/.claude` を追加。既存の
  `~/.claude → /workspace/dotfiles/.claude` symlink 経由で、`.credentials.json` に加え
  `.claude.json` も永続側へ集約される想定。env 1個の最小変更で、post-create の変更は不要。
  既存の `GH_CONFIG_DIR`（gh の config dir を env で移設）と同じパターン。
- **B（不採用）: `~/.claude.json` を直接 symlink する。**
  Claude は `.claude.json` を atomic rename（temp→rename）で書き換えるため、symlink が
  実ファイルに置換され永続が外れる懸念。脆い。
- **C（不採用）: `CLAUDE_CODE_OAUTH_TOKEN`（`claude setup-token` の1年トークン）を env forward。**
  認証は決定的になるがトークン管理の手間があり、inference 専用（Remote Control 不可）。
  個人 dev 用途には重い。

## 設計詳細

変更ファイル（最小差分）:

1. `scaffold/devcontainer.base.json` の `remoteEnv` に
   `"CLAUDE_CONFIG_DIR": "/home/ubuntu/.claude"` を追加（消費プロジェクト向け）。
2. `.devcontainer/devcontainer.json` の `remoteEnv` に同じキーを追加＋理由コメント（dogfood）。

post-create やスクリプトの変更は不要（symlink は既存のものをそのまま利用）。

## 根拠（調査結果）

公式ドキュメント（code.claude.com/docs/en/authentication）で確認:

> If you've set the `CLAUDE_CONFIG_DIR` environment variable on Linux or Windows,
> the `.credentials.json` file lives under that directory instead.

- `CLAUDE_CONFIG_DIR` は実装済みで、`.credentials.json` の移設は公式に確認できた。
- ただし `.claude.json` も同ディレクトリへ移設されるかはドキュメント未明記。
  → 実装フェーズで実機検証する（下記の手動受け入れ基準）。移設されないと判明した場合は
  spec に立ち返り fallback を追補する。

## テスト

- `tests/scaffold.bats`: 生成された `devcontainer.json` の
  `.remoteEnv.CLAUDE_CONFIG_DIR == "/home/ubuntu/.claude"` を jq で検証（消費プロジェクト経路）。
- dogfood `.devcontainer/devcontainer.json` は JSONC（コメント有）なので
  grep で `CLAUDE_CONFIG_DIR` の存在を検証。

## スコープ外

- `.gemini`/`.codex` の同等対応。
- `CLAUDE_CODE_OAUTH_TOKEN` 方式。
- 既存の永続化（gh named volume / ssh コピー）の変更。
