/// 色ソートの見た目の定義(色 + 記号 + 数字)。色だけに頼らず、
/// 各色に固有の記号と数字を付ける(色覚対応は必須要件)。
class ColorStyle {
  const ColorStyle(this.fill, this.symbol);

  /// 0xRRGGBB
  final int fill;

  /// 描画側が形として描く記号ID(文字ではないので l10n 対象外)。
  final String symbol;
}

/// 記号・数字の描画色(全塗り色の上で 4.5:1 以上を保つ)。
const symbolInk = 0x1F2233;

/// 色番号(0..7)→スタイル。数字ラベルは色番号+1。
const palette = <ColorStyle>[
  ColorStyle(0xF28B82, 'circle'),
  ColorStyle(0xFBBC04, 'triangle'),
  ColorStyle(0xA8DAB5, 'square'),
  ColorStyle(0x7FB8F0, 'diamond'),
  ColorStyle(0xD7AEFB, 'star'),
  ColorStyle(0xFDCFE8, 'heart'),
  ColorStyle(0x4DD0C8, 'cross'),
  ColorStyle(0xE6C9A8, 'flower'),
];
