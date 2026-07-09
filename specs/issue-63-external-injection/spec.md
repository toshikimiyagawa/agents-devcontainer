# Spec: 既存devcontainer外部注入

- Tier: 2
- Status: frozen
- Feature slug: issue-63-external-injection
- Parent issue: #63
- SDD contract issue: #64

## 背景 / 意図

既存の `agents-devcontainer` は、消費プロジェクトに `.devcontainer` と repo-local `dotfiles/` を生成する scaffold 方式を中心にしている。この方式は新規導入には有効だが、すでに `.devcontainer/devcontainer.json` を持つリポジトリでは、対象リポジトリの開発環境定義を汚す。

#63 では、対象リポジトリを変更せずに agent tooling を注入する第2の導入経路を作る。既存 scaffold 方式は維持し、外部注入方式は明示的に別経路として扱う。

## 受入条件

- [ ] AC-001: VS Code `Reopen in Container` 経由では、対象リポジトリの `.devcontainer` を変更せず、Dev Container Feature を `dev.containers.defaultFeatures` で注入する設計と手順が文書化されている。
- [ ] AC-002: CLI 経由では、生の `devcontainer up` ではなく `adc up <workspace>` を正式入口とし、`--additional-features` で agents Feature を注入する仕様が実装・文書化されている。
- [ ] AC-003: 生の `devcontainer up` では VS Code user settings の `defaultFeatures` が適用されない制約が、CLI help または docs に明記されている。
- [ ] AC-004: agent tooling の state/cache/dotfiles/auth 関連データは、対象リポジトリ配下ではなく repo 外の named volume または user data directory に置く仕様になっている。
- [ ] AC-005: 初期対応範囲は Debian/Ubuntu 系 devcontainer に限定され、Alpine/Fedora/sudoなし特殊環境は非対応または後続課題として明記されている。
- [ ] AC-006: 既存 scaffold/submodule 方式は維持され、既存の scaffold/merge tests が通る。
- [ ] AC-007: Feature metadata、`adc up` の引数生成、docs の制約記載、対象リポジトリを汚さないことを確認するテストまたは検証手順が定義されている。

## スコープ

- Dev Container Feature の最小骨格を追加する。
- CLI wrapper `adc up` を追加する。
- VS Code `Reopen in Container` と CLI の利用手順を文書化する。
- 外部注入方式の最小検証と既存 scaffold 方式の回帰確認を追加する。
- #63 の子issue #65, #66, #67, #68 に分けて実装可能なタスクに落とす。

## スコープ外

- 既存 scaffold 方式の削除または置き換え。
- 対象リポジトリに `.devcontainer`、agent config、cache、state を生成する方式。
- `devcontainer` コマンド自体の shim または alias 差し替え。
- 既存 base image と完全同等の tool install を Feature 初版で再現すること。
- Alpine、Fedora、RHEL、sudo なし image、特殊 user layout への初期対応。
- GitHub Actions で OCI Feature を publish するリリース自動化。必要なら後続issueにする。

## 制約 / 前提

- Dev Container Feature は `features/agents/` に配置する。
- Feature ID は `agents` とする。
- 公開時の想定参照先は `ghcr.io/toshikimiyagawa/agents-devcontainer/agents:1` とする。
- `adc up` は `devcontainer up` を内部で呼ぶ wrapper であり、`devcontainer` CLI の代替実装ではない。
- `adc up` は対象リポジトリ配下にファイルを書いてはならない。
- Feature の初期対応 OS は Debian/Ubuntu 系に限定する。
- 実装は SDD の frozen contract に従い、spec/plan/tasks を実装中に都合よく変更しない。

## Catalog

この feature は `.sdd/catalog.json` の `rules` catalog に新しい開発ルールを追加しない。外部注入方式の仕様はこの spec と利用ドキュメントで管理する。
