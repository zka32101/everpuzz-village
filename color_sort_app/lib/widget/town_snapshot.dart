import 'dart:ui' as ui;

import 'package:color_sort/color_sort.dart' show Placement;
import 'package:flutter/services.dart';

import '../game/art.dart';

/// ホーム画面ウィジェットに見せる「町の絵」を PNG にする。
/// 文字は載せない(絵だけ)。画像が無い建物は淡い四角で示す。
class TownSnapshot {
  const TownSnapshot({
    required this.placements,
    required this.cells,
    this.background,
    this.columns = 4,
  });

  final List<Placement> placements;
  final int cells;
  final String? background;
  final int columns;

  /// 中身が同じかを見分ける印(同じなら描き直さない)。
  String get signature => [
        background ?? '-',
        cells,
        for (final p in placements) '${p.cell}:${p.buildingId}_s${p.stage}',
      ].join('|');

  /// 絵にする。[loadImage] は ID から画像を返す(無ければ null)。
  Future<Uint8List?> render(
    Future<ui.Image?> Function(String id) loadImage, {
    required ArtCatalog art,
    double width = 640,
  }) async {
    final rows = (cells / columns).ceil().clamp(1, 99);
    const pad = 24.0;
    const gap = 12.0;
    final cell = (width - pad * 2 - gap * (columns - 1)) / columns;
    final height = pad * 2 + rows * cell + (rows - 1) * gap;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final full = ui.Rect.fromLTWH(0, 0, width, height);

    final bg = background == null ? null : await loadImage(background!);
    if (bg != null) {
      canvas.drawImageRect(
        bg,
        ui.Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()),
        full,
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
    } else {
      canvas.drawRect(full, ui.Paint()..color = const ui.Color(0xFFE8F3E4));
    }

    for (final p in placements) {
      if (p.cell < 0 || p.cell >= cells) continue;
      final col = p.cell % columns;
      final row = p.cell ~/ columns;
      final rect = ui.Rect.fromLTWH(
        pad + col * (cell + gap),
        pad + row * (cell + gap),
        cell,
        cell,
      );
      final id = '${p.buildingId}_s${p.stage}';
      final img = art.has(id) ? await loadImage(id) : null;
      if (img == null) {
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
              rect.deflate(6), const ui.Radius.circular(12)),
          ui.Paint()..color = const ui.Color(0x66FFFFFF),
        );
        continue;
      }
      // 下そろえで、枠に収まるよう縮める(アプリの町と同じ見え方)。
      final scale = (rect.width / img.width) < (rect.height / img.height)
          ? rect.width / img.width
          : rect.height / img.height;
      final w = img.width * scale;
      final h = img.height * scale;
      canvas.drawImageRect(
        img,
        ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        ui.Rect.fromLTWH(
            rect.left + (rect.width - w) / 2, rect.bottom - h, w, h),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.round(), height.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  /// アプリの画像から読む既定の読み込み。
  static Future<ui.Image?> assetLoader(String id, {AssetBundle? bundle}) async {
    try {
      final data = await (bundle ?? rootBundle).load(ArtCatalog.assetOf(id));
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }
}
