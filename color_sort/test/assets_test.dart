import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../tool/check_assets.dart';

/// 最小のPNGヘッダ(IHDRのみ。検査には十分)を作る。
Uint8List png(int w, int h, int colorType, {bool trns = false}) {
  final b = BytesBuilder();
  void u32(int v) =>
      b.add([v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255]);
  b.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  u32(13);
  b.add('IHDR'.codeUnits);
  u32(w);
  u32(h);
  b.add([8, colorType, 0, 0, 0]);
  u32(0); // CRC(検査では見ない)
  if (trns) {
    u32(1);
    b.add('tRNS'.codeUnits);
    b.add([0]);
    u32(0);
  }
  return b.toBytes();
}

void main() {
  final manifest = {
    'slots': [
      {
        'id': 'a',
        'path': 'a.png',
        'width': 4,
        'height': 2,
        'transparent': true,
        'required': true
      },
      {
        'id': 'b',
        'path': 'b.png',
        'width': 4,
        'height': 2,
        'transparent': false,
        'required': false
      },
    ],
  };
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('art'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('未配置は通常は許容、strictでは必須のみ失敗', () {
    expect(checkAssets(manifest, root: tmp.path), isEmpty);
    expect(checkAssets(manifest, root: tmp.path, strict: true), ['a: 未配置(必須)']);
  });

  test('サイズ違い・透過なし・非PNGを検出', () {
    File('${tmp.path}/a.png').writeAsBytesSync(png(5, 2, 2)); // RGB(透過なし)
    File('${tmp.path}/b.png').writeAsStringSync('not png');
    final issues = checkAssets(manifest, root: tmp.path);
    expect(issues, hasLength(3));
  });

  test('RGBA・パレット+tRNS は透過あり、合格', () {
    File('${tmp.path}/a.png').writeAsBytesSync(png(4, 2, 6));
    expect(checkAssets(manifest, root: tmp.path), isEmpty);
    File('${tmp.path}/a.png').writeAsBytesSync(png(4, 2, 3, trns: true));
    expect(checkAssets(manifest, root: tmp.path), isEmpty);
  });

  test('同梱の台帳は読め、現状(未配置)で通常検査に合格する', () {
    final m = {'slots': <Object?>[]};
    expect(checkAssets(m, root: '.'), isEmpty);
  });
}
