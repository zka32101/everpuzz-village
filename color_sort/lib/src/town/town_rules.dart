import 'town_config.dart';
import 'town_state.dart';

enum TownError {
  /// まだ解放されていない・存在しない建物。
  locked,
  alreadyPlaced,
  notPlaced,
  cellOutOfRange,
  cellTaken,
  maxStage,
  notEnoughCoins,
  sameCell,
}

/// 操作の結果。成功なら [state] と使ったコイン [cost]、失敗なら [error]。
class TownResult {
  const TownResult.ok(this.state, {this.cost = 0}) : error = null;
  const TownResult.fail(this.error)
      : state = null,
        cost = 0;

  final TownState? state;
  final int cost;
  final TownError? error;

  bool get ok => error == null;
}

/// 町のルール(純粋関数。コインの出し入れは呼び出し側が [TownResult.cost] で行う)。
class TownRules {
  const TownRules(this.config);

  final TownConfig config;

  /// クリア済みの面数に応じて解放された建物(設定の順)。
  List<BuildingDef> unlocked(int clearedLevels) => [
        for (final b in config.buildings)
          if (b.unlockAfterLevels <= clearedLevels) b,
      ];

  /// まだ知らせていない新しい建物(静かに知らせる用)。
  List<BuildingDef> newlyUnlocked(TownState s, int clearedLevels) {
    final all = unlocked(clearedLevels);
    return s.seenUnlocked >= all.length
        ? const []
        : all.sublist(s.seenUnlocked);
  }

  /// 解放の知らせを済みにする。
  TownState markUnlocksSeen(TownState s, int clearedLevels) =>
      s.copyWith(seenUnlocked: unlocked(clearedLevels).length);

  /// 終えた季節の数(季節を終えるごとに「季節の飾り」が1つ贈られる)。最大は季節の数。
  int seasonsDone(int clearedLevels) => config.seasons.isEmpty
      ? 0
      : (clearedLevels ~/ config.levelsPerSeason)
          .clamp(0, config.seasons.length);

  /// まだ知らせていない新しい季節の飾り(季節の番号。0始まり)。
  List<int> newSeasonObjects(TownState s, int clearedLevels) => [
        for (var i = s.seenSeasons; i < seasonsDone(clearedLevels); i++) i,
      ];

  TownState markSeasonsSeen(TownState s, int clearedLevels) =>
      s.copyWith(seenSeasons: seasonsDone(clearedLevels));

  /// いま遊んでいる面(0始まり)の季節。範囲外は最後の季節。
  SeasonDef? seasonAt(int levelIndex) {
    if (config.seasons.isEmpty) return null;
    final i = (levelIndex ~/ config.levelsPerSeason)
        .clamp(0, config.seasons.length - 1);
    return config.seasons[i];
  }

  /// 使えるマス数。解放数+空き、最大 [TownConfig.maxCells]。
  int cellCount(int clearedLevels) =>
      (unlocked(clearedLevels).length + config.spareCells)
          .clamp(0, config.maxCells);

  /// 置ける建物(解放済みで未設置)。
  List<BuildingDef> placeable(TownState s, int clearedLevels) => [
        for (final b in unlocked(clearedLevels))
          if (s.placementOf(b.id) == null) b,
      ];

  TownResult place(
    TownState s,
    String buildingId,
    int cell, {
    required int clearedLevels,
    required int coins,
  }) {
    final def = config.byId(buildingId);
    if (def == null || def.unlockAfterLevels > clearedLevels) {
      return const TownResult.fail(TownError.locked);
    }
    if (s.placementOf(buildingId) != null) {
      return const TownResult.fail(TownError.alreadyPlaced);
    }
    if (cell < 0 || cell >= cellCount(clearedLevels)) {
      return const TownResult.fail(TownError.cellOutOfRange);
    }
    if (s.at(cell) != null) return const TownResult.fail(TownError.cellTaken);
    final cost = def.costs.first;
    if (coins < cost) return const TownResult.fail(TownError.notEnoughCoins);
    return TownResult.ok(
      s.copyWith(placements: [
        ...s.placements,
        Placement(buildingId: buildingId, cell: cell)
      ]),
      cost: cost,
    );
  }

  TownResult upgrade(TownState s, String buildingId, {required int coins}) {
    final p = s.placementOf(buildingId);
    if (p == null) return const TownResult.fail(TownError.notPlaced);
    if (p.stage >= BuildingDef.stages) {
      return const TownResult.fail(TownError.maxStage);
    }
    final cost = config.byId(buildingId)!.upgradeCost(p.stage);
    if (coins < cost) return const TownResult.fail(TownError.notEnoughCoins);
    return TownResult.ok(
      s.copyWith(placements: [
        for (final q in s.placements)
          q.buildingId == buildingId ? q.copyWith(stage: q.stage + 1) : q,
      ]),
      cost: cost,
    );
  }

  /// 動かす(費用なし)。移し先に建物があれば入れ替える。
  TownResult move(
    TownState s,
    String buildingId,
    int toCell, {
    required int clearedLevels,
  }) {
    final p = s.placementOf(buildingId);
    if (p == null) return const TownResult.fail(TownError.notPlaced);
    if (toCell < 0 || toCell >= cellCount(clearedLevels)) {
      return const TownResult.fail(TownError.cellOutOfRange);
    }
    if (toCell == p.cell) return const TownResult.fail(TownError.sameCell);
    final other = s.at(toCell);
    return TownResult.ok(s.copyWith(placements: [
      for (final q in s.placements)
        if (q.buildingId == buildingId)
          q.copyWith(cell: toCell)
        else if (other != null && q.buildingId == other.buildingId)
          q.copyWith(cell: p.cell)
        else
          q,
    ]));
  }

  /// 置いた建物の段階の合計(最大 建物数×3)。
  int stagePoints(TownState s) => s.placements.fold(0, (a, p) => a + p.stage);

  /// こびとの人数(演出のみ)。
  int dwellers(TownState s) =>
      (stagePoints(s) ~/ config.pointsPerDweller).clamp(0, config.maxDwellers);

  /// 完成(全種類を置いた)。
  bool isComplete(TownState s) =>
      s.placements.length == config.buildings.length;

  /// 満開(完成していて、全建物が最終段階)。
  bool isBloom(TownState s) =>
      isComplete(s) && s.placements.every((p) => p.stage == BuildingDef.stages);

  /// 完成の知らせを出すべきか(完成していて、まだ出していない)。
  bool shouldShowComplete(TownState s) => isComplete(s) && !s.completeShown;

  /// 満開の知らせを出すべきか。
  bool shouldShowBloom(TownState s) => isBloom(s) && !s.bloomShown;

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 今日の贈り物を受け取れるか(1日1回。連続は問わない)。
  bool canClaimGift(TownState s, DateTime now) =>
      config.dailyGift > 0 && s.lastGiftDay != dayKey(now);

  /// 贈り物を受け取る。受け取れない時は null。
  TownResult? claimGift(TownState s, DateTime now) {
    if (!canClaimGift(s, now)) return null;
    // 贈り物額(config.dailyGift)のコイン加算は呼び出し側で行う。
    return TownResult.ok(s.copyWith(lastGiftDay: dayKey(now)));
  }
}
