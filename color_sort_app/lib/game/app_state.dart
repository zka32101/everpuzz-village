import 'dart:convert';

import 'package:color_sort/color_sort.dart'
    show TownConfig, TownError, TownResult, TownRules, TownState, TownStore;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_core/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'hint.dart';
import 'purchases.dart';

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
const hintBooster = 'hint';

/// 経済の設定データ(数値はここだけ。価格・商品IDはストア側でゲームが持つ)。
/// 通貨は1種類、報酬は固定のみ(確率報酬なし)。
const economyConfig = EconomyConfig(
  maxLives: 8,
  lifeRegenInterval: Duration(minutes: 15),
  winReward: 20,
  boosterCosts: {extraTubeBooster: 40, hintBooster: 20},
);

/// 星が1つ増えるごとのコイン。
const starBonus = 5;

/// クリア報酬(固定のみ。確率報酬なし)。
/// 初回クリアは、基本額(`winReward`)+(星-1)×[starBonus]。
/// 2回目以降は、星が増えた分だけ×[starBonus](同じ星で繰り返しても増えない)。
int clearReward({
  required bool firstClear,
  required int previousStars,
  required int newStars,
}) {
  if (firstClear) {
    return economyConfig.winReward + (newStars - 1).clamp(0, 2) * starBonus;
  }
  return (newStars - previousStars).clamp(0, 3) * starBonus;
}

/// 課金まわりの保存状態。
class PurchaseState {
  const PurchaseState({this.adsRemoved = false, this.credited = const []});

  final bool adsRemoved;

  /// コインを付与済みの取引ID(二重付与の防止)。
  final List<String> credited;

  factory PurchaseState.fromJson(Map<String, Object?>? j) => j == null
      ? const PurchaseState()
      : PurchaseState(
          adsRemoved: (j['adsRemoved'] as bool?) ?? false,
          credited: ((j['credited'] as List?) ?? const []).cast<String>(),
        );

  Map<String, Object?> toJson() =>
      {'adsRemoved': adsRemoved, 'credited': credited};

  PurchaseState copyWith({bool? adsRemoved, List<String>? credited}) =>
      PurchaseState(
        adsRemoved: adsRemoved ?? this.adsRemoved,
        credited: credited ?? this.credited,
      );
}

/// アプリ全体の状態(レベルパック・進行・ライフとコイン)。
class AppState extends ChangeNotifier {
  AppState({
    required this.pack,
    required this.kv,
    required this.progress,
    required EconomyState economyState,
    this.clock = const SystemClock(),
    this.adGate,
    this.telemetry = const NoopTelemetry(),
    this.hintSolver = isolateHintSolver,
    this.purchaseGate,
    required this.townConfig,
    this.townState = TownState.empty,
    this.catalog = ShopCatalog.empty,
    PurchaseState purchaseState = const PurchaseState(),
  })  : economy = Economy(economyConfig, clock),
        townRules = TownRules(townConfig),
        _eco = economyState,
        _purchases = purchaseState,
        _progressStore = KeyValueProgressStore(kv);

  static const packAsset = 'packages/color_sort/assets/levels/pack_main.json';
  static const economyKey = 'economy';
  static const economySchema = 1;
  static const purchasesKey = 'purchases';
  static const purchasesSchema = 1;
  static const townAsset = 'packages/color_sort/assets/town/buildings.json';
  static const catalogAsset = 'assets/shop/products.json';

  final LevelPack pack;
  final KeyValueStore kv;
  final Clock clock;

  /// リワード広告の窓口。未接続(null)なら広告ボタンは出さない。
  final AdGate? adGate;

  /// 計測の窓口。実体(analytics等)は後から差し込む。未接続なら何もしない。
  final Telemetry telemetry;

  /// ヒントを解く関数(既定は別isolate。テストでは同期版に差し替える)。
  final HintSolver hintSolver;

  /// 課金の窓口。未接続(null)なら店は出さない。
  final PurchaseGate? purchaseGate;
  final ShopCatalog catalog;

  final TownConfig townConfig;
  final TownRules townRules;
  TownState townState;

