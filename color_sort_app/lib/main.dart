import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/services.dart';

import 'game/app_state.dart';
import 'game/purchases.dart';
import 'game/revenuecat_gate.dart';
import 'l10n/strings.dart';
import 'ui/level_select_screen.dart';
import 'ui/town_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // 公開SDKキーはビルド時に渡す(--dart-define=RC_API_KEY=...)。無ければ店を出さない。
  const rcKey = String.fromEnvironment('RC_API_KEY');
  PurchaseGate? gate;
  if (rcKey.isNotEmpty) {
    final catalog = ShopCatalog.fromJson(
        await rootBundle.loadString(AppState.catalogAsset));
    gate =
        await RevenueCatGate.configure(rcKey, entitlement: catalog.entitlement);
  }
  final app =
      await AppState.load(PrefsKeyValueStore(prefs), purchaseGate: gate);
  runApp(ColorSortApp(app: app));
}

class ColorSortApp extends StatelessWidget {
  const ColorSortApp({
    super.key,
    required this.app,
    this.languageTag,
    this.startOnLevels = false,
  });

  final AppState app;

  /// テスト用の言語指定。null なら端末の言語。
  final String? languageTag;

  /// テスト用。true なら町を飛ばして面選択から始める。
  final bool startOnLevels;

  @override
  Widget build(BuildContext context) {
    final tag =
        languageTag ?? ui.PlatformDispatcher.instance.locale.toLanguageTag();
    final translator = translatorFor(tag);
    return L10n(
      translator: translator,
      child: MaterialApp(
        title: translator.tr('appTitle'),
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF7FB8F0),
          useMaterial3: true,
        ),
        home:
            startOnLevels ? LevelSelectScreen(app: app) : TownScreen(app: app),
      ),
    );
  }
}
