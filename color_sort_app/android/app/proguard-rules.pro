# 起動時に「Failed to create an instance of androidx.work.impl.WorkDatabase」で落ちる既知のR8問題への対策。
# 都道府県アプリ(geography_puzzle_king)で確立したkeepルールと同じもの。共通基盤が
# Firebase / WorkManager(Room) / 広告SDK を含むため、R8縮小化でリフレクション経由のクラスが削られる。

# Firebase SDKs rely on reflection to instantiate their component
# registrars (ComponentDiscoveryService reads <meta-data> from the merged
# manifest, then does Class.forName(...).newInstance() on each one). With
# R8 full mode the no-arg constructors get stripped/renamed, which throws
# NoSuchMethodException at startup and makes Crashlytics/Installations
# "not present" — the app then hangs on the Flutter splash screen because
# the unhandled PlatformException blocks Firebase init.
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
-keep class * implements com.google.firebase.components.ComponentRegistrar
-keep class com.google.firebase.provider.FirebaseInitProvider

# WorkManager (pulled in transitively by Firebase) uses Room, which loads
# its generated *_Impl database classes by name via reflection at runtime.
# Same class of bug as above: R8 renaming/stripping them causes "Failed to
# create an instance of androidx.work.impl.WorkDatabase" at startup.
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Database class * { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase {
    <init>();
}
-keep class androidx.work.impl.WorkDatabase
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-dontwarn androidx.room.**

# 上記の keep ルールを追加して WorkManager クラッシュを直した後、今度は
# firebase_core の Pigeon 生成コード（FirebaseCoreHostApi の native 側
# ハンドラ登録）が R8 full mode で削れてしまい、Dart 側が
# "channel-error, Unable to establish connection on channel:
# ...FirebaseCoreHostApi.initializeCore" で Firebase.initializeApp() に
# 失敗し起動直後に白画面のまま止まる別バグが表面化した。Flutter の
# プラグインブリッジ層（io.flutter.plugins.* / io.flutter.plugin.*）を
# まるごと keep することで、各プラグインの consumer-rules.pro 適用漏れに
# 依存せず確実に守る。
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**
