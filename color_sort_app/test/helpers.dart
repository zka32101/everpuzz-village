import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_core/foundation.dart';

/// 同梱パックから AppState を作る。時計・保存先・広告窓口を差し替えられる。
Future<AppState> loadApp({
  MemoryKeyValueStore? kv,
  Clock? clock,
  AdGate? adGate,
  Telemetry? telemetry,
}) {
  return AppState.load(
    kv ?? MemoryKeyValueStore(),
    bundle: rootBundle,
    clock: clock ?? FakeClock(DateTime.utc(2026, 1, 1, 12)),
    adGate: adGate,
    telemetry: telemetry ?? const NoopTelemetry(),
  );
}

Widget appWidget(AppState app, {String lang = 'en', double textScale = 1}) =>
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: ColorSortApp(app: app, languageTag: lang),
    );
