import 'package:flutter/material.dart';
import 'package:puzzle_core/foundation.dart';
import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/main.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

Future<AppState> loadApp({MemoryKeyValueStore? kv}) async {
  final raw = await rootBundle.loadString(AppState.packAsset);
  final pack = LevelPack.fromJson(jsonDecode(raw) as Map<String, Object?>);
  final store = KeyValueProgressStore(kv ?? MemoryKeyValueStore());
  return AppState(pack: pack, store: store, progress: await store.load());
}

Widget appWidget(AppState app, {String lang = 'en', double textScale = 1}) =>
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: ColorSortApp(app: app, languageTag: lang),
    );
