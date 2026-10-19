// 同梱レベルの出荷前検査(CI用)。
// 全面をソルバーで再検証し、verified と食い違えば・解けなければ失敗する。
// 使い方: dart run tool/check_levels.dart [JSONパス...]
import 'dart:convert';
import 'dart:io';

import 'package:color_sort/color_sort.dart';
import 'package:puzzle_core/puzzle_core.dart';

void main(List<String> args) {
  final paths = args.isEmpty
      ? Directory('assets/levels')
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => p.endsWith('.json'))
          .toList()
      : args;
  var failed = false;
  for (final path in paths) {
    final pack = LevelPack.fromJson(
        jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>);
    final issues = pack.validate();
    final redo = const LevelVerifier(ColorSortRules(),
            solverVersion: 'bfs-1', maxStates: levelSolveMaxStates)
        .verifyPack(pack);
    for (var i = 0; i < pack.levels.length; i++) {
      final a = pack.levels[i].verified!;
      final b = redo.levels[i].verified!;
      if (a.solvable != b.solvable || a.minMoves != b.minMoves) {
        issues.add('${pack.levels[i].id}: verified が再検証と不一致');
      }
    }
    if (issues.isEmpty) {
      stdout.writeln('$path: OK (${pack.levels.length}面)');
    } else {
      failed = true;
      stderr.writeln('$path:\n  ${issues.join('\n  ')}');
    }
  }
  if (failed) exit(1);
}
