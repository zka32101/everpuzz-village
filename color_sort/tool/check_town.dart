// 町の設定(assets/town/buildings.json)の検査と、経済の整合の報告。
// 使い方: dart run tool/check_town.dart
import 'dart:convert';
import 'dart:io';

import 'package:color_sort/color_sort.dart';

// アプリ側の報酬(color_sort_app の clearReward / starBonus)と同じ値。
const firstClearReward = 20;
const starBonus = 5;

void main() {
  final config = TownConfig.fromJson(
      File('assets/town/buildings.json').readAsStringSync());
  final pack =
      jsonDecode(File('assets/levels/pack_main.json').readAsStringSync())
          as Map<String, Object?>;
  final levels = (pack['levels'] as List).length;

  final issues = config.validate(levelCount: levels);
  final last = config.buildings.last.unlockAfterLevels;
  if (last > levels) issues.add('最終面までに全建物が解放されない');
  final b = TownBalance.compute(config,
      levelCount: levels, firstClear: firstClearReward, starBonus: starBonus);
  stdout.writeln(
      '建物 ${config.buildings.length}種 / 全面 $levels / 町全体の費用 ${b.totalCost}');
  stdout.writeln('収入 最小 ${b.minIncome} 〜 最大 ${b.maxIncome}'
      '(費用÷最小=${b.vsMin.toStringAsFixed(2)}、費用÷最大=${b.vsMax.toStringAsFixed(2)})');
  for (final w in b.warnings()) {
    stdout.writeln('警告: $w');
  }
  if (issues.isNotEmpty) {
    for (final i in issues) {
      stderr.writeln('NG: $i');
    }
    exit(1);
  }
  stdout.writeln('OK');
}
