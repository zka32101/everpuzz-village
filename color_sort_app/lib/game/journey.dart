/// 「町のあゆみ」に出す数字。競わせず、いままでの歩みを眺めるためのもの。
class Journey {
  const Journey({
    required this.levelsCleared,
    required this.levelsTotal,
    required this.stars,
    required this.starsMax,
    required this.buildingsPlaced,
    required this.buildingStages,
    required this.dwellers,
    required this.seasonsDone,
    required this.areas,
  });

  final int levelsCleared;
  final int levelsTotal;
  final int stars;
  final int starsMax;

  /// 置いた建物の数(全エリアの合計)と、育てた段階の合計。
  final int buildingsPlaced;
  final int buildingStages;

  /// こびとの数(全エリアの合計)。
  final int dwellers;
  final int seasonsDone;
  final List<AreaJourney> areas;
}

/// エリア(チャプター)ごとのあゆみ。
class AreaJourney {
  const AreaJourney({
    required this.id,
    required this.levelsCleared,
    required this.levelsTotal,
    required this.buildings,
    required this.available,
  });

  final String id;
  final int levelsCleared;
  final int levelsTotal;
  final int buildings;

  /// 遊べる(開いている)か。
  final bool available;
}
