# color_sort_app

Everpuzz 1本目(色ソート・仮称)の Flutter アプリ。ルール・面生成は `../color_sort`、基盤は `../../puzzle_core`。

## 構成

- `lib/game/game_controller.dart`: 1面のプレイ状態(選択・移動・戻す・やり直し・失敗理由・星)
- `lib/game/app_state.dart`: 同梱60面の読み込み・進行の保存(`puzzle_core` の保存窓口 + SharedPreferences)
- `lib/l10n/strings.dart`: 文言(ja/en)。**画面コードに文言を直書きしない**(テストで検査)
- `lib/ui/`: レベル選択・プレイ画面・容器(色 + 固有の記号 + 数字、鍵/凍結はバッジ)

## 見やすさ(テストで検査)

- 色だけに頼らない(各色に記号と数字)/ 失敗の理由を文で表示 / 星は数でも伝える
- タップ領域 44pt 以上 / 文字 200% で溢れない / 日本語の直書きなし

## 開発

```
flutter pub get
flutter analyze
flutter test
flutter run
```

## 未実装・仮

- ライフ・コイン・ブースター・広告・課金(`puzzle_core` の economy は用意済み。画面は未接続)
- 画像素材(`../color_sort/assets/art_manifest.json`)。未配置の間は図形で描画
- アプリID・アプリ名・アイコンは仮(`com.petitworksapps.color_sort_app`)
- 効果音・演出(注ぎアニメ等)、チュートリアル、設定画面
