// AI画像など外部で作った素材の検査。台帳(assets/art_manifest.json)と照合する。
// 使い方: dart run tool/check_assets.dart [--strict]
//   通常: 配置済みの画像のサイズ・透過を検査(未配置は許容)
//   --strict(リリース前): required の未配置も失敗にする
import 'dart:convert';
import 'dart:io';

class PngInfo {
  const PngInfo(this.width, this.height, this.hasAlpha);

  final int width;
  final int height;
  final bool hasAlpha;
}

/// PNG のヘッダ(IHDR)と tRNS から寸法・透過の有無を読む。PNG でなければ null。
PngInfo? readPng(List<int> b) {
  const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (b.length < 33) return null;
  for (var i = 0; i < 8; i++) {
    if (b[i] != sig[i]) return null;
  }
  int u32(int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
  if (String.fromCharCodes(b.sublist(12, 16)) != 'IHDR') return null;
  final colorType = b[25];
  var alpha = colorType == 4 || colorType == 6;
  // パレット形式などは tRNS チャンクで透過を持つ。
  var o = 8;
  while (o + 8 <= b.length) {
    final len = u32(o);
    if (String.fromCharCodes(b.sublist(o + 4, o + 8)) == 'tRNS') alpha = true;
    o += 12 + len;
  }
  return PngInfo(u32(16), u32(20), alpha);
}

List<String> checkAssets(Map<String, Object?> manifest,
    {required String root, bool strict = false}) {
  final issues = <String>[];
  for (final s in manifest['slots']! as List<Object?>) {
    final slot = s! as Map<String, Object?>;
    final id = slot['id']! as String;
    final file = File('$root/${slot['path']}');
    if (!file.existsSync()) {
      if (strict && slot['required'] == true) issues.add('$id: 未配置(必須)');
      continue;
    }
    final info = readPng(file.readAsBytesSync());
    if (info == null) {
      issues.add('$id: PNGとして読めない');
      continue;
    }
    if (info.width != slot['width'] || info.height != slot['height']) {
      issues.add('$id: サイズ ${info.width}x${info.height} '
          '(期待 ${slot['width']}x${slot['height']})');
    }
    if (slot['transparent'] == true && !info.hasAlpha) {
      issues.add('$id: 透過が必要(背景が塗りつぶされている)');
    }
  }
  return issues;
}

void main(List<String> args) {
  final manifest =
      jsonDecode(File('assets/art_manifest.json').readAsStringSync())
          as Map<String, Object?>;
  final issues =
      checkAssets(manifest, root: '.', strict: args.contains('--strict'));
  if (issues.isEmpty) {
    stdout.writeln('assets OK');
    return;
  }
  issues.forEach(stderr.writeln);
  exit(1);
}
