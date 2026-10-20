import 'dart:convert';

/// 建物の定義(設定データ。コードを変えずに調整する)。
class BuildingDef {
  const BuildingDef({
    required this.id,
    required this.category,
    required this.unlockAfterLevels,
    required this.costs,
  });

  /// 素材は `<id>_s1〜s3`、名前は l10n の `building.<id>`。
  final String id;
  final String category;

  /// 何面クリア後に解放されるか。0 なら最初から。
  final int unlockAfterLevels;

  /// 費用 [置く(1段階目), 2段階目へ, 3段階目へ]。
  final List<int> costs;

  static const stages = 3;

  int get totalCost => costs.fold(0, (a, b) => a + b);

  /// 段階 [stage](1〜2)から次の段階へ育てる費用。
  int upgradeCost(int stage) => costs[stage];
}

/// 町の設定。
class TownConfig {
  const TownConfig({
    required this.columns,
    required this.maxCells,
    required this.spareCells,
    required this.dailyGift,
    required this.pointsPerDweller,
    required this.maxDwellers,
    required this.buildings,
  });

  final int columns;

  /// マスの最大数(4列×6行=24)。
  final int maxCells;

  /// 解放済みの建物数に足す空きマス(模様替えの余地)。
  final int spareCells;

  /// 1日1回の「町の贈り物」のコイン。
  final int dailyGift;

  /// 合計段階がこの数だけ増えるごとにこびとが1人増える。
  final int pointsPerDweller;
  final int maxDwellers;
  final List<BuildingDef> buildings;

  factory TownConfig.fromJson(String raw) {
    final m = jsonDecode(raw) as Map<String, Object?>;
    final grid = m['grid'] as Map<String, Object?>;
    final dw = m['dwellers'] as Map<String, Object?>;
    return TownConfig(
      columns: grid['columns'] as int,
      maxCells: grid['maxCells'] as int,
      spareCells: grid['spareCells'] as int,
      dailyGift: m['dailyGift'] as int,
      pointsPerDweller: dw['pointsPerDweller'] as int,
      maxDwellers: dw['max'] as int,
      buildings: [
        for (final b in (m['buildings'] as List).cast<Map<String, Object?>>())
          BuildingDef(
            id: b['id'] as String,
            category: b['category'] as String,
            unlockAfterLevels: b['unlockAfterLevels'] as int,
            costs: (b['costs'] as List).cast<int>(),
          ),
      ],
    );
  }

  BuildingDef? byId(String id) {
    for (final b in buildings) {
      if (b.id == id) return b;
    }
    return null;
  }

  int get totalCost => buildings.fold(0, (a, b) => a + b.totalCost);

  /// 設定の不整合を返す(空なら問題なし)。[levelCount] は面の総数。
  List<String> validate({required int levelCount}) {
    final issues = <String>[];
    final seen = <String>{};
    for (final b in buildings) {
      if (!seen.add(b.id)) issues.add('建物IDが重複: ${b.id}');
      if (b.costs.length != BuildingDef.stages) {
        issues.add('${b.id}: 費用は${BuildingDef.stages}個必要');
        continue;
      }
      if (b.costs.any((c) => c <= 0)) issues.add('${b.id}: 費用は正の数');
      for (var i = 1; i < b.costs.length; i++) {
        if (b.costs[i] <= b.costs[i - 1]) {
          issues.add('${b.id}: 費用は段階ごとに増やす');
          break;
        }
      }
      if (b.unlockAfterLevels < 0 || b.unlockAfterLevels > levelCount) {
        issues.add('${b.id}: 解放面が範囲外(${b.unlockAfterLevels})');
      }
    }
    if (buildings.isNotEmpty && buildings.first.unlockAfterLevels != 0) {
      issues.add('最初の建物は最初から解放する');
    }
    if (maxCells < buildings.length) {
      issues.add('マス数($maxCells)が建物の種類(${buildings.length})より少ない');
    }
    if (columns <= 0 || maxCells % columns != 0) {
      issues.add('マス数は列数の倍数にする');
    }
    if (spareCells < 0 || dailyGift < 0 || pointsPerDweller <= 0) {
      issues.add('設定値が不正');
    }
    return issues;
  }
}
