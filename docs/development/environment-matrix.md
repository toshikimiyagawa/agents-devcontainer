# Environment Matrix

このリポジトリでの作業環境と、各環境で可能な操作の一覧。

## 可否表

| Environment | 実装 | Bats | image build | dogfood smoke |
|---|---|---|---|---|
| host（通常 clone、/Users 配下） | ✓ | ✓ | ✓ | ✓ |
| host（linked worktree） | ✓ | ✓ | ✓ | ✗ |
| devcontainer 内 | ✓ | ✓ | ✗ | ✗ |
| CI（ubuntu-latest） | — | ✓ | ✓ | ✓ |

## なぜ linked worktree で smoke が動かないか

linked worktree の `.git` はファイル（ポインタ）であり、共通 git dir が workspace 外を指す。
devcontainer runtime は workspace に `.git` ディレクトリがあることを前提とするため、
linked worktree での起動に失敗する。

また macOS + Colima 環境では、linked worktree を `/private/tmp` や `/tmp` に
作成すると Colima のマウント範囲外になり bind mount に失敗する。

**これは回避すべき制約ではなく、正しい検証モデルを示す設計上の境界**:
smoke は消費プロジェクト（通常 clone）の体験をシミュレートするため、
通常 clone で実行することが最も実態に即した検証になる。

## smoke の正しい実行環境

- `/Users` 配下に通常 clone を用意する（Colima のデフォルトマウント範囲内）
- clone は既存 repo からローカル clone でよい（push 済みの branch が対象）
- Docker Desktop を使う場合も `/Users` 配下を推奨（制限が少ないが一貫性のため）
- CI（ubuntu-latest）は常に通常 clone で動作するため制約なし

## devcontainer 内での制限

devcontainer 内では Docker daemon にアクセスできないため、
image build と dogfood smoke は実行不可。
Bats テストと実装作業は devcontainer 内でも可能。
