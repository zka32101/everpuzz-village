import 'dart:convert';
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

  group('同梱の台帳', () {
    final manifest =
        jsonDecode(File('assets/art_manifest.json').readAsStringSync())
            as Map<String, Object?>;
    final slots = [
      for (final s in manifest['slots']! as List<Object?>)
        s! as Map<String, Object?>,
    ];

    test('読めて、現状(未配置)で通常検査に合格する', () {
      expect(checkAssets(manifest, root: '.'), isEmpty);
    });

    test('IDとパスは重複しない', () {
      expect({for (final s in slots) s['id']}.length, slots.length);
      expect({for (final s in slots) s['path']}.length, slots.length);
    });

    test('建物は設計書の20種×3段階=60状態(512x512・透過・任意)', () {
      // 設計書(町づくり設計 v0.1 の「建物20種」)の並び。名前と絵柄は仮だが、IDはここで固定する。
      const slugs = [
        'small_house',
        'mushroom_house',
        'windmill_house',
        'treehouse',
        'flower_house',
        'flower_field',
        'big_tree',
        'gourd_pond',
        'log_bridge',
        'bench',
        'bakery',
        'cafe',
        'general_store',
        'vegetable_field',
        'ranch',
        'lighthouse',
        'balloon',
        'water_mill',
        'clock_tower',
        'rainbow_arch',
      ];
      final expected = [
        for (final s in slugs)
          for (final st in [1, 2, 3]) '${s}_s$st',
      ];
      final ids = [for (final s in slots) s['id']! as String];
      final states = ids.where((i) => RegExp(r'_s[123]$').hasMatch(i)).toList();
      expect(states, expected);
      for (final s in slots.where((s) => expected.contains(s['id']))) {
        expect(s['width'], 512, reason: '${s['id']}');
        expect(s['height'], 512, reason: '${s['id']}');
        expect(s['transparent'], isTrue, reason: '${s['id']}');
        expect(s['required'], isFalse, reason: '${s['id']}');
        expect(s['path'], 'assets/art/${s['id']}.png');
      }
    });

    test('必須の素材は、背景1・アイコン・容器の奥と手前だけ', () {
      final required = {
        for (final s in slots)
          if (s['required'] == true) s['id'],
      };
      expect(required, {'bg_stage_01', 'tube_back', 'tube_front', 'app_icon'});
    });
  });
}
