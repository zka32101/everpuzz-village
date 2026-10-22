// 色ソートの面を生成し、ソルバーで検証して JSON に書き出す。
// 使い方:
//   dart run tool/generate_levels.dart [面数=60] [出力パス]                      (従来: main パック)
//   dart run tool/generate_levels.dart --id extra1 --count 60 --offset 60 \
//       --out assets/levels/pack_extra1.json [--version 1]
//   --offset は難易度の曲線を始める面番号(0始まり)。続きのパックは前のパックの面数を指定する。
// 出したら assets/packs.json に1行足す(パックの一覧。ここに無いパックは遊べない)。
import 'dart:convert';
import 'dart:io';

import 'package:color_sort/color_sort.dart';
import 'package:puzzle_core/puzzle_core.dart';

void main(List<String> args) {
  var id = 'main';
  var count = 60;
  var offset = 0;
  var version = 3;
  var out = 'assets/levels/pack_main.json';
  var outGiven = false;
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--id':
        id = args[++i];
      case '--count':
        count = int.parse(args[++i]);
      case '--offset':
        offset = int.parse(args[++i]);
      case '--version':
        version = int.parse(args[++i]);
      case '--out':
        out = args[++i];
        outGiven = true;
      default:
        positional.add(args[i]);
    }
  }
  if (positional.isNotEmpty) count = int.parse(positional[0]);
  if (positional.length > 1) {
    out = positional[1];
    outGiven = true;
  }
  if (!outGiven && id != 'main') out = 'assets/levels/pack_$id.json';

  final levels = <LevelEntry>[];
  for (var i = 0; i < count; i++) {
    final index = offset + i; // 難易度の曲線は通しの面番号で決める
    final g = generateLevel(index);
    levels.add(LevelEntry(
      id: '$id-${(i + 1).toString().padLeft(3, '0')}',
      seed: g.seed,
      difficulty: paramsForIndex(index).colors.toDouble(),
      spec: g.spec,
    ));
  }
  // 生成時の解とは独立に、パック全体を改めて検証して verified を書く。
  final pack = const LevelVerifier(ColorSortRules(),
          solverVersion: 'bfs-1', maxStates: levelSolveMaxStates)
      .verifyPack(LevelPack(
          game: 'color_sort',
          packId: id,
          packVersion: version,
          levels: levels));
  final issues = pack.validate();
  if (issues.isNotEmpty) {
    stderr.writeln(issues.join('\n'));
    exit(1);
  }
  File(out).writeAsStringSync(
      '${const JsonEncoder.withIndent(' ').convert(pack.toJson())}\n');
  stdout.writeln('wrote $count levels (id=$id, offset=$offset) -> $out');
}
