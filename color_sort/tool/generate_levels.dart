// 色ソートの面を生成し、ソルバーで検証して JSON に書き出す。
// 使い方: dart run tool/generate_levels.dart [面数=60] [出力パス]
import 'dart:convert';
import 'dart:io';

import 'package:color_sort/color_sort.dart';
import 'package:puzzle_core/puzzle_core.dart';

void main(List<String> args) {
  final count = args.isNotEmpty ? int.parse(args[0]) : 60;
  final out = args.length > 1 ? args[1] : 'assets/levels/pack_main.json';

  final levels = <LevelEntry>[];
  for (var i = 0; i < count; i++) {
    final g = generateLevel(i);
    levels.add(LevelEntry(
      id: 'main-${(i + 1).toString().padLeft(3, '0')}',
      seed: g.seed,
      difficulty: paramsForIndex(i).colors.toDouble(),
      spec: g.spec,
    ));
  }
  // 生成時の解とは独立に、パック全体を改めて検証して verified を書く。
  final pack = const LevelVerifier(ColorSortRules(),
          solverVersion: 'bfs-1', maxStates: levelSolveMaxStates)
      .verifyPack(LevelPack(
          game: 'color_sort', packId: 'main', packVersion: 3, levels: levels));
  final issues = pack.validate();
  if (issues.isNotEmpty) {
    stderr.writeln(issues.join('\n'));
    exit(1);
  }
  File(out).writeAsStringSync(
      '${const JsonEncoder.withIndent(' ').convert(pack.toJson())}\n');
  stdout.writeln('wrote $count levels -> $out');
}
