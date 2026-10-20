import 'town_config.dart';

/// 経済の整合(町全体の費用と、面クリアの収入の釣り合い)の報告。
class TownBalance {
  const TownBalance({
    required this.totalCost,
    required this.minIncome,
    required this.maxIncome,
  });

  /// [firstClear]=初回クリア報酬、[starBonus]=星1つ増えるごとの追加(最大+2つ分)。
  /// 収入は日替わりを含まない(面クリアのみ)。
  factory TownBalance.compute(
    TownConfig config, {
    required int levelCount,
    required int firstClear,
    required int starBonus,
  }) =>
      TownBalance(
        totalCost: config.totalCost,
        minIncome: levelCount * firstClear,
        maxIncome: levelCount * (firstClear + 2 * starBonus),
      );

  final int totalCost;
  final int minIncome;
  final int maxIncome;

  /// 費用 ÷ 最小収入(1より大きいと、全て1星では届かない)。
  double get vsMin => totalCost / minIncome;

  /// 費用 ÷ 最大収入(1より大きいと、全て3星でも届かない)。
  double get vsMax => totalCost / maxIncome;

  /// 極端なずれの警告。
  List<String> warnings() => [
        if (vsMax > 1) '全て3星でも町全体の費用に届かない',
        if (vsMin < 0.5) '全て1星でも費用の2倍以上が貯まる(町が早く終わりすぎる)',
      ];
}
