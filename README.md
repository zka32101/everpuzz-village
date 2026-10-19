# everpuzz-pastel-village

Everpuzz シリーズ1本目（色ソート・仮称）のアプリ。共通基盤は別リポジトリの
[puzzle_core](https://github.com/zka32101/puzzle_core)（非公開）を、**タグ固定の git 依存**で使う。

| ディレクトリ | 内容 |
|---|---|
| `color_sort/` | 純Dart: ルール・面生成・レベル検証・同梱レベル（60面）・素材台帳 |
| `color_sort_app/` | Flutterアプリ（画面・ライフ/コイン・ヒント・計測・多言語） |

詳細は各ディレクトリの README を参照。

## CIの準備（最初に1回）

`puzzle_core` が非公開のため、CI が取得できるよう、このリポジトリの **Settings → Secrets and variables → Actions** に
`PUZZLE_CORE_TOKEN`（puzzle_core の読み取り権限を持つ fine-grained トークン）を登録する。

## puzzle_core の版を上げるとき

1. puzzle_core 側でタグ（例 `v0.2.0`）を打つ
2. `color_sort/pubspec.yaml` と `color_sort_app/pubspec.yaml` の `ref:` を同じ版にそろえる
3. テストが通ることを確認してからマージ
