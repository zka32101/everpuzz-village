# iOS ホーム画面ウィジェット(町の絵)

Xcode での設定が要るため、ソースだけ置いてある(Runner のビルドには入れていない)。**実機未確認**。

1. Xcode で `File > New > Target > Widget Extension` を作る(名前 `TownWidget`、Include Configuration App Intent は外す)。
   自動生成のソースは消し、このフォルダの `TownWidget.swift` を入れる。
2. Runner と TownWidget の両方で `Signing & Capabilities > App Groups` を追加し、同じ名前
   (`group.com.petitworksapps.colorsortapp`。変えるなら Swift 側 2 か所の `appGroup` も同じに)を入れる。
3. `HomeWidgetChannel.swift` を Runner ターゲットに加え、`AppDelegate.swift` の
   `didInitializeImplicitFlutterEngine` で `HomeWidgetChannel.register(...)` を呼ぶ(ファイル冒頭のコメント参照)。
4. 実機で、アプリで町を変えたあと、ホーム画面のウィジェットが更新されることを確かめる。

Dart 側(`lib/widget/home_widget_sync.dart`)は、チャンネル `everpuzz/home_widget` の `update` に
町の PNG を渡すだけ。iOS 側が未設定でもアプリは普通に動く。
