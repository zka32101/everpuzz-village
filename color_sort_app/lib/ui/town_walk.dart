import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/art.dart';

/// こびとの歩き方(純粋な計算。時刻と番号だけで決まるので、テストできる)。
/// 1回の移動は [moveSeconds] 秒、その後 [pauseSeconds] 秒立ち止まる。ゆっくり、急かさない。
class DwellerWalk {
  const DwellerWalk({
    required this.columns,
    required this.cells,
    this.moveSeconds = 8,
    this.pauseSeconds = 3,
  });

  final int columns;

  /// 使えるマス数(こびとはこの範囲のマスの間を歩く)。
  final int cells;
  final double moveSeconds;
  final double pauseSeconds;

  double get legSeconds => moveSeconds + pauseSeconds;

  int _hash(int a, int b) {
    var h = (a * 73856093) ^ (b * 19349663);
    h = (h ^ (h >> 13)) * 0x5bd1e995 & 0x7fffffff;
    return h ^ (h >> 15);
  }

  /// 目的のマス(区間番号ごとに決まる)。
  int targetCell(int dweller, int leg) => _hash(dweller + 1, leg) % cells;

  /// 時刻 [seconds] での位置(列・行の小数。マスの中心が整数+0.5)。
  /// 歩いている間は、移動元から移動先へなめらかに進む。
  Offset position(int dweller, double seconds) {
    // こびとごとに出発をずらす(全員が同時に動かない)。
    final t = seconds + dweller * 2.3;
    final leg = (t ~/ legSeconds);
    final local = t - leg * legSeconds;
    final from = _cellCenter(targetCell(dweller, leg));
    final to = _cellCenter(targetCell(dweller, leg + 1));
    final p = (local / moveSeconds).clamp(0.0, 1.0);
    final eased = p * p * (3 - 2 * p); // 出だしと止まる所をやわらかく
    return Offset.lerp(from, to, eased)!;
  }

  Offset _cellCenter(int cell) =>
      Offset(cell % columns + 0.5, (cell ~/ columns).toDouble() + 0.5);

  /// 歩いている最中か(止まっている間は体を揺らさない)。
  bool isWalking(int dweller, double seconds) {
    final t = seconds + dweller * 2.3;
    return (t % legSeconds) < moveSeconds;
  }
}

/// 町の上を歩くこびと(画像)。タップは通さない(町の操作の邪魔をしない)。
/// 「アニメーションを減らす」設定のときは歩かず、立ったまま。
class DwellerLayer extends StatefulWidget {
  const DwellerLayer({
    super.key,
    required this.count,
    required this.walk,
    required this.cellSize,
    required this.gap,
    required this.padding,
    this.size = 36,
  });

  final int count;
  final DwellerWalk walk;
  final double cellSize;
  final double gap;
  final double padding;
  final double size;

  @override
  State<DwellerLayer> createState() => _DwellerLayerState();
}

class _DwellerLayerState extends State<DwellerLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _seconds = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _seconds.value = d.inMicroseconds / 1e6)
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return IgnorePointer(
      child: ValueListenableBuilder<double>(
        valueListenable: _seconds,
        builder: (context, s, _) {
          final seconds = still ? 0.0 : s;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < widget.count; i++) _dweller(i, seconds),
            ],
          );
        },
      ),
    );
  }

  Widget _dweller(int i, double seconds) {
    final pos = widget.walk.position(i, seconds);
    final step = widget.cellSize + widget.gap;
    // マスの下寄りに立つ(足元がマスの下端近く)。歩く間は小さく弾む。
    final bob = widget.walk.isWalking(i, seconds)
        ? math.sin(seconds * 6 + i).abs() * 3
        : 0.0;
    final x = widget.padding + pos.dx * step - widget.gap / 2 - widget.size / 2;
    final y = widget.padding +
        pos.dy * step -
        widget.gap / 2 +
        widget.cellSize * 0.3 -
        widget.size -
        bob;
    final id = 'kobito_0${i % 3 + 1}';
    return Positioned(
      left: x,
      top: y,
      width: widget.size,
      height: widget.size,
      child: Image.asset(
        ArtCatalog.assetOf(id),
        key: Key('walker-$i'),
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
