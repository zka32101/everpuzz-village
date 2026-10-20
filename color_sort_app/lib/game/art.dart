import 'package:flutter/services.dart';

/// 配置済みの画像素材(`color_sort/assets/art/<ID>.png`)の一覧。
/// 画像が無いIDは描画側が仮の図形で代用する(台帳: art_manifest.json)。
class ArtCatalog {
  const ArtCatalog(this.ids);

  static const empty = ArtCatalog({});
  static const prefix = 'packages/color_sort/assets/art/';

  final Set<String> ids;

  bool has(String id) => ids.contains(id);

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