  final Economy economy;
  final ProgressStore _progressStore;
  Progress progress;
  EconomyState _eco;
  PurchaseState _purchases;

  static Future<AppState> load(
    KeyValueStore kv, {
    AssetBundle? bundle,
    Clock clock = const SystemClock(),
    AdGate? adGate,
    Telemetry telemetry = const NoopTelemetry(),
    HintSolver hintSolver = isolateHintSolver,
    PurchaseGate? purchaseGate,
  }) async {
    final raw = await (bundle ?? rootBundle).loadString(packAsset);
    final pack = LevelPack.fromJson(jsonDecode(raw) as Map<String, Object?>);
    // 解けない面を出荷しない(CIで検査済みだが、実行時にも念のため)。
    assert(pack.validate().isEmpty, pack.validate().join('\n'));
    final saved = await VersionedJsonStore(kv)
        .load(economyKey, currentVersion: economySchema);
    final b = bundle ?? rootBundle;
    final catalog = purchaseGate == null
        ? ShopCatalog.empty
        : ShopCatalog.fromJson(await b.loadString(catalogAsset));
    var purchases = PurchaseState.fromJson(await VersionedJsonStore(kv)
        .load(purchasesKey, currentVersion: purchasesSchema));
    if (purchaseGate != null) {
      try {
        // ストア側の権利を正とする(別端末での購入・返金を反映)。
        purchases =
            purchases.copyWith(adsRemoved: await purchaseGate.adsRemoved());
      } catch (_) {
        // 取れない時は保存済みの値で続ける。
      }
    }
    final townConfig = TownConfig.fromJson(await b.loadString(townAsset));
    assert(townConfig.validate(levelCount: pack.levels.length).isEmpty);
    final progress = await KeyValueProgressStore(kv).load();
    final clearedNow =
        pack.levels.where((l) => progress.recordOf(l.id).cleared).length;
    return AppState(
      townConfig: townConfig,
      townState: await TownStore(kv, townConfig,
              cellLimit: TownRules(townConfig).cellCount(clearedNow))
          .load(),
      purchaseGate: purchaseGate,
      catalog: catalog,
      purchaseState: purchases,
      pack: pack,
      kv: kv,
      clock: clock,
      adGate: adGate,
      telemetry: telemetry,
      hintSolver: hintSolver,
      progress: progress,
      economyState: saved == null
          ? EconomyState.initial(economyConfig, clock.now())
          : EconomyState.fromJson(saved),
    );
  }

  /// 経過時間ぶんのライフ回復を反映した現在の経済状態(読むだけで状態は変えない)。
  EconomyState get current => economy.refresh(_eco);

  int get lives => current.lives;
  int get coins => current.coins;

  /// 広告削除の購入済みか(購入するとライフの制限も外れる)。
  bool get adsRemoved => _purchases.adsRemoved;

  bool get canPlay => adsRemoved || lives > 0;

  /// 店を出せるか(課金の窓口と商品がそろっているとき)。
  bool get shopAvailable => purchaseGate != null && catalog.products.isNotEmpty;

  /// 次のライフが回復するまで。満タンなら null。
  Duration? get timeToNextLife => economy.timeToNextLife(_eco);

  int get extraTubeCost => economyConfig.boosterCosts[extraTubeBooster]!;
  int get hintCost => economyConfig.boosterCosts[hintBooster]!;

  bool get canAffordHint => coins >= hintCost;

  /// クリア済みの面数(町の解放・マス数の元)。
  int get clearedLevels =>
      pack.levels.where((l) => progress.recordOf(l.id).cleared).length;

  /// 次に遊ぶ面(最初の未クリア。全クリア済みなら最後の面)。
  int get nextLevelIndex =>
      progress.currentLevelIndex.clamp(0, pack.levels.length - 1);

  /// 次のライフが回復する見込みの時刻。満タンなら null。
  DateTime? get nextLifeAt {
    final d = timeToNextLife;
    return d == null ? null : clock.now().add(d);
  }

  /// 町に建物を置く。成功なら null、失敗なら理由。
  Future<TownError?> placeBuilding(String id, int cell) async {
    final r = townRules.place(townState, id, cell,
        clearedLevels: clearedLevels, coins: coins);
    return _applyTown(r);
  }

