# Hermes Agent — Design Notes (brainstorming output)

日付: 2026-06-13
対応 spec: `specs/hermes-agent/`

## 背景 / きっかけ

ユーザーから「open code を削除して hermes agent を入れて」という依頼。調査の結果:

- リポジトリ内に **opencode は存在しない**（`grep -rin opencode` が 0 件）。現在同梱の AI エージェントは
  Claude Code / Gemini CLI / Codex CLI の 3 つ（`Dockerfile.base:42,94`）。
- ユーザー確認の結果、**削除は行わない**（誤認だった）。
- 「hermes agent」は **NousResearch の Hermes Agent**（github.com/NousResearch/hermes-agent）。
  自己改善型の自律 AI エージェントで、CLI / TUI / メッセージングゲートウェイ / Desktop を持つ。
  永続メモリ・スキル学習・40+ ツール・マルチプロバイダ対応。

## 決定事項（ユーザー合意）

1. **削除なし** — opencode は元々存在しないため、何も削除しない。
2. **インストール先 = per-user**（`~/.local/bin`、Claude Code と同じ）。
3. **ブラウザツール（Playwright/Chromium）を含める**。
4. **SDD フルプロセス**（spec → plan → tasks、人間承認後に凍結 → 実装）。

## インストーラ調査（`https://hermes-agent.nousresearch.com/install.sh`）

- 非対話フラグ: `--skip-setup`（プロバイダ設定ウィザード省略）, `--skip-browser`/`--no-playwright`,
  `--no-skills`。`bash -s -- <flags>` でパイプ実行に渡せる。
- 非対話検知: stdin が TTY でなければ `IS_INTERACTIVE=false`。setup ウィザードは `/dev/tty` を
  open 試行し、Docker build では開けず自動スキップ。
- per-user レイアウト: コード `~/.hermes/hermes-agent`、コマンド `~/.local/bin/hermes`
  （root 実行時は `/usr/local/lib/hermes-agent` + `/usr/local/bin/hermes` の FHS）。
- ブラウザ: apt 系かつ `sudo -n true` 可なら `npx playwright install --with-deps chromium` を実行
  （system libs + Chromium）。`ubuntu` ユーザーは passwordless sudo を持つので build 中に通る。
- Node: `node_satisfies_build`（`^20.19 || >=22.12`）で既存 Node を判定。満たせば自前 Node を入れない。
  ベースは NodeSource `setup_20.x`（最新 20.x = 20.19+）→ 既存 Node を再利用。

## 採用しなかった代替案

- **root FHS インストール**: Codex/Gemini と同列になるが、dev ユーザーが `hermes update` で
  自己更新できず、UID remap の恩恵も薄い → per-user を採用。
- **`--skip-browser` でブラウザ省略**: イメージは軽くなるが、利用者に手作業が必要 → ユーザー選択により含める。
- **Node 22 への bump**: 全ツールを Node 22 LTS に統一できるが、既存 gemini-cli/codex への影響評価が必要で
  scope 拡大。現行 Node 20(≥20.19) で要件充足のため見送り。

## 検証戦略

bats はコンテナをビルド/実起動しないため、Dockerfile.base と docs の **配線を grep で検証**する
`tests/hermes-install.bats` を追加。実インストールの成否は CI `build-base-image`（PR の amd64
build-only ジョブ）を authoritative とする（dotfiles-sync spec の AC 検証前例に倣う）。
