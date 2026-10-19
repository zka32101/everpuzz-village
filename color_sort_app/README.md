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

## ライフ・コイン(puzzle_core の economy を接続)

- ライフ5・30分で1回復(時計は注入。ライフ切れは回復を待つ)。**行き詰まるとライフを1つ失う**(戻す/やり直しの後に詰んだ場合は、やり直しごとに1回)。ライフ0では新しい面を始められない
- コインは1種類。**初回クリアで+10**(2回目以降は0)。確率報酬なし
- 空き容器ブースター(40コイン): 空の容器を1本足す。1回のプレイにつき1回、足した後は戻せない、星は最大2。やり直しても持ち越し
- リワード広告: `AdGate` を渡したときだけ「広告を見て回復」が出る(未接続なら非表示)
- 数値は `lib/game/app_state.dart` の `economyConfig`(設定データ)。保存は版管理つき

## 計測(puzzle_core の Telemetry)

`level_start` / `level_win`(手数)/ `level_fail`(行き詰まり)/ `booster_used` / `ad_shown` を、`AppState.telemetry` に出す。
実体(analytics 等)は未接続(既定は何もしない)。やり直しで `attempt` が増え、失敗は進行にも試行回数として残る。

## 未実装・仮

- 広告SDK・課金(広告削除・コインパック)の接続。`AdGate` の実装は未着手
- 画像素材(`../color_sort/assets/art_manifest.json`)。未配置の間は図形で描画
- アプリID・アプリ名・アイコンは仮(`com.petitworksapps.color_sort_app`)
- 効果音・演出(注ぎアニメ等)、チュートリアル、設定画面、日替わり報酬
