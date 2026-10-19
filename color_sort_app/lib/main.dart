import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:puzzle_core/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/app_state.dart';
import 'l10n/strings.dart';
import 'ui/level_select_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final app = await AppState.load(
    KeyValueProgressStore(PrefsKeyValueStore(prefs)),
  );
  runApp(ColorSortApp(app: app));
}

class ColorSortApp extends StatelessWidget {
  const ColorSortApp({super.key, required this.app, this.languageTag});

  final AppState app;

  /// テスト用の言語指定。null なら端末の言語。
  final String? languageTag;

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
        home: LevelSelectScreen(app: app),
      ),
    );
  }
}
