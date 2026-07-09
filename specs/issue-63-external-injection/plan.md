# Plan: 既存devcontainer外部注入

## アプローチ

既存 scaffold 方式を変更せず、外部注入方式を追加する。VS Code は `dev.containers.defaultFeatures` による Dev Container Feature 注入、CLI は `adc up` wrapper による `--additional-features` 注入を正式経路にする。

初期実装は「repo を汚さない外部注入経路の成立」を優先する。既存 base image に含まれる全ツールの完全再現、非Debian対応、OCI publish 自動化は後続に分離する。

## 影響範囲 / 主要ファイル

- `features/agents/devcontainer-feature.json` — agents Feature の metadata を定義する。
- `features/agents/install.sh` — Debian/Ubuntu 系 container に最小 runtime scripts と導線を配置する。
- `features/agents/scripts/agents-post-create` — Feature 注入時の post-create 処理。repo 外 state を使い、対象 repo に state を作らない。
- `features/agents/scripts/agents-post-start` — Feature 注入時の post-start 処理。safe.directory や credential helper など、repo を汚さない範囲に限定する。
- `bin/adc` — `adc up [workspace]` wrapper。`devcontainer up` に `--additional-features` と repo 外 mount を渡す。
- `docs/external-injection.md` — VS Code `Reopen in Container` と `adc up` の利用手順、制約、対応 matrix を記載する。
- `README.md` — 既存 scaffold 方式と外部注入方式の使い分けを短く案内する。
- `tests/feature-agents.bats` — Feature metadata と install script の静的検証。
- `tests/adc-up.bats` — `adc up` の引数生成と repo-clean 挙動の検証。
- `tests/external-injection-docs.bats` — docs に必須制約が書かれていることを検証。
- `tests/scaffold.bats`, `tests/merge.bats` — 既存回帰として引き続き通す。

## 実装順序

1. #65: Feature 骨格を追加する。
2. #66: `adc up` wrapper を追加する。
3. #67: 利用手順と制約を文書化する。
4. #68: 最小検証と回帰テストを整備する。

この順序は依存関係に沿っている。`adc up` は Feature ID と想定 mount を必要とし、docs と検証は Feature/wrapper の仕様を参照する。

## 検討した代替案とトレードオフ

- scaffold 拡張: 既存コードの延長で実装しやすいが、対象リポジトリを汚さないという #63 の目的に反するため採用しない。
- `devcontainer` shim: ユーザーは既存コマンドを使えるが、上流 CLI と異なる隠れた挙動になり、障害時の原因切り分けが難しいため採用しない。
- Feature + `adc up`: 新しいコマンドを覚える必要はあるが、VS Code と CLI の差分を明示でき、テストしやすいため採用する。

## リスク / ロールバック

- Feature が一部 image に適用できない: 初期対応を Debian/Ubuntu に限定し、unsupported OS では明確に失敗させる。
- `adc up` が想定外に target repo へ書き込む: dry-run/print mode と fixture repo 検証で、wrapper 自体が repo に書かないことを確認する。
- 既存 scaffold 方式を壊す: 既存 `tests/scaffold.bats` と `tests/merge.bats` を回帰テストとして維持する。
- Feature の publish が未整備: 初期実装では local path または想定 OCI ID の command generation を確認し、publish 自動化は後続issueに分ける。

