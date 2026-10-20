import 'package:color_sort/color_sort.dart';
import 'package:flutter/material.dart';

import '../game/art.dart';
import '../l10n/strings.dart';
import 'symbols.dart';

/// 1本の容器。色玉は「塗り色 + 固有の記号 + 数字」で描く(色だけに頼らない)。
/// タップ領域は 44pt 以上、文字拡大 200% でも崩れないよう数字は縮小して収める。
/// ヒントでの役割(色ではなく文字でも示す)。
enum HintRole { none, from, to }

class TubeWidget extends StatelessWidget {
  const TubeWidget({
    super.key,
    required this.index,
    required this.tube,
    required this.lock,
    required this.usable,
    required this.selected,
    required this.onTap,
    this.hintRole = HintRole.none,
    this.art = ArtCatalog.empty,
  });

  final int index;
  final List<int> tube;
  final TubeLock? lock;
  final bool usable;
  final bool selected;
  final VoidCallback onTap;
  final HintRole hintRole;

  /// 配置済みの画像。tube_back / tube_front があれば画像の容器で描く(無ければ従来の図形)。
  final ArtCatalog art;

  bool get useArt => art.has('tube_back') && art.has('tube_front');

  static const unit = 46.0; // 1スロットの大きさ(44pt以上)
  static const pad = 4.0;
  static const badgeHeight = 28.0;
  static const border = 3.0; // 選択時の枠線の太さ(最大)を常に見込む

  // 容器画像(256x640)。ガラスの内側は縦は約88%・横は約59%なので、
  // 色玉の積み(unit x capacity)がちょうど収まる大きさに合わせて描く。
  static const _artGlassHeight = 0.88;
  static const _artAspect = 256 / 640;
  static const _artBottom = 0.04; // 下の余白(高さに対する割合)

