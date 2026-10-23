# リリースに必要な対応(2026-10-23 時点)

コードで済む作業は終わっている。下は、**お手元(ストア・端末・署名・画像の権利)でしかできないもの**と、決めること。

## 0. 先に決める(公開後は変えにくい)
- [ ] **アプリ名・シリーズ名**(仮名「Everpuzz Pastel Village」)。いまの表示名は仮のまま:
  Android `android/app/src/main/AndroidManifest.xml` の `android:label="color_sort_app"`、iOS `ios/Runner/Info.plist` の `CFBundleDisplayName`("Color Sort App")。決まったら、ここと日本語・英語のストア名を揃える(依頼してくれればこちらで差し替える)。
- [ ] **アプリID**(一度公開すると変えられない)。いまは食い違っている:
  Android `com.petitworksapps.color_sort_app`(`android/app/build.gradle.kts`)、iOS `com.petitworksapps.colorSortApp`(`project.pbxproj`)。ストアのアプリを作る前に、最終の名前を決めて、両方を揃える(こちらで直せる)。
- [ ] **価格・コインの数**(`docs/monetization.md` の叩き台)。

## 1. 署名
- [ ] Android: アップロード鍵(キーストア)を作り、`android/key.properties` に置く(リポジトリには入れない。`.gitignore` 済み)。
  中身: `storeFile=<キーストアのパス>` / `storePassword=` / `keyAlias=` / `keyPassword=`。無いとデバッグ鍵で署名される(公開不可)。Google Play のアプリ署名を使う。
- [ ] iOS: Apple Developer の登録、証明書とプロビジョニング、App Store Connect にアプリを作る。

## 2. 広告・課金の本番設定
- [ ] AdMob: 本番のアプリID・リワード広告ユニットを作る。
  **Google のテスト用アプリIDを本番に差し替える**: `AndroidManifest.xml`(`com.google.android.gms.ads.APPLICATION_ID`)と `Info.plist`(`GADApplicationIdentifier`)。差し替え前の公開は不可。
- [ ] iOS: `Info.plist` の `SKAdNetworkItems` は、Google の識別子 1 つだけ入れてある。AdMob の公式の一覧(最新)に合わせて、リリース前に全部を足す。
- [ ] RevenueCat: 商品 `ads_removal` / `coins_small` / `coins_medium` / `coins_large` / `life_refill` / `levels_pack_1`(追加の面パック。権利は `levels.extra3` を付与)と権利 `ads_removed` を作り、`assets/shop/products.json` と一致させる。ストアコンソールでも同じ商品IDを作る。
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
- [ ] Google Play のデータセーフティ、App Store のプライバシー(広告・購入・端末ID/広告ID)。計測(telemetry)は、既定では何も送らない(`NoopTelemetry`)。
- [ ] 年齢区分(ガチャ・確率報酬なし、広告あり、アプリ内課金あり)。
- [ ] 説明文・スクリーンショット(縦)。アイコンは入っている(共通 C案)。

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
