import 'package:color_sort/color_sort.dart';
import 'package:puzzle_core/foundation.dart';
import 'package:test/test.dart';

void main() {
  final fills = [for (final c in palette) c.fill];

  test('各色に固有の記号がある(色だけに頼らない)', () {
    expect(palette.map((c) => c.symbol).toSet().length, palette.length);
  });

  test('記号・数字の色が全ての塗りの上でAAコントラスト', () {
    for (final c in palette) {
      expect(meetsTextAA(symbolInk, c.fill), isTrue,
          reason: '${c.symbol}: ${contrastRatio(symbolInk, c.fill)}');
    }
  });

  test('通常の色覚では全色が見分けられる', () {
    expect(
        findIndistinguishable(fills,
            visions: [ColorVision.normal], minDifference: 15),
        isEmpty);
  });

  test('色覚の違いで見分けにくい組を一覧する(記号で補うので許容、増えたら気付く)', () {
    final pairs = findIndistinguishable(fills, minDifference: 12);
    // 記号で必ず区別できるため失敗にはしない。極端に多い場合のみ見直す。
    expect(pairs.length, lessThan(12), reason: pairs.join('\n'));
  });
}
