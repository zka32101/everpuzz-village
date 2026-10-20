/// 置いた建物。
class Placement {
  const Placement(
      {required this.buildingId, required this.cell, this.stage = 1});

  final String buildingId;

  /// マス番号(0〜。行優先)。
  final int cell;

  /// 段階(1〜3)。
  final int stage;

  Placement copyWith({int? cell, int? stage}) => Placement(
        buildingId: buildingId,
        cell: cell ?? this.cell,
        stage: stage ?? this.stage,
      );
}

/// 町の状態(解放済みは進行から導くので持たない)。
class TownState {
  const TownState({
    this.placements = const [],
    this.lastGiftDay,
    this.seenUnlocked = 1,
    this.completeShown = false,
    this.bloomShown = false,
  });

  /// 置いた建物(各建物は最大1つ)。
  final List<Placement> placements;

  /// 町の贈り物を最後に受け取った日(`yyyy-mm-dd`)。
  final String? lastGiftDay;

  /// 知らせ済みの解放数(最初の1種は最初から解放なので 1)。
  final int seenUnlocked;

  /// 「完成」「満開」の知らせを出した(1回だけ)。
  final bool completeShown;
  final bool bloomShown;

  static const empty = TownState();

  Placement? placementOf(String buildingId) {
    for (final p in placements) {
      if (p.buildingId == buildingId) return p;
    }
    return null;
  }

  Placement? at(int cell) {
    for (final p in placements) {
      if (p.cell == cell) return p;
    }
    return null;
  }

  TownState copyWith({
    List<Placement>? placements,
    String? lastGiftDay,
    int? seenUnlocked,
    bool? completeShown,
    bool? bloomShown,
  }) =>
      TownState(
        placements: placements ?? this.placements,
        lastGiftDay: lastGiftDay ?? this.lastGiftDay,
        seenUnlocked: seenUnlocked ?? this.seenUnlocked,
        completeShown: completeShown ?? this.completeShown,
        bloomShown: bloomShown ?? this.bloomShown,
      );

  Map<String, Object?> toJson() => {
        'placements': [
          for (final p in placements)
            {'id': p.buildingId, 'cell': p.cell, 'stage': p.stage},
        ],
        'lastGiftDay': lastGiftDay,
        'seenUnlocked': seenUnlocked,
        'completeShown': completeShown,
        'bloomShown': bloomShown,
      };
}
