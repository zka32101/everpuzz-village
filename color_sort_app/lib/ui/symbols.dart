import 'dart:math' as math;
import 'dart:ui';

/// 色ごとの記号を [r] の矩形に収まる Path にする。色だけに頼らない表示の要。
/// ID は `color_sort` の palette.dart と対応する。
Path symbolPath(String id, Rect r) {
  final c = r.center;
  final s = r.shortestSide / 2;
  switch (id) {
    case 'circle':
      return Path()..addOval(Rect.fromCircle(center: c, radius: s));
    case 'triangle':
      return Path()
        ..moveTo(c.dx, c.dy - s)
        ..lineTo(c.dx + s, c.dy + s * 0.8)
        ..lineTo(c.dx - s, c.dy + s * 0.8)
        ..close();
    case 'square':
      return Path()
        ..addRect(Rect.fromCenter(center: c, width: s * 1.7, height: s * 1.7));
    case 'diamond':
      return Path()
        ..moveTo(c.dx, c.dy - s)
        ..lineTo(c.dx + s, c.dy)
        ..lineTo(c.dx, c.dy + s)
        ..lineTo(c.dx - s, c.dy)
        ..close();
    case 'star':
      final p = Path();
      for (var i = 0; i < 10; i++) {
        final rad = i.isEven ? s : s * 0.45;
        final a = -math.pi / 2 + i * math.pi / 5;
        final pt = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    case 'heart':
      return Path()
        ..moveTo(c.dx, c.dy + s)
        ..cubicTo(
          c.dx - s * 1.6,
          c.dy - s * 0.2,
          c.dx - s * 0.7,
          c.dy - s * 1.2,
          c.dx,
          c.dy - s * 0.35,
        )
        ..cubicTo(
          c.dx + s * 0.7,
          c.dy - s * 1.2,
          c.dx + s * 1.6,
          c.dy - s * 0.2,
          c.dx,
          c.dy + s,
        )
        ..close();
    case 'cross':
      final t = s * 0.38;
      return Path()
        ..addRect(Rect.fromCenter(center: c, width: s * 2, height: t * 2))
        ..addRect(Rect.fromCenter(center: c, width: t * 2, height: s * 2));
    case 'flower':
      final p = Path();
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / 5;
        p.addOval(
          Rect.fromCircle(
            center: Offset(
              c.dx + s * 0.55 * math.cos(a),
              c.dy + s * 0.55 * math.sin(a),
            ),
            radius: s * 0.45,
          ),
        );
      }
      return p..addOval(Rect.fromCircle(center: c, radius: s * 0.3));
    default:
      return Path()..addOval(Rect.fromCircle(center: c, radius: s * 0.5));
  }
}
