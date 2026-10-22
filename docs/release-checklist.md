# リリース前チェックリスト

コードで済む作業は終わっている。下は、**お手元(ストア・端末・画像)でしかできないもの**。

## 1. ビルド時に渡す値(リポジトリには入れない)
`--dart-define=名前=値` で渡す。
| 名前 | 内容 | 無いとき |
|---|---|---|
| `RC_API_KEY` | RevenueCat の公開SDKキー | ショップを出さない |
| `ADMOB_REWARDED_ID` | AdMob のリワード広告ユニットID | 広告ボタンを出さない |
| `PRIVACY_URL` / `TERMS_URL` | プライバシー・利用規約のURL | 情報画面にリンクを出さない |
| `APP_VERSION` | 表示用の版 | 空 |

## 2. ストア・課金
- [ ] RevenueCat: 商品 `ads_removal` / `coins_small` / `coins_medium` / `coins_large` / `life_refill` を作り、`assets/shop/products.json` と一致させる(価格・コイン数は決める)。
- [ ] AdMob: 本番のアプリID・広告ユニットを発行。**`AndroidManifest.xml` / `Info.plist` の Google テスト用アプリID を本番IDに差し替える**(差し替え前の公開は不可)。
- [ ] 同意(UMP)の文言・地域設定を確認。
- [ ] アプリ名・シリーズ名(仮名「Everpuzz Pastel Village」)を決める。

## 3. 画像(お手元の画像セッション)
`color_sort/assets/art/` だけを変更するPRで出す(CIが通ればマージ)。
- [ ] 季節ごとの容器・玉(秋・冬・夏・桜): Drive「画像作成 追記6」
- [ ] アダプティブアイコン `app_icon_fg.png` / `app_icon_bg.png`: 追記8(その後 `flutter_launcher_icons-adaptive.yaml` で生成。iOSの `project.pbxproj` の `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` 差分は戻す)
- [ ] エリア背景 `area_village` / `area_meadow`(追記9)、第3エリア `area_hill`(1080x1920、台帳と `TownScreen.areaArt` への追加が要る)
- [ ] 画像生成サービスの利用規約の版・日付を記録。
- [ ] リリース前の厳密検査: `cd color_sort && dart run tool/check_assets.dart --strict`

## 4. 実機で確認
- [ ] Android / iOS: 起動(白画面にならない)、面を遊ぶ、ヒントの見やすさ、横向き→縦に戻す。
- [ ] ホーム画面ウィジェット: Android は一覧に「あなたの町」が出て更新される。iOS は `ios/TownWidget/README.md` の手順。
- [ ] 購入(サンドボックス)と購入の復元、広告の表示と報酬。
- [ ] 設定: 言語切替、動きを減らす、進行の削除。
- [ ] 小さい画面・文字拡大で、盤面が1画面に収まる。

## 5. CI・その他
- [ ] `PUZZLE_CORE_TOKEN` シークレット(puzzle_core を取得するため)。
- [ ] ストア掲載文・スクリーンショット・年齢区分(ガチャ・確率報酬なし、広告あり)。