  Future<TownError?> upgradeBuilding(String id) async =>
      _applyTown(townRules.upgrade(townState, id, coins: coins));

  Future<TownError?> moveBuilding(String id, int cell) async => _applyTown(
      townRules.move(townState, id, cell, clearedLevels: clearedLevels));

  Future<TownError?> _applyTown(TownResult r) async {
    if (!r.ok) return r.error;
    if (r.cost > 0) {
      _eco = economy.spendCoins(current, r.cost)!;
    }
    townState = r.state!;
    notifyListeners();
    await TownStore(kv, townConfig).save(townState);
    if (r.cost > 0) await _saveEconomy();
    return null;
  }

  /// 順番にだけ進める(現在レベルまで遊べる)。
  bool isUnlocked(int index) => index <= progress.currentLevelIndex;

  /// クリアを記録し、得たコインを返す(`clearReward`。星が増えない繰り返しは0)。
  Future<int> recordWin(
    int index, {
    required int moves,
    required int stars,
  }) async {
    final id = pack.levels[index].id;
    final before = progress.recordOf(id);
    progress = progress.recordWin(
      id,
      stars: stars,
      moves: moves,
      levelIndex: index,
    );
    final reward = clearReward(
      firstClear: !before.cleared,
      previousStars: before.stars,
      newStars: stars,
    );
    if (reward > 0) _eco = economy.addCoins(current, reward);
    notifyListeners();
    await _progressStore.save(progress);
    await _saveEconomy();
    return reward;
  }

  /// 失敗(行き詰まり)を記録する。試行回数が増える。
  Future<void> recordFail(int index) async {
    progress = progress.recordFail(pack.levels[index].id);
    notifyListeners();
    await _progressStore.save(progress);
  }

  /// 行き詰まりでライフを1つ消費する。消費できたら true(ライフ切れなら false)。
  Future<bool> loseLife() async {
    if (adsRemoved) return false;
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

  /// ヒントの購入(その場で使う)。コイン不足なら false。
  /// 手が見つかってから呼ぶこと(見つからない時は課金しない)。
  Future<bool> buyHint() async {
    final next = economy.buyBooster(current, hintBooster);
    if (next == null) return false;
    _eco = economy.useBooster(next, hintBooster)!;
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
    telemetry.log(TelemetryEvent.adShown('restoreLife'));
    _eco = economy.restoreLife(_eco);
    notifyListeners();
    await _saveEconomy();
    return true;
  }

  /// 商品の購入。成功なら true。コインは取引IDで重複を防いで付与する。
  Future<bool> buyProduct(String productId) async {
    final gate = purchaseGate;
    final product = catalog.byId(productId);
    if (gate == null || product == null) return false;
    final r = await gate.buy(productId);
    if (r.status != BuyStatus.success) return false;
    switch (product.kind) {
      case ProductKind.adsRemoval:
        _purchases = _purchases.copyWith(adsRemoved: true);
      case ProductKind.coinPack:
        final tx = r.transactionId;
        // 取引IDが無い・処理済みのときは付与しない。
        if (tx == null || _purchases.credited.contains(tx)) return false;
        _eco = economy.addCoins(current, product.coins);
        _purchases =
            _purchases.copyWith(credited: [..._purchases.credited, tx]);
        await _saveEconomy();
    }
    notifyListeners();
    await _savePurchases();
    return true;
  }

  /// 購入の復元(広告削除のみ。コインは復元されない)。
  Future<bool> restorePurchases() async {
    final gate = purchaseGate;
    if (gate == null) return false;
    final has = await gate.restore();
    _purchases = _purchases.copyWith(adsRemoved: has);
    notifyListeners();
    await _savePurchases();
    return has;
  }

  Future<void> _savePurchases() => VersionedJsonStore(kv)
      .save(purchasesKey, purchasesSchema, _purchases.toJson());

  Future<void> _saveEconomy() =>
      VersionedJsonStore(kv).save(economyKey, economySchema, current.toJson());
}
