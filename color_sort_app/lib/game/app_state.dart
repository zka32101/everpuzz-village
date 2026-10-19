import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_core/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences を puzzle_core の保存窓口に合わせるアダプタ。
class PrefsKeyValueStore implements KeyValueStore {
  PrefsKeyValueStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<String?> read(String key) async => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// アプリ全体の状態(レベルパックと進行)。
class AppState extends ChangeNotifier {
  AppState({required this.pack, required this.store, required this.progress});

  static const packAsset = 'packages/color_sort/assets/levels/pack_main.json';

  final LevelPack pack;
  final ProgressStore store;
  Progress progress;

  static Future<AppState> load(
    ProgressStore store, {
    AssetBundle? bundle,
  }) async {
    final raw = await (bundle ?? rootBundle).loadString(packAsset);
    final pack = LevelPack.fromJson(jsonDecode(raw) as Map<String, Object?>);
    // 解けない面を出荷しない(CIで検査済みだが、実行時にも念のため)。
    assert(pack.validate().isEmpty, pack.validate().join('\n'));
    return AppState(pack: pack, store: store, progress: await store.load());
  }

  /// 順番にだけ進める(現在レベルまで遊べる)。
  bool isUnlocked(int index) => index <= progress.currentLevelIndex;

  Future<void> recordWin(
    int index, {
    required int moves,
    required int stars,
  }) async {
    progress = progress.recordWin(
      pack.levels[index].id,
      stars: stars,
      moves: moves,
      levelIndex: index,
    );
    notifyListeners();
    await store.save(progress);
  }
}
