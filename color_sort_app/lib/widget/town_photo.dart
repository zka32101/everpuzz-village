import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:share_plus/share_plus.dart';

import '../game/app_state.dart';
import 'town_snapshot.dart';

/// いまのエリアの町の絵(ウィジェットと町の写真で共通)。
TownSnapshot townSnapshotOf(AppState app) => TownSnapshot(
      placements: app.townState.placements,
      cells: app.townRules.cellCount(app.clearedLevels),
      background: _background(app),
    );

String? _background(AppState app) {
  // 町の画面と同じ背景(エリアの背景があればそれ、無ければ段階の背景)。
  final area = app.art.areaBackground(app.activePackId);
  if (area != null) return area;
  return app.art.stageBackground(app.globalLevelIndex(app.nextLevelIndex));
}

/// 共有の窓口(テストで差し替える)。PNG と、添える一言を渡す。
typedef PhotoSharer = Future<void> Function(Uint8List png, String text);

/// 端末の共有画面を開く。
Future<void> sharePhotoOnDevice(Uint8List png, String text) =>
    SharePlus.instance.share(ShareParams(
      text: text,
      files: [XFile.fromData(png, mimeType: 'image/png', name: 'town.png')],
      fileNameOverrides: const ['town.png'],
    ));

/// 町の写真(PNG)を作る。建物が1つも無いときは null。
Future<Uint8List?> renderTownPhoto(
  AppState app, {
  Future<ui.Image?> Function(String id)? loadImage,
  double width = 1080,
}) async {
  if (app.townState.placements.isEmpty) return null;
  return townSnapshotOf(app).render(
    loadImage ?? TownSnapshot.assetLoader,
    art: app.art,
    width: width,
  );
}
