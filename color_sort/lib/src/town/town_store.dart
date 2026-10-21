import 'package:puzzle_core/foundation.dart';

import 'town_config.dart';
import 'town_state.dart';

/// 町の保存(版管理つき)。
class TownStore {
  const TownStore(this.kv, this.config, {this.cellLimit});

  static const key = 'town';
  static const schema = 1;

  final KeyValueStore kv;
  final TownConfig config;

  /// 読み込み時に許すマス番号の上限(省略時は設定の最大マス数)。
  final int? cellLimit;

  Future<void> save(TownState s) =>
      VersionedJsonStore(kv).save(key, schema, s.toJson());

  /// 未保存・破損・将来版は空の町。壊れた項目(未知のID・範囲外・重複)は捨てる。
  Future<TownState> load() async {
    final j = await VersionedJsonStore(kv).load(key, currentVersion: schema);
    if (j == null) return TownState.empty;
    try {
      final limit = cellLimit ?? config.maxCells;
      final ids = <String>{};
      final cells = <int>{};
      final placements = <Placement>[];
      for (final m in ((j['placements'] as List?) ?? const [])) {
        final e = m as Map;
        final id = e['id'] as String;
        final cell = e['cell'] as int;
        final stage = e['stage'] as int;
        if (config.byId(id) == null) continue;
        if (cell < 0 || cell >= limit) continue;
        if (stage < 1 || stage > BuildingDef.stages) continue;
        if (!ids.add(id) || !cells.add(cell)) continue;
        placements.add(Placement(buildingId: id, cell: cell, stage: stage));
      }
      return TownState(
        placements: placements,
        lastGiftDay: j['lastGiftDay'] as String?,
        seenUnlocked: (j['seenUnlocked'] as int?) ?? 1,
        completeShown: (j['completeShown'] as bool?) ?? false,
        bloomShown: (j['bloomShown'] as bool?) ?? false,
        seenSeasons: (j['seenSeasons'] as int?) ?? 0,
      );
    } on Object {
      return TownState.empty;
    }
  }
}
