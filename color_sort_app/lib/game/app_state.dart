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

/// ブースターID。
const extraTubeBooster = 'extraTube';

/// 経済の設定データ(数値はここだけ。価格・商品IDはストア側でゲームが持つ)。
/// 通貨は1種類、報酬は固定のみ(確率報酬なし)。
const economyConfig = EconomyConfig(
  maxLives: 5,
  lifeRegenInterval: Duration(minutes: 30),
  winReward: 10,
  boosterCosts: {extraTubeBooster: 40},
);

/// アプリ全体の状態(レベルパック・進行・ライフとコイン)。
class AppState extends ChangeNotifier {
  AppState({
    required this.pack,
    required this.kv,
    required this.progress,
    required EconomyState economyState,
    this.clock = const SystemClock(),
    this.adGate,
  })  : economy = Economy(economyConfig, clock),
        _eco = economyState,
        _progressStore = KeyValueProgressStore(kv);

  static const packAsset = 'packages/color_sort/assets/levels/pack_main.json';
  static const economyKey = 'economy';
  static const economySchema = 1;

  final LevelPack pack;
  final KeyValueStore kv;
  final Clock clock;

  /// リワード広告の窓口。未接続(null)なら広告ボタンは出さない。
  final AdGate? adGate;

  final Economy economy;
  final ProgressStore _progressStore;
  Progress progress;
  EconomyState _eco;

  static Future<AppState> load(
    KeyValueStore kv, {
    AssetBundle? bundle,
    Clock clock = const SystemClock(),
    AdGate? adGate,
  }) async {
    final raw = await (bundle ?? rootBundle).loadString(packAsset);
    final pack = LevelPack.fromJson(jsonDecode(raw) as Map<String, Object?>);
    // 解けない面を出荷しない(CIで検査済みだが、実行時にも念のため)。
    assert(pack.validate().isEmpty, pack.validate().join('\n'));
    final saved = await VersionedJsonStore(kv)
        .load(economyKey, currentVersion: economySchema);
    return AppState(
      pack: pack,
      kv: kv,
      clock: clock,
      adGate: adGate,
      progress: await KeyValueProgressStore(kv).load(),
      economyState: saved == null
          ? EconomyState.initial(economyConfig, clock.now())
          : EconomyState.fromJson(saved),
    );
  }

  /// 経過時間ぶんのライフ回復を反映した現在の経済状態(読むだけで状態は変えない)。
  EconomyState get current => economy.refresh(_eco);

  int get lives => current.lives;
  int get coins => current.coins;
  bool get canPlay => lives > 0;

  /// 次のライフが回復するまで。満タンなら null。
  Duration? get timeToNextLife => economy.timeToNextLife(_eco);

  int get extraTubeCost => economyConfig.boosterCosts[extraTubeBooster]!;

  /// 順番にだけ進める(現在レベルまで遊べる)。
  bool isUnlocked(int index) => index <= progress.currentLevelIndex;

  /// クリアを記録する。初回クリアのみ固定報酬を返す(2回目以降は0)。
  Future<int> recordWin(
    int index, {
    required int moves,
    required int stars,
  }) async {
    final id = pack.levels[index].id;
    final first = !progress.recordOf(id).cleared;
    progress = progress.recordWin(
      id,
      stars: stars,
      moves: moves,
      levelIndex: index,
    );
    var reward = 0;
    if (first) {
      reward = economyConfig.winReward;
      _eco = economy.addCoins(current, reward);
    }
    notifyListeners();
    await _progressStore.save(progress);
    await _saveEconomy();
    return reward;
  }

  /// 行き詰まりでライフを1つ消費する。消費できたら true(ライフ切れなら false)。
  Future<bool> loseLife() async {
    final next = economy.consumeLife(_eco);
    if (next == null) return false;
    _eco = next;
    notifyListeners();
    await _saveEconomy();
    return true;
  }

  /// 空き容器ブースターの購入。コイン不足なら false。
  Future<bool> buyExtraTube() async {
    final next = economy.buyBooster(current, extraTubeBooster);
    if (next == null) return false;
    // その場で使うので在庫には積まない。
    _eco = economy.useBooster(next, extraTubeBooster)!;
    notifyListeners();
    await _saveEconomy();
    return true;
  }

  /// リワード広告でライフを1つ回復。広告が出せない・見終わらなかった場合は false。
  Future<bool> restoreLifeWithAd() async {
    final gate = adGate;
    if (gate == null) return false;
    final ok = await gate.showRewarded(RewardedPlacement.restoreLife);
    if (!ok) return false;
    _eco = economy.restoreLife(_eco);
    notifyListeners();
    await _saveEconomy();
    return true;
  }

  Future<void> _saveEconomy() =>
      VersionedJsonStore(kv).save(economyKey, economySchema, current.toJson());
}
