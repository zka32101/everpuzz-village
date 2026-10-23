import 'dart:convert';
import 'dart:io';

/// 引き継ぎコード。端末の保存(進行・コイン・町・遊ぶ章)を、1つの文字列にまとめる。
/// 形: `EVP1.` + base64url(gzip(JSON))。壊れた・別物の文字列は null(読み込まない)。
class TransferCodec {
  static const prefix = 'EVP1.';
  static const version = 1;

  static String encode(Map<String, String> entries) {
    final json = jsonEncode({'v': version, 'e': entries});
    return prefix + base64Url.encode(gzip.encode(utf8.encode(json)));
  }

  /// 空白・改行は無視する(貼り付け時に入りやすい)。読めなければ null。
  static Map<String, String>? decode(String code) {
    try {
      final s = code.replaceAll(RegExp(r'\s'), '');
      if (!s.startsWith(prefix)) return null;
      final bytes = gzip.decode(base64Url.decode(s.substring(prefix.length)));
      final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (j['v'] != version) return null;
      return {
        for (final e in (j['e'] as Map<String, dynamic>).entries)
          e.key: e.value as String,
      };
    } on Object {
      return null;
    }
  }
}
