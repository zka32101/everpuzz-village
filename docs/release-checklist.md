# リリースに必要な対応(2026-10-23 時点)

コードで済む作業は終わっている。下は、**お手元(ストア・端末・署名・画像の権利)でしかできないもの**と、決めること。

## 0. 先に決める(公開後は変えにくい)
- [x] **アプリ名**: 「Everpuzz Village」に決定(表示名は Android `AndroidManifest.xml` / iOS `Info.plist` / アプリ内 `appTitle` に反映済み)。ストア名・言語別の名前は別途。
- [x] **アプリID(Android)**: `com.yourwish.everpuzz.village` に決定(`android/app/build.gradle.kts` の applicationId。namespace とコードのパッケージは内部名 `com.petitworksapps.color_sort_app` のまま)。
- [ ] **アプリID(iOS)**: 未対応。いまは `com.petitworksapps.colorSortApp`(`project.pbxproj`)。iOS を出すときに、Android に合わせて揃える(保留中)。
- [x] **価格**: Play に商品7つを作成済み(2026-10-24。`ads_removal` 480円・`coins_small` 160円・`coins_medium` 480円・`coins_large` 960円・`life_refill` 160円・`levels_pack_1` 480円・`deco_pack_1` 3ドル(米国は 2.99ドルに丸められる))。コインの数は `assets/shop/products.json`。

## 1. 署名
- [x] Android: アップロード鍵を作成済み(鍵は Drive の key フォルダ。リポジトリには入れない)。AAB 0.1.0+1 を署名してビルドし、Play の内部テストにアップロード済み。(旧メモ: `android/key.properties` に置く(リポジトリには入れない。`.gitignore` 済み)。)
  中身: `storeFile=<キーストアのパス>` / `storePassword=` / `keyAlias=` / `keyPassword=`。無いとデバッグ鍵で署名される(公開不可)。Google Play のアプリ署名を使う。
- [ ] iOS: Apple Developer の登録、証明書とプロビジョニング、App Store Connect にアプリを作る。

## 2. 広告・課金の本番設定
- [x] AdMob(Android): アプリとリワード広告ユニットを作成済み(アプリID `ca-app-pub-5058227312086483~7715479034`、リワード `ca-app-pub-5058227312086483/8090135120`)。マニフェストのアプリIDは本番に差し替え済み(広告ユニットIDは `--dart-define=ADMOB_REWARDED_ID` で渡す)。iOS は保留。
- [ ] (旧) AdMob: 本番のアプリID・リワード広告ユニットを作る。
  **Google のテスト用アプリIDを本番に差し替える**: `AndroidManifest.xml`(`com.google.android.gms.ads.APPLICATION_ID`)と `Info.plist`(`GADApplicationIdentifier`)。差し替え前の公開は不可。
- [ ] iOS: `Info.plist` の `SKAdNetworkItems` は、Google の識別子 1 つだけ入れてある。AdMob の公式の一覧(最新)に合わせて、リリース前に全部を足す。
- [x] RevenueCat: プロジェクト「Everpuzz」・Play アプリ(`com.yourwish.everpuzz.village`)・権利 `ads_removed` は作成済み。残り: サービスアカウント JSON のアップロード、商品(下記)と Offering。
- [x] RevenueCat: 商品7つと権利 `ads_removed` を作成済み(`ads_removal` を `ads_removed` に紐付け。`levels.extra3` と `deco.seasonal1` はアプリ内で付与するため権利は不要。Offering は不要: アプリは `Purchases.getProducts` を商品IDで直接呼ぶ)。**残り: サービスアカウント JSON のアップロード**。(旧メモ: 商品 `ads_removal` / `coins_small` / `coins_medium` / `coins_large` / `life_refill` / `levels_pack_1`(追加の面パック。権利は `levels.extra3` を付与)と権利 `ads_removed` を作り、`assets/shop/products.json` と一致させる。ストアコンソールでも同じ商品IDを作る。)
- [ ] 同意(UMP)の文言・地域設定を確認。iOS の追跡の許可(ATT)の説明文は入れてある(`NSUserTrackingUsageDescription`)。

