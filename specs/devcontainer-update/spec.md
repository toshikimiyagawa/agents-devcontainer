# Spec: devcontainer-update

## Intent

agents-devcontainer の設定変更（devcontainer.json テンプレート・SDD統合ファイル）を
消費プロジェクトが git submodule update で安全に取り込めるようにする。

## Acceptance Criteria

1. 消費プロジェクトで `git submodule update --remote vendor/agents-devcontainer && vendor/agents-devcontainer/scaffold/merge.sh` を実行すると `devcontainer.json` が最新の base に基づいて再生成される
2. `devcontainer.project.json` の内容がマージルール通りに反映される（name, image/build, mounts 結合, remoteEnv マージ, postCreateCommand 上書き）
3. `sdd-update.sh` が `.claude/agents/` と `sdd-check.yml` のみを更新し、`CLAUDE.md` 等の保護対象は変更しない
4. `scaffold.sh` で新規プロジェクトをセットアップすると `devcontainer.project.json` が生成され、`merge.sh` で `devcontainer.json` が生成される
5. `bats tests/` が全て通る