  /// 使えない容器の覆い。画像があれば画像(鍵=南京錠、凍結=氷)、無ければ従来の膜。
  /// 中身が見えないと手が読めないので、鍵の覆いは半透明にする。
  Widget _lockCover() {
    final id = lock!.kind == LockKind.key ? 'tube_lock_key' : 'tube_frozen';
    if (!useArt || !art.has(id)) return LockOverlay(lock: lock!);
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: lock!.kind == LockKind.key ? 0.55 : 1,
          child: _art(id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final artHeight = unit * ColorSortRules.capacity / _artGlassHeight; // 画像の高さ
    final artWidth = artHeight * _artAspect;
    final height = useArt
        ? artHeight + border * 2
        : unit * ColorSortRules.capacity + pad * 2 + border * 2;
    final done = ColorSortRules.isDone(tube);
    final label = [
      t.tr('tube', {'n': index + 1}),
      if (lock != null)
        t.tr(lock!.kind == LockKind.key ? 'lockKey' : 'lockFrozen'),
      if (selected) t.tr('selected'),
      if (hintRole != HintRole.none)
        t.tr(hintRole == HintRole.from ? 'hintFrom' : 'hintTo'),
    ].join(' ');

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 特殊容器の種類は容器の上のバッジで示す(中身に重ねない)。
            SizedBox(
              height: badgeHeight,
              child: hintRole != HintRole.none
                  ? Center(
                      child: FittedBox(
                        child: Text(
                          t.tr(hintRole == HintRole.from
                              ? 'hintFrom'
                              : 'hintTo'),
                          key: Key('hint-${hintRole.name}'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scheme.tertiary,
                          ),
                        ),
                      ),
                    )
                  : lock != null && !usable
                      ? LockBadge(lock: lock!)
                      : null,
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width:
                  useArt ? artWidth + border * 2 : unit + pad * 2 + border * 2,
              height: height,
              margin: EdgeInsets.only(
                  bottom: selected ? 14 : 0, top: selected ? 0 : 14),
              decoration: BoxDecoration(
                color: useArt ? null : scheme.surfaceContainerHighest,
                border: Border.all(
                  color: selected
                      ? scheme.primary
                      : hintRole != HintRole.none
                          ? scheme.tertiary
                          // 画像の容器は縁が絵に含まれるので、枠は選択・ヒントの時だけ。
                          : useArt
                              ? Colors.transparent
                              : scheme.outline,
                  width: selected || hintRole != HintRole.none ? 3 : 1.5,
                ),
                borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(6),
                    bottom: Radius.circular(unit / 2)),
              ),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  if (useArt) ...[
                    Positioned.fill(child: _art('tube_back')),
                    Padding(
                      padding: EdgeInsets.only(bottom: artHeight * _artBottom),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          for (final c in tube.reversed) UnitChip(color: c),
                        ],
                      ),
                    ),
                    Positioned.fill(child: _art('tube_front')),
                  ] else
                    Padding(
                      padding: const EdgeInsets.all(pad),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          for (final c in tube.reversed) UnitChip(color: c),
                        ],
                      ),
                    ),
                  if (done && art.has('tube_done'))
                    Positioned.fill(
                        child: IgnorePointer(child: _art('tube_done'))),
                  if (done)
                    Positioned(
                      top: 2,
                      child: Icon(Icons.check_circle,
                          size: 16, color: scheme.primary),
                    ),
                  if (lock != null && !usable) _lockCover(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 色玉1つ。塗り・記号・数字(色番号+1)。
Widget _art(String id) => Image.asset(
      'packages/color_sort/assets/art/$id.png',
      fit: BoxFit.fill,
      excludeFromSemantics: true,
    );

class UnitChip extends StatelessWidget {
  const UnitChip({super.key, required this.color});

  final int color;

  @override
  Widget build(BuildContext context) {
    final style = palette[color % palette.length];
    return SizedBox(
      width: TubeWidget.unit,
      height: TubeWidget.unit,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: CustomPaint(
          painter: _UnitPainter(style),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 3, bottom: 1),
              child: FittedBox(
                child: Text(
                  '${color + 1}',
                  style: const TextStyle(
                    color: Color(symbolInk | 0xFF000000),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnitPainter extends CustomPainter {
  _UnitPainter(this.style);

  final ColorStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..color = Color(style.fill | 0xFF000000),
    );
    final symbolRect = Rect.fromLTWH(
      size.width * 0.2,
      size.height * 0.1,
      size.width * 0.6,
      size.height * 0.6,
    );
    canvas.drawPath(
      symbolPath(style.symbol, symbolRect),
      Paint()..color = Color(symbolInk | 0xFF000000),
    );
  }

  @override
  bool shouldRepaint(_UnitPainter old) => old.style != style;
}

/// 使えない容器の覆い。中身は見えたままにし、縞模様(凍結)と白い膜(鍵)で示す。
class LockOverlay extends StatelessWidget {
  const LockOverlay({super.key, required this.lock});

  final TubeLock lock;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
              bottom: Radius.circular(TubeWidget.unit / 2)),
          child: CustomPaint(
            painter: _LockPainter(striped: lock.kind == LockKind.frozen),
          ),
        ),
      ),
    );
  }
}

class _LockPainter extends CustomPainter {
  _LockPainter({required this.striped});

  final bool striped;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55));
    if (!striped) return;
    final p = Paint()
      ..color = const Color(0xFF1F2233).withValues(alpha: 0.25)
      ..strokeWidth = 2;
    for (var x = -size.height; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(_LockPainter old) => old.striped != striped;
}

/// 容器の上のバッジ。鍵は「錠 + 解錠色の記号」、凍結は雪の結晶。
/// 解錠色は塗りだけでなく記号でも示す(色だけに頼らない)。
class LockBadge extends StatelessWidget {
  const LockBadge({super.key, required this.lock});

  final TubeLock lock;

  @override
  Widget build(BuildContext context) {
    final isKey = lock.kind == LockKind.key;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isKey ? Icons.lock : Icons.ac_unit,
            size: 18, color: const Color(0xFF1F2233)),
        if (isKey)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: CustomPaint(
              size: const Size(18, 18),
              painter: _KeySymbolPainter(palette[lock.color! % palette.length]),
            ),
          ),
      ],
    );
  }
}

class _KeySymbolPainter extends CustomPainter {
  _KeySymbolPainter(this.style);

  final ColorStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final path = symbolPath(style.symbol, (Offset.zero & size).deflate(1));
    canvas.drawPath(path, Paint()..color = Color(style.fill | 0xFF000000));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF1F2233));
  }

  @override
  bool shouldRepaint(_KeySymbolPainter old) => old.style != style;
}
