# Spec: ci-pr-image-build

## Intent

`Dockerfile.base`（およびビルド対象の `scripts/**`・`dotfiles/**`・`.dockerignore`）を変更する
PR で、マージ前にイメージがビルドできるかを検証する build-only ジョブを追加する。
PR ではレジストリに publish せず（`latest` を汚さない）、main / tag では従来どおり
multi-arch で本ビルド＆publish する二段構えにする。

issue #29 に対応する。Tier 1（lightweight spec のみ。plan/tasks は省略）。

## Acceptance Criteria

1. `.github/workflows/build-base-image.yml` の `on:` に `pull_request` トリガーが追加され、
   `push` と同じ `paths` フィルタ（`Dockerfile.base`, `scripts/agents-post-create`,
   `scripts/agents-post-start`, `dotfiles/**`, このワークフロー自身, `.dockerignore`）を持つ。
2. `pull_request` イベントでは `build-push-action` が `push: false` かつ
   `platforms: linux/amd64`（単一）でビルドする。
3. `push`（main / tag）イベントでは従来どおり `push: true` かつ
   `platforms: linux/amd64,linux/arm64`。
4. PR ではレジストリへ publish されない（タグ付け・push が発生しない）。
5. 該当 `paths` を変更しない PR ではこのジョブは起動しない。
6. 本変更を含む PR 上で build-only ジョブが実行され成功する（self-validating:
   ワークフロー自身が `paths` に含まれるため）。

## Out of Scope

- PR での multi-arch（arm64）ビルド（遅いため main / tag のみ）。
- fork からの PR に対する挙動の最適化（同一リポジトリの PR を前提）。
- 既存の `test` / `sdd` / `orchestration` ワークフローの変更。
