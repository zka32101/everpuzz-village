import 'package:color_sort_app/game/app_state.dart';
import 'package:color_sort_app/game/art.dart';
import 'package:color_sort_app/game/hint.dart';
import 'package:color_sort_app/game/purchases.dart';
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
  HintSolver? hintSolver,
  PurchaseGate? purchaseGate,
  ShopCatalog? catalogOverride,
  ArtCatalog? art,
}) {
  return AppState.load(
    kv ?? MemoryKeyValueStore(),
    bundle: rootBundle,
    clock: clock ?? FakeClock(DateTime.utc(2026, 1, 1, 12)),
    adGate: adGate,
    purchaseGate: purchaseGate,
    catalogOverride: catalogOverride,
    // 既定は画像なし(図形+文字の表示を検査する)。実画像は art: で渡す。
    artOverride: art ?? ArtCatalog.empty,
    telemetry: telemetry ?? const NoopTelemetry(),
    // テストでは isolate を使わず同期で解く。
    hintSolver: hintSolver ?? (b) async => solveHint(b),
  );
}

Widget appWidget(AppState app,
        {String lang = 'en', double textScale = 1, bool town = false}) =>
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: ColorSortApp(app: app, languageTag: lang, startOnLevels: !town),
    );
