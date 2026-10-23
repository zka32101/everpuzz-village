import 'dart:io';

import 'package:color_sort_app/l10n/strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_core/foundation.dart';

void main() {
  test('l10n lint: 対応する全言語が、ja とキー・プレースホルダ・複数形まで一致', () {
    expect(supportedLocales,
        {'ja', 'en', 'ko', 'es', 'zh-Hans', 'zh-Hant'}); // 言語を足したら、ここも更新する
    for (final l in supportedLocales.where((l) => l != 'ja')) {
      expect(L10nLint.compare(bundles['ja']!, bundles[l]!, locale: l), isEmpty,
          reason: 'ja → $l');
      expect(
          L10nLint.compare(bundles[l]!, bundles['ja']!, locale: 'ja'), isEmpty,
          reason: '$l → ja');
    }
  });

  test('端末の言語から、対応する言語を選ぶ(中国語は字体で)', () {
    String pick(String tag) => translatorFor(tag).locale;
    expect(pick('ja-JP'), 'ja');
    expect(pick('en-US'), 'en');
    expect(pick('ko-KR'), 'ko');
    expect(pick('es-ES'), 'es');
    expect(pick('es-419'), 'es');
    expect(pick('zh-Hans-CN'), 'zh-Hans');
    expect(pick('zh-Hant-TW'), 'zh-Hant');
    expect(pick('zh-HK'), 'zh-Hant');
    expect(pick('fr-FR'), 'en'); // 対応外は英語
  });

  test('各言語で、文言が空でなく、言語名が自分の言語で出る', () {
    const names = {
      'ja': '日本語',
      'en': 'English',
      'ko': '한국어',
      'es': 'Español',
      'zh-Hans': '简体中文',
      'zh-Hant': '繁體中文',
    };
    for (final l in supportedLocales) {
      final t = Translator(l, bundles);
      for (final k in bundles['ja']!.keys) {
        expect(t.tr(k), isNotEmpty, reason: '$l: $k');
        expect(t.tr(k), isNot(k), reason: '$l: $k が訳されていない(キーのまま)');
      }
      for (final e in names.entries) {
        expect(t.tr('language.${e.key}'), e.value, reason: l);
      }
    }
    // 複数形(スペイン語だけ 1 と それ以外で変わる)
    expect(Translator('es', bundles).tr('moves', {'count': 1}), '1 movimiento');
    expect(
        Translator('es', bundles).tr('moves', {'count': 5}), '5 movimientos');
    expect(Translator('ko', bundles).tr('moves', {'count': 1}), '1번');
  });

  test('l10n lint: 画面コードに日本語を直書きしない(l10n/strings.dart のみ可)', () {
    final cjk = RegExp(r'[぀-ヿ一-鿿]');
    final bad = <String>[];
    for (final f
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      // Windows の区切り(\)でも同じに扱う。
      final path = f.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || path.endsWith('l10n/strings.dart')) {
        continue;
      }
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // コメント(///, //)は対象外
        final code = lines[i].split('//').first;
        if (cjk.hasMatch(code)) bad.add('$path:${i + 1}');
      }
    }
    expect(bad, isEmpty);
  });
}
