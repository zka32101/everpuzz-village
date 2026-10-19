import 'dart:io';

import 'package:color_sort_app/l10n/strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';

void main() {
  test('l10n lint: ja と en のキー・プレースホルダが一致', () {
    expect(L10nLint.compare(bundles['en']!, bundles['ja']!, locale: 'ja'),
        isEmpty);
  });

  test('l10n lint: 画面コードに日本語を直書きしない(l10n/strings.dart のみ可)', () {
    final cjk = RegExp(r'[぀-ヿ一-鿿]');
    final bad = <String>[];
    for (final f
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('l10n/strings.dart')) {
        continue;
      }
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // コメント(///, //)は対象外
        final code = lines[i].split('//').first;
        if (cjk.hasMatch(code)) bad.add('${f.path}:${i + 1}');
      }
    }
    expect(bad, isEmpty);
  });
}