## 3. ビルド(お手元で)
```
cd color_sort_app
flutter build appbundle --release \
  --build-name=1.0.0 --build-number=1 \
  --dart-define=RC_API_KEY=... \
  --dart-define=ADMOB_REWARDED_ID=... \
  --dart-define=PRIVACY_URL=... --dart-define=TERMS_URL=... --dart-define=APP_VERSION=1.0.0
flutter build ipa --release  (同じ --dart-define を付ける)
```
- 無い値は、その機能が出ない(`RC_API_KEY` が無ければショップなし、`ADMOB_REWARDED_ID` が無ければ広告ボタンなし)。**公開用は全部入れる**。
- この環境には Android SDK も Xcode も無いので、リリースビルド(R8 の縮小を含む)は未確認。**release のビルドが通り、起動して遊べることを、実機で必ず確認**(`proguard-rules.pro` で R8 の落ちは防いである)。

## 4. 画像・権利
- [ ] Canva・Leonardo・Google の画像生成の、**商用利用の条件**(生成物の扱い)を確認し、版・日付を記録する。アプリ内のクレジット(情報画面)に載せてある。
- [ ] 季節の容器・玉(秋・冬・夏・桜): Drive「画像作成 追記6」。無くても動く(既存の絵で代用)。
- [ ] 厳密検査: `cd color_sort && dart run tool/check_assets.dart --strict`(必須の素材がそろっているか)。

## 5. ストアの提出物
- [ ] プライバシーポリシー・利用規約の URL(アプリ内のリンクに使う)。
- [x] (Google Play のデータセーフティは下書き保存済み。広告=位置(おおよそ)・クラッシュ・診断・操作数・デバイスID、購入=購入履歴。**審査前に確認**)
- [ ] (旧) Google Play のデータセーフティ、App Store のプライバシー(広告・購入・端末ID/広告ID)。計測(telemetry)は、既定では何も送らない(`NoopTelemetry`)。
- [ ] 年齢区分(ガチャ・確率報酬なし、広告あり、アプリ内課金あり)。
- [x] 説明文(英・日)・スクリーンショット4枚・機能グラフィック・アイコン512は、Play に下書き保存済み(素材は Drive の images\everpuzz\ストア掲載_2026-10-24)。ショップの金額が出る画面は、サービスアカウント JSON のあと撮り直す。

## 6. 実機で確認
- [ ] 起動(白画面にならない)、面を遊ぶ、ヒント(丸と矢印)の見やすさ、効果音、横向き→縦に戻す、小さい画面・文字拡大で盤面が1画面に収まる。
- [ ] 町: 置く・育てる・動かす、エリアの切替、町の写真の共有、引き継ぎ(2台で作る→読み込む)、あゆみ。
- [ ] ホーム画面ウィジェット(Android は一覧に「あなたの町」。iOS は `ios/TownWidget/README.md` の手順が要る)。
- [ ] 購入(サンドボックス)と「購入の復元」、広告の表示と報酬、広告なし購入後に広告が消える。
- [ ] 設定: 言語、動きを減らす、効果音、進行の削除。
- [ ] アイコンの見え方(丸・角丸・四角のマスク)。

## 7. CI
- [ ] `PUZZLE_CORE_TOKEN` シークレット(puzzle_core を取得するため)。
- [ ] 公開前に、main の CI が緑であること。

## できていること(参考)
面 180(3 章)・町とエリア・休憩の案内・はじめての案内・町の写真・引き継ぎ・町のあゆみ・効果音・ホーム画面ウィジェット(Android)・設定/情報・共通アイコン・エリア背景・収益化の仕組み(広告なし・コイン・ライフ全回復・リワード広告)。
