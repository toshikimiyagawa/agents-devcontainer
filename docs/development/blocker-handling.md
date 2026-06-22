# Blocker Handling

frozen `tasks.md` の範囲外の問題が発生した場合の手順。

## 停止条件

以下の場合は即座に作業を停止する:
- frozen `tasks.md` にないファイルを変更しなければならない
- frozen spec の acceptance criterion を達成できない実装上の問題が判明した
- verify 時に SDD reviewer が scope 外の問題を指摘した

## 停止手順

1. 作業を停止する（scope 外の修正を行ってはいけない）
2. `.sdd/tasks.json` の当該 feature を `blocked` に設定する：

```json
{
  "id": "<feature-slug>",
  "status": "blocked",
  "blocked_reason": "<何が・なぜ・どのファイルで詰まっているかを記入>"
}
```

3. follow-up issue を作成する（下記テンプレート参照）
4. kanban 状態と `blocked_reason` を human に報告して待機する

## follow-up issue テンプレート

```
タイトル: fix(<feature>): <問題の概要>

## 背景
<元 issue #N の作業中に発見>

## 再現手順
```
<コマンド>
```

出力:
```
<実際の出力>
```

## 影響する acceptance criterion
- AC<N>: <該当する acceptance criterion のテキスト>

## 元 issue の resume 条件
この issue が close されたら #<元issue番号> の作業を再開できる。
```

## resume 条件

以下のいずれかが満たされた場合のみ作業を再開する:
- follow-up issue が close された
- human が「resume してよい」と明示的に指示した

どちらもない状態で自己判断して resume してはいけない。

## scope creep を吸収しない原則

SDD reviewer が verify 時に scope 外の問題を指摘しても、
`spec.md` や `tasks.md` を変更してその問題を吸収してはいけない。

frozen spec の範囲で実装を完了し、scope 外の問題は follow-up issue に分離する。
元 issue は frozen spec の範囲で close する。
