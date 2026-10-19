import 'package:color_sort_app/game/game_controller.dart';
import 'package:puzzle_core/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

LevelEntry level(List<List<int>> tubes, {int? minMoves}) => LevelEntry(
      id: 't',
      difficulty: 1,
      spec: {'capacity': 4, 'tubes': tubes},
      verified: minMoves == null
          ? null
          : LevelVerification(
              solvable: true, minMoves: minMoves, solverVersion: 't'),
    );

void main() {
  test('選択→移動→戻す→やり直し', () {
    final g = GameController(level([
      [1, 0, 0],
      [0, 0],
      [],
    ]));
    g.tap(0);
    expect(g.selected, 0);
    g.tap(1);
    expect(g.board.tubes[1], [0, 0, 0, 0]);
    expect(g.moves, 1);
    g.undo();
    expect(g.moves, 0);
    expect(g.board.tubes[1], [0, 0]);
    g.tap(0);
    g.tap(1);
    g.restart();
    expect(g.moves, 0);
    expect(g.canUndo, isFalse);
  });

  test('通らない手は理由が出て、動かせる容器なら選び直す', () {
    final g = GameController(level([
      [0, 1],
      [1, 0],
      [0, 0, 0, 0],
    ]));
    g.tap(0);
    g.tap(1); // 上が 1 と 0 で一致しない
    expect(g.lastError, MoveError.color);
    expect(g.selected, 1);
    g.tap(2); // 満杯
    expect(g.lastError, MoveError.full);
  });

  test('そろった容器は選べない', () {
    final g = GameController(level([
      [0, 0, 0, 0],
      [1],
    ]));
    g.tap(0);
    expect(g.lastError, MoveError.done);
    expect(g.selected, isNull);
  });

  test('鍵付き容器は使えない理由(locked)が出る', () {
    final g = GameController(LevelEntry(
      id: 'k',
      difficulty: 1,
      spec: {
        'capacity': 4,
        'tubes': [
          [0, 0, 0],
          [1, 0],
          [],
        ],
        'locks': [
          null,
          {'kind': 'key', 'color': 1},
          null,
        ],
      },
    ));
    g.tap(1);
    expect(g.lastError, MoveError.locked);
    g.tap(0);
    g.tap(1);
    expect(g.lastError, MoveError.locked);
  });

  test('クリア判定と星(最短手数以内で3)', () {
    final g = GameController(level([
      [0, 0, 0],
      [0],
    ], minMoves: 1));
    g.tap(1);
    g.tap(0);
    expect(g.won, isTrue);
    expect(g.stars, 3);
    final before = g.moves;
    g.tap(0); // クリア後は操作しない
    expect(g.moves, before);
  });

  test('行き詰まり(stuck)を検出する', () {
    final g = GameController(level([
      [0, 1, 0, 1],
      [1, 0, 1, 0],
    ]));
    expect(g.stuck, isTrue);
  });
}
