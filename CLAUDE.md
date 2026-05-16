# Development Guidelines

## ブランチ

変更は必ずブランチを切って作業すること。main への直接コミットは行わない。

## テスト

変更に対応するテストを書いてから実装すること。テストは必ずローカルで実行して通ることを確認してから PR を作成する。

```bash
# 実行方法（要 bats-core: brew install bats-core）
bats tests/
```

テストは `tests/` 以下に配置する。`scaffold.sh` の変更には `tests/scaffold.bats` を更新すること。
