# everpuzz-village

Everpuzz シリーズ1本目（色ソート・仮称）のアプリ。共通基盤は別リポジトリの
[puzzle_core](https://github.com/zka32101/puzzle_core)（非公開）を、**版を固定した git 依存**（コミットのハッシュ。タグを打てるようになったらタグ）で使う。

| ディレクトリ | 内容 |
|---|---|
| `color_sort/` | 純Dart: ルール・面生成・レベル検証・同梱レベル（60面）・素材台帳 |
| `color_sort_app/` | Flutterアプリ（画面・ライフ/コイン・ヒント・計測・多言語） |

詳細は各ディレクトリの README を参照。

## CIの準備（最初に1回）

`puzzle_core` が非公開のため、CI が取得できるよう、このリポジトリの **Settings → Secrets and variables → Actions** に
`PUZZLE_CORE_TOKEN`（puzzle_core の読み取り権限を持つ fine-grained トークン）を登録する。

## puzzle_core の版を上げるとき

1. puzzle_core 側で変更をマージし、そのコミット（またはタグ）を決める
2. `color_sort/pubspec.yaml` と `color_sort_app/pubspec.yaml` の `ref:` を同じ版にそろえる
3. テストが通ることを確認してからマージ

## 面パック(チャプター)
- `color_sort/assets/packs.json` に並べたパックが「章」になる。章は自由に行き来できる。
- 追加: `dart run tool/generate_levels.dart --id extra2 --count 60 --offset 120 --out assets/levels/pack_extra2.json` → `packs.json` に追記(`requires` / `unlockAfterPrevious` で解放条件)。
- 季節テーマ・背景は通し番号で5季節を循環する。
