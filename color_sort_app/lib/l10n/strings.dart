import 'package:flutter/widgets.dart';
import 'package:puzzle_core/foundation.dart';

/// 文言は全てここ(翻訳データ)経由で引く。画面コードに文言を直書きしない。
/// 言語の追加はこの Map にロケールを足すだけ。
const bundles = <String, Map<String, String>>{
  'ja': {
    'appTitle': 'Everpuzz',
    'level': 'レベル {n}',
    'moves': '{count, plural, other{#手}}',
    'undo': 'ひとつ戻す',
    'restart': 'やり直す',
    'next': 'つぎへ',
    'back': 'もどる',
    'winTitle': 'クリア！',
    'stars': '星 {n}',
    'stuck': '動かせる手がありません。戻すかやり直してください。',
    'errLocked': 'この容器はまだ使えません。',
    'errFull': 'いっぱいで入りません。',
    'errColor': '上の色が違うので入りません。',
    'errDone': 'そろった容器は動かせません。',
    'lockKey': '鍵付き',
    'lockFrozen': '凍結',
    'tube': '容器 {n}',
    'selected': '選択中',
    'levelLocked': 'まだ遊べません',
    'lives': 'ライフ {n}',
    'coins': 'コイン {n}',
    'nextLife': 'あと{n}分で回復',
    'noLivesTitle': 'ライフがありません',
    'noLivesBody': 'ライフが回復すると遊べます。',
    'watchAd': '広告を見て回復',
    'close': '閉じる',
    'extraTube': '空き容器を足す',
    'extraTubeCost': 'コイン {n}',
    'notEnoughCoins': 'コインが足りません。',
    'stuckLifeLost': '動かせる手がありません。ライフを1つ失いました。戻すかやり直してください。',
    'reward': 'コイン +{n}',
  },
  'en': {
    'appTitle': 'Everpuzz',
    'level': 'Level {n}',
    'moves': '{count, plural, one{# move} other{# moves}}',
    'undo': 'Undo',
    'restart': 'Restart',
    'next': 'Next',
    'back': 'Back',
    'winTitle': 'Cleared!',
    'stars': '{n} stars',
    'stuck': 'No moves left. Undo or restart.',
    'errLocked': 'This tube is not usable yet.',
    'errFull': 'It is full.',
    'errColor': 'The top color does not match.',
    'errDone': 'A finished tube cannot be moved.',
    'lockKey': 'Locked',
    'lockFrozen': 'Frozen',
    'tube': 'Tube {n}',
    'selected': 'Selected',
    'levelLocked': 'Not unlocked yet',
    'lives': 'Lives {n}',
    'coins': 'Coins {n}',
    'nextLife': 'Next life in {n} min',
    'noLivesTitle': 'No lives left',
    'noLivesBody': 'You can play again when a life is restored.',
    'watchAd': 'Watch an ad to restore',
    'close': 'Close',
    'extraTube': 'Add an empty tube',
    'extraTubeCost': '{n} coins',
    'notEnoughCoins': 'Not enough coins.',
    'stuckLifeLost': 'No moves left. You lost a life. Undo or restart.',
    'reward': '+{n} coins',
  },
};

const supportedLocales = {'ja', 'en'};

/// 画面から `L10n.of(context).tr('key')` で引く。
class L10n extends InheritedWidget {
  const L10n({super.key, required this.translator, required super.child});

  final Translator translator;

  static Translator of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<L10n>();
    assert(w != null, 'L10n がツリーにありません');
    return w!.translator;
  }

  @override
  bool updateShouldNotify(L10n old) =>
      old.translator.locale != translator.locale;
}

Translator translatorFor(String deviceLanguageTag) =>
    Translator(resolveLocale(deviceLanguageTag, supportedLocales), bundles);
