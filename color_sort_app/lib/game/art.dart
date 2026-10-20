import 'package:flutter/services.dart';

/// 配置済みの画像素材(`color_sort/assets/art/<ID>.png`)の一覧。
/// 画像が無いIDは描画側が仮の図形で代用する(台帳: art_manifest.json)。
class ArtCatalog {
  const ArtCatalog(this.ids);

  static const empty = ArtCatalog({});
  static const prefix = 'packages/color_sort/assets/art/';

  final Set<String> ids;

  bool has(String id) => ids.contains(id);

  /// ステージ背景は12面ごとに切り替わる(bg_stage_01〜05)。
  /// 画像が無い段階は、ある中で一番近い手前の段階にする。無ければ null。
  String? stageBackground(int levelIndex, {int levelsPerStage = 12}) {
    var n = (levelIndex ~/ levelsPerStage + 1).clamp(1, 5);
    for (; n >= 1; n--) {
      final id = 'bg_stage_${n.toString().padLeft(2, '0')}';
      if (has(id)) return id;
    }
    return null;
  }

  /// Image.asset に渡すパス。
  static String assetOf(String id) => '$prefix$id.png';

  static Future<ArtCatalog> load(AssetBundle bundle) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(bundle);
      return ArtCatalog({
        for (final a in manifest.listAssets())
          if (a.startsWith(prefix) && a.endsWith('.png'))
            a.substring(prefix.length, a.length - '.png'.length),
      });
    } catch (_) {
      return empty;
    }
  }
}
