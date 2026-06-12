# Plan: hermes-agent

詳細な手順とコード全文は `docs/superpowers/plans/2026-06-13-hermes-agent.md` を参照。
本ファイルは SDD 契約としての approach / affected files / tradeoffs を記す。

## Approach

`Dockerfile.base` の既存 `USER ubuntu` ブロック（Claude Code を入れている箇所）に、
公式インストーラを叩く `RUN` を 1 行追加する:

```dockerfile
RUN curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup
```

- **per-user**: `USER ubuntu` で実行するため、インストーラは既定の per-user レイアウトを選び、
  コードを `~/.hermes/hermes-agent`、コマンドを `~/.local/bin/hermes` に置く。`dotfiles/.zshrc`
  が `PATH="$HOME/.local/bin:$PATH"` を設定済みなので `hermes` が解決される。Claude Code と同一の
  仕組みで、start-time の `updateRemoteUserUID` による `$HOME` chown でも生き残る。
- **browser 込み**: `--skip-browser` を付けない。`ubuntu` ユーザーは passwordless sudo を持つため、
  インストーラは `npx playwright install --with-deps chromium`（apt system libs + Chromium）まで
  自動で実行する。
- **--skip-setup**: ビルド環境には TTY が無く（`/dev/tty` を開けない）ウィザードは自動スキップされるが、
  意図を明示するため明示付与する。プロバイダ設定はランタイムで `hermes setup`。
- **Node 再利用**: インストーラは `node_satisfies_build`（`^20.19 || >=22.12`）で既存 Node を判定する。
  ベースは NodeSource `setup_20.x`（最新 20.x = 20.19+）なので既存 Node を再利用し、自前 Node を
  入れない。よって `~/.local/bin` への node/npm/npx symlink による既存ツールへの干渉は発生しない。

ドキュメント（README / `.devcontainer/Agents.md`）と LABEL を更新し、grep ベースの bats テストで
配線を検証する。イメージが実際にビルドできるかは CI `build-base-image` ジョブが担保する
（bats ではコンテナを実起動しない）。

## Affected files

| Action | Path | 役割 |
|---|---|---|
| Modify | `.devcontainer/Dockerfile.base` | `USER ubuntu` ブロックに Hermes インストール RUN を追加。LABEL description に "Hermes Agent" を追記 |
| Modify | `README.md` | 同梱エージェント一覧（行 4 / 「特徴」の箇条書き）に Hermes Agent を追記 |
| Modify | `.devcontainer/Agents.md` | 「AI・特定ツール」一覧に `hermes` を追記 |
| Create | `tests/hermes-install.bats` | Dockerfile.base / docs の配線を grep で検証 |

## Tradeoffs / alternatives

- **per-user（採用）vs root FHS**: per-user は Claude Code と一貫し、UID remap で生き残り、dev ユーザー
  自身が `hermes update` で自己更新できる。root FHS（`/usr/local/bin/hermes`）は Codex/Gemini と同列に
  なるが、`ubuntu` ユーザーから自己更新できず、UID remap の恩恵も受けにくいため不採用。
- **browser 込み（採用、ユーザー選択）**: 数百 MB のイメージ増・ビルド時間増を許容し、ブラウザ自動化を
  すぐ使える状態にする。`--skip-browser` 版より重いが、利用者の手作業（`npx playwright install`）が不要。
- **既存 Node 再利用（採用）vs Node 22 への bump**: bump すれば全ツールが Node 22 LTS に揃うが、
  gemini-cli/codex への影響評価が必要で scope 拡大。現行 Node 20(≥20.19) で要件を満たすため bump しない。
  将来ベースが Node <20.19 を積んだ場合はインストーラが自前 Node 22 を `~/.hermes/node` に入れ
  `~/.local/bin` へ symlink する（PATH 先頭のため既存 node を shadow するが、いずれも Node 22 で動作可）。
- **テスト戦略**: bats はコンテナをビルド/実起動しないため、配線（Dockerfile/docs の内容）のみ grep で検証し、
  実インストールの成否は CI `build-base-image`（PR の amd64 build-only）を authoritative とする
  （dotfiles-sync spec の「Dockerfile.base レビュー」前例に倣う）。

## Out of scope

- Hermes のプロバイダ/モデル/API キー事前構成。
- Node の bump、既存エージェント・dotfiles・scaffold の変更。
- コンテナ実起動の E2E テスト。
