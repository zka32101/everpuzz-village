import 'package:flutter/services.dart';

/// 配置済みの画像素材(`color_sort/assets/art/<ID>.png`)の一覧。
/// 画像が無いIDは描画側が仮の図形で代用する(台帳: art_manifest.json)。
class ArtCatalog {
  const ArtCatalog(this.ids);

  static const empty = ArtCatalog({});
  static const prefix = 'packages/color_sort/assets/art/';

  final Set<String> ids;

  bool has(String id) => ids.contains(id);

  /// ステージ背景は12面ごとに切り替わる(bg_stage_01〜05)。画像が無い段階は、ある中で
  /// 一番近い手前の段階にする。無ければ null。
  String? stageBackground(int levelIndex, {int levelsPerStage = 12}) {
    // 5段階を超えたら最初から巡る(面が増えても背景が続く)。
    var n = (levelIndex ~/ levelsPerStage) % 5 + 1;
    for (; n >= 1; n--) {
      final id = 'bg_stage_${n.toString().padLeft(2, '0')}';
      if (has(id)) return id;
    }
    return null;
  }

  /// 面のテーマ(背景の段階に対応: 若草・秋・冬・夏・桜)。12面ごとに切り替わる。
  /// 容器と色玉の画像をテーマごとに用意できる(無ければ共通の画像、それも無ければ図形)。
  static const themes = ['spring', 'autumn', 'winter', 'summer', 'sakura'];

  String themeFor(int levelIndex, {int levelsPerStage = 12}) =>
      themes[(levelIndex ~/ levelsPerStage) % themes.length];

  /// テーマ付きの画像ID(`<base>_<theme>`)があればそれ、無ければ共通の [base]。
  String themed(String base, String theme) {
    final id = '${base}_$theme';
    return has(id) ? id : base;
  }

  /// テーマ付きの色玉の画像ID(`ball_<theme>_<色番号2桁>`)。無ければ null(図形で描く)。
  String? ballId(String theme, int color, {int colors = 8}) {
    final id = 'ball_${theme}_${(color % colors).toString().padLeft(2, '0')}';
    return has(id) ? id : null;
  }

  /// エリア(パックID)ごとの背景画像ID。町の画面・町の写真・ウィジェットで共通。
  static const areaBackgrounds = {
    'main': 'area_village',
    'extra1': 'area_meadow',
    'extra2': 'area_hill',
  };

  /// そのエリアの背景(画像があれば)。無ければ null。
  String? areaBackground(String packId) {
    final id = areaBackgrounds[packId];
    return id != null && has(id) ? id : null;
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
