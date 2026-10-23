import 'dart:convert';

import 'package:color_sort/color_sort.dart'
    show
        SeasonDef,
        TownConfig,
        TownError,
        TownResult,
        TownRules,
        TownState,
        TownStore;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_core/foundation.dart';
import 'package:puzzle_core/meta.dart' show AppSettings, SettingsStore;
import 'package:shared_preferences/shared_preferences.dart';

import 'art.dart';
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

/// 続けて何面クリアしたら、やさしい休憩の案内を出すか。止めはしない(案内だけ)。
/// 面が大量にあっても、遊べる量に上限は設けず、ライフ(行き詰まりで減る)だけで調整する。
const restNudgeEvery = 10;

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
  const PurchaseState({
    this.adsRemoved = false,
    this.credited = const [],
    this.grants = const [],
    this.usedOnce = const [],
  });

  final bool adsRemoved;

  /// 付与済みの取引ID(二重付与の防止)。
  final List<String> credited;

  /// 使えるようになった中身のID(飾り・スキン・着せ替え・追加面)。
  final List<String> grants;

  /// 1回きりの商品(スターターパック)で使用済みの商品ID。
  final List<String> usedOnce;

  factory PurchaseState.fromJson(Map<String, Object?>? j) {
    if (j == null) return const PurchaseState();
    List<String> list(String k) => ((j[k] as List?) ?? const []).cast<String>();
    return PurchaseState(
      adsRemoved: (j['adsRemoved'] as bool?) ?? false,
      credited: list('credited'),
      grants: list('grants'),
      usedOnce: list('usedOnce'),
    );
  }

  Map<String, Object?> toJson() => {
        'adsRemoved': adsRemoved,
        'credited': credited,
        'grants': grants,
        'usedOnce': usedOnce,
      };

  PurchaseState copyWith({
    bool? adsRemoved,
    List<String>? credited,
    List<String>? grants,
    List<String>? usedOnce,
  }) =>
      PurchaseState(
        adsRemoved: adsRemoved ?? this.adsRemoved,
        credited: credited ?? this.credited,
        grants: grants ?? this.grants,
        usedOnce: usedOnce ?? this.usedOnce,
      );
}

/// 面のパック(チャプター)。`assets/packs.json` の1件+読み込んだ中身。
class PackInfo {
  const PackInfo({
    required this.id,
    required this.pack,
    this.requires,
    this.unlockAfterPrevious = true,
  });

  final String id;

  final LevelPack pack;

  /// 遊ぶのに必要な中身(`grants` のID。例 `levels.extra1`)。null なら不要。
  final String? requires;

  /// 前のパックを全部クリアすると解放される(false なら条件は `requires` だけ)。
  final bool unlockAfterPrevious;
}

/// アプリ全体の状態(レベルパック・進行・ライフとコイン)。
class AppState extends ChangeNotifier {
  AppState({
    LevelPack? pack,
    List<PackInfo>? packs,
    this.activePackIndex = 0,
    required this.kv,
    required this.progress,
    required EconomyState economyState,
    this.clock = const SystemClock(),
    this.adGate,
    this.telemetry = const NoopTelemetry(),
    this.hintSolver = isolateHintSolver,
    this.purchaseGate,
    required this.townConfig,
    this.settings = AppSettings.defaults,
    this.art = ArtCatalog.empty,
    this.tutorialSeen = true,
    TownState townState = TownState.empty,
    Map<String, TownState>? towns,
    this.catalog = ShopCatalog.empty,
    PurchaseState purchaseState = const PurchaseState(),
  })  : assert(pack != null || packs != null),
        packs = packs ?? [PackInfo(id: pack!.packId, pack: pack)],
        economy = Economy(economyConfig, clock),
        townRules = TownRules(townConfig),
        _towns = {...?towns},
        _eco = economyState,
        _purchases = purchaseState,
        _progressStore = KeyValueProgressStore(kv) {
    if (townState != TownState.empty) this.townState = townState;
  }

  static const packsAsset = 'packages/color_sort/assets/packs.json';
  static const packAssetDir = 'packages/color_sort/assets/levels/';
  static const activePackKey = 'activePack';
  static const tutorialKey = 'tutorialSeen';
  static const economyKey = 'economy';
  static const economySchema = 1;
  static const purchasesKey = 'purchases';
  static const purchasesSchema = 1;
  static const townAsset = 'packages/color_sort/assets/town/buildings.json';
  static const catalogAsset = 'assets/shop/products.json';

  /// 全部のパック(チャプター)。一覧は `assets/packs.json`。
  final List<PackInfo> packs;

  /// いま選んでいるパック。面選択・プレイ・次の面は、このパックの中で動く。
  int activePackIndex;

  LevelPack get pack => packs[activePackIndex].pack;

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

  /// ユーザー設定(言語・動きを減らす)。
  AppSettings settings;

  /// 配置済みの画像素材。
  final ArtCatalog art;
  final TownRules townRules;

  /// はじめての案内を見たか。見ていなければ、起動時に案内を出す。
  bool tutorialSeen;

  Future<void> markTutorialSeen() async {
    tutorialSeen = true;
    notifyListeners();
    await kv.write(tutorialKey, '1');
  }

  final Map<String, TownState> _towns;

  /// いまのエリア(=いま遊ぶパック)の町。エリアごとに別の町を持つ。
  TownState get townState => _towns[activePackId] ?? TownState.empty;
  set townState(TownState v) => _towns[activePackId] = v;

  /// いまのエリア(パック)のID。
  String get activePackId => packs[activePackIndex].id;

  /// 町の保存キー。最初のエリアは従来の `town` のまま(移行なし)、ほかは `town.<id>`。
  static String townKeyFor(List<PackInfo> packs, int i) =>
      i == 0 ? TownStore.key : '${TownStore.key}.${packs[i].id}';

  TownStore _townStore() =>
      TownStore(kv, townConfig, storageKey: townKeyFor(packs, activePackIndex));

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

    /// テスト用。商品カタログを差し替える。
    ShopCatalog? catalogOverride,

    /// テスト用。画像素材の一覧を差し替える(省略時は同梱の画像を読む)。
    ArtCatalog? artOverride,
  }) async {
    final packList = await _loadPacks(bundle ?? rootBundle);
    // 解けない面を出荷しない(CIで検査済みだが、実行時にも念のため)。
    assert(packList.every((p) => p.pack.validate().isEmpty));
    final saved = await VersionedJsonStore(kv)
        .load(economyKey, currentVersion: economySchema);
    final b = bundle ?? rootBundle;
    final catalog = catalogOverride ??
        (purchaseGate == null
            ? ShopCatalog.empty
            : ShopCatalog.fromJson(await b.loadString(catalogAsset)));
    var purchases = PurchaseState.fromJson(await VersionedJsonStore(kv)
        .load(purchasesKey, currentVersion: purchasesSchema));
    if (purchaseGate != null) {
      try {
        // ストア側の権利を正とする(別端末での購入・返金を反映)。
        purchases =
            purchases.copyWith(adsRemoved: await purchaseGate.adsRemoved());
        purchases =
            _withOwned(purchases, catalog, await purchaseGate.ownedProducts());
      } catch (_) {
        // 取れない時は保存済みの値で続ける。
      }
    }
    final townConfig = TownConfig.fromJson(await b.loadString(townAsset));
    final totalLevels =
        packList.fold<int>(0, (a, p) => a + p.pack.levels.length);
    assert(townConfig.validate(levelCount: totalLevels).isEmpty);
    final progress = await KeyValueProgressStore(kv).load();
    final clearedNow = packList
        .expand((p) => p.pack.levels)
        .where((l) => progress.recordOf(l.id).cleared)
        .length;
    final savedActive = await kv.read(activePackKey);
    final activeIndex = packList.indexWhere((p) => p.id == savedActive);
    return AppState(
      townConfig: townConfig,
      tutorialSeen: await kv.read(tutorialKey) != null,
      settings: await SettingsStore(kv).load(),
      art: artOverride ?? await ArtCatalog.load(b),
      towns: {
        for (var i = 0; i < packList.length; i++)
          packList[i].id: await TownStore(kv, townConfig,
                  cellLimit: TownRules(townConfig).cellCount(clearedNow),
                  storageKey: townKeyFor(packList, i))
              .load(),
      },
      purchaseGate: purchaseGate,
      catalog: catalog,
      purchaseState: purchases,
      packs: packList,
      activePackIndex: activeIndex < 0 ? 0 : activeIndex,
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

  /// `assets/packs.json` を読み、各パックの面を読み込む。
  static Future<List<PackInfo>> _loadPacks(AssetBundle bundle) async {
    final list = (jsonDecode(await bundle.loadString(packsAsset))
        as Map<String, Object?>)['packs']! as List;
    return [
      for (final e in list.cast<Map<String, Object?>>())
        PackInfo(
          id: e['id']! as String,
          pack: LevelPack.fromJson(
              jsonDecode(await bundle.loadString('$packAssetDir${e['file']}'))
                  as Map<String, Object?>),
          requires: e['requires'] as String?,
          unlockAfterPrevious: (e['unlockAfterPrevious'] as bool?) ?? true,
        ),
    ];
  }

  /// 経過時間ぶんのライフ回復を反映した現在の経済状態(読むだけで状態は変えない)。
  EconomyState get current => economy.refresh(_eco);

  int get lives => current.lives;
  int get coins => current.coins;

  /// 広告削除の購入済みか(購入するとライフの制限も外れる)。
  bool get adsRemoved => _purchases.adsRemoved;

  bool get canPlay => adsRemoved || lives > 0;

  /// 店を出せるか(課金の窓口と商品がそろっているとき)。
  bool get shopAvailable => purchaseGate != null && catalog.shown.isNotEmpty;

  /// 次のライフが回復するまで。満タンなら null。
  Duration? get timeToNextLife => economy.timeToNextLife(_eco);

  int get extraTubeCost => economyConfig.boosterCosts[extraTubeBooster]!;
  int get hintCost => economyConfig.boosterCosts[hintBooster]!;

  bool get canAffordHint => coins >= hintCost;

  bool _isCleared(String levelId) => progress.recordOf(levelId).cleared;

  /// クリア済みの面数(全パックの合計。町の解放・マス数の元)。
  int get clearedLevels =>
      packs.expand((p) => p.pack.levels).where((l) => _isCleared(l.id)).length;

  /// パック [i] のクリア済みの面数。
  int clearedIn(int i) =>
      packs[i].pack.levels.where((l) => _isCleared(l.id)).length;

  bool isPackComplete(int i) => clearedIn(i) == packs[i].pack.levels.length;

  /// パック [i] を遊べるか(必要な中身を持っていて、前のパックを全部クリア済み)。
  bool isPackAvailable(int i) {
    final p = packs[i];
    if (p.requires != null && !owns(p.requires!)) return false;
    if (p.unlockAfterPrevious && i > 0 && !isPackComplete(i - 1)) return false;
    return true;
  }

  /// パックが遊べない理由(遊べるなら null)。'purchase' か 'previous'。
  String? packLockReason(int i) {
    final p = packs[i];
    if (p.requires != null && !owns(p.requires!)) return 'purchase';
    if (p.unlockAfterPrevious && i > 0 && !isPackComplete(i - 1)) {
      return 'previous';
    }
    return null;
  }

  /// パックを切り替える(遊べるパックだけ)。成功なら true。
  Future<bool> selectPack(int i) async {
    if (i < 0 || i >= packs.length || !isPackAvailable(i)) return false;
    activePackIndex = i;
    notifyListeners();
    await kv.write(activePackKey, packs[i].id);
    return true;
  }

  /// 次に遊ぶ面。いまのパックで最初の未クリア(全部クリア済みなら最後の面)。
  int get nextLevelIndex {
    final levels = pack.levels;
    final i = levels.indexWhere((l) => !_isCleared(l.id));
    return i < 0 ? levels.length - 1 : i;
  }

  /// いまのパックの先頭が、全パックを通した何番目の面か(背景・季節の元)。
  int get activeOffset {
    var n = 0;
    for (var i = 0; i < activePackIndex; i++) {
      n += packs[i].pack.levels.length;
    }
    return n;
  }

  /// 全パックを通した面番号(0始まり)。
  int globalLevelIndex(int levelIndex) => activeOffset + levelIndex;

  /// 「あそぶ」で進む先。いまのパックに未クリアの面があればそこ。無ければ、遊べる次のパックの
  /// 最初の未クリア。進めたらそのパックに切り替える。全部クリア済みなら最後の面のまま。
  Future<int> advanceToPlayable() async {
    final order = [
      activePackIndex,
      for (var i = 0; i < packs.length; i++)
        if (i != activePackIndex) i,
    ];
    for (final i in order) {
      if (isPackAvailable(i) && !isPackComplete(i)) {
        if (i != activePackIndex) await selectPack(i);
        return nextLevelIndex;
      }
    }
    return nextLevelIndex;
  }

  /// 次のパック(遊べるもの)があるか。最後の面のクリア後に「つぎのチャプターへ」を出す条件。
  int? get nextAvailablePack {
    for (var i = activePackIndex + 1; i < packs.length; i++) {
      if (isPackAvailable(i) && !isPackComplete(i)) return i;
    }
    return null;
  }

  /// 次のライフが回復する見込みの時刻。満タンなら null。
  DateTime? get nextLifeAt {
    final d = timeToNextLife;
    return d == null ? null : clock.now().add(d);
  }

  /// 町に建物を置く。成功なら null、失敗なら理由。
  Future<TownError?> placeBuilding(String id, int cell) async {
    final r = townRules.place(townState, id, cell,
        clearedLevels: clearedLevels, coins: coins);
    return _applyTown(r, 'town_place', id);
  }

  Future<TownError?> upgradeBuilding(String id) async => _applyTown(
      townRules.upgrade(townState, id, coins: coins), 'town_upgrade', id);

  Future<TownError?> moveBuilding(String id, int cell) async => _applyTown(
      townRules.move(townState, id, cell, clearedLevels: clearedLevels),
      'town_move',
      id);

  /// まだ知らせていない新しい建物の名前ID(静かに知らせる)。
  List<String> get newBuildingIds => [
        for (final b in townRules.newlyUnlocked(townState, clearedLevels)) b.id,
      ];

  Future<void> acknowledgeNewBuildings() async {
    townState = townRules.markUnlocksSeen(townState, clearedLevels);
    notifyListeners();
    await _townStore().save(townState);
  }

  /// いま遊ぶ面の季節(資材・テーマ)。
  SeasonDef? get currentSeason =>
      townRules.seasonAt(globalLevelIndex(nextLevelIndex));

  /// 終えた季節の数(= 町に贈られた季節の飾りの数)。
  int get seasonsDone => townRules.seasonsDone(clearedLevels);

  /// まだ知らせていない新しい季節の飾り(季節の番号)。
  List<int> get newSeasonObjects =>
      townRules.newSeasonObjects(townState, clearedLevels);

  Future<void> acknowledgeSeasonObjects() async {
    townState = townRules.markSeasonsSeen(townState, clearedLevels);
    notifyListeners();
    await _townStore().save(townState);
  }

  /// 建物を置く・育てたときに添える資材(いまの季節の2つ。建物と段階で回す)。
  List<String> materialsFor(String buildingId, int stage) {
    final m = currentSeason?.materials ?? const <String>[];
    if (m.isEmpty) return const [];
    final i = townConfig.buildings.indexWhere((b) => b.id == buildingId);
    final a = (i + stage) % m.length;
    return m.length == 1 ? [m[a]] : [m[a], m[(a + 1) % m.length]];
  }

  /// 設定を変えて保存する(言語・動きを減らす)。
  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    notifyListeners();
    await SettingsStore(kv).save(next);
  }

  /// 進行・コイン・町を初期に戻す(購入した内容・設定は残す)。
  Future<void> resetProgress() async {
    progress = const Progress();
    _eco = EconomyState.initial(economyConfig, clock.now());
    _towns.clear();
    notifyListeners();
    await _progressStore.save(progress);
    await _saveEconomy();
    for (var i = 0; i < packs.length; i++) {
      await TownStore(kv, townConfig, storageKey: townKeyFor(packs, i))
          .save(TownState.empty);
    }
  }

  /// 今日の「町の贈り物」を受け取れるか(1日1回。連続は問わない)。
  bool get canClaimGift => townRules.canClaimGift(townState, clock.now());

  /// 贈り物を受け取り、得たコインを返す(受け取れない時は0)。
  Future<int> claimGift() async {
    final r = townRules.claimGift(townState, clock.now());
    if (r == null) return 0;
    townState = r.state!;
    _eco = economy.addCoins(current, townConfig.dailyGift);
    notifyListeners();
    telemetry.log(const TelemetryEvent('town_gift'));
    await _townStore().save(townState);
    await _saveEconomy();
    return townConfig.dailyGift;
  }

  /// 町の住人(こびと)の人数。演出のみ。
  int get dwellers => townRules.dwellers(townState);

  /// 出すべき知らせ: 'complete'(完成)/'bloom'(満開)/null。1回ずつ。
  String? get pendingTownMilestone {
    if (townRules.shouldShowComplete(townState)) return 'complete';
    if (townRules.shouldShowBloom(townState)) return 'bloom';
    return null;
  }

  Future<void> acknowledgeMilestone(String which) async {
    townState = which == 'complete'
        ? townState.copyWith(completeShown: true)
        : townState.copyWith(bloomShown: true);
    notifyListeners();
    await _townStore().save(townState);
  }

  Future<TownError?> _applyTown(TownResult r, String event, String id) async {
    if (!r.ok) return r.error;
    if (r.cost > 0) {
      _eco = economy.spendCoins(current, r.cost)!;
    }
    townState = r.state!;
    notifyListeners();
    // 個人を特定しない値だけ送る(建物ID・段階・使ったコイン・クリア数)。
    telemetry.log(TelemetryEvent(event, {
      'buildingId': id,
      'stage': townState.placementOf(id)?.stage,
      'cost': r.cost,
      'clearedLevels': clearedLevels,
    }));
    await _townStore().save(townState);
    if (r.cost > 0) await _saveEconomy();
    return null;
  }

  /// クリア済みの面と、次の面だけ遊べる(戻ってやり直すのは自由)。
  bool isUnlocked(int index) =>
      _isCleared(pack.levels[index].id) || index == nextLevelIndex;

  /// 町に寄らずに続けてクリアした面数(休憩の案内に使う。町に戻るとリセット)。
  int winsSinceRest = 0;

  /// 休憩の案内を出す時期か(出したらカウントを戻す。出す時だけ true)。
  bool takeRestNudge() {
    if (winsSinceRest < restNudgeEvery) return false;
    final n = winsSinceRest;
    winsSinceRest = 0;
    telemetry.log(TelemetryEvent('rest_nudge', {'wins': n}));
    return true;
  }

  /// 町に戻った(ひと息ついた)ので、続けてクリアした数を戻す。
  void markRested() => winsSinceRest = 0;

  /// クリアを記録し、得たコインを返す(`clearReward`。星が増えない繰り返しは0)。
  Future<int> recordWin(
    int index, {
    required int moves,
    required int stars,
  }) async {
    winsSinceRest++;
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

  /// 買い切り商品の所有を中身(grants)に反映する。
  static PurchaseState _withOwned(
      PurchaseState p, ShopCatalog catalog, Set<String> owned) {
    final grants = {...p.grants};
    for (final id in owned) {
      final prod = catalog.byId(id);
      if (prod != null && prod.kind == ProductKind.unlock) {
        grants.addAll(prod.grants);
      }
    }
    return p.copyWith(grants: grants.toList());
  }

  /// 中身(飾り・スキン・着せ替え・追加面)を持っているか。
  bool owns(String grant) => _purchases.grants.contains(grant);

  /// 店に出す商品。
  List<ShopProduct> get shopProducts => catalog.shown;

  /// 購入済み(もう買えない)か。
  bool isPurchased(ShopProduct p) => switch (p.kind) {
        ProductKind.adsRemoval => adsRemoved,
        ProductKind.unlock => p.grants.every(owns),
        ProductKind.starterPack => _purchases.usedOnce.contains(p.id),
        _ => false,
      };

  /// 商品の購入。成功なら true。消費型は取引IDで重複を防いで付与する。
  Future<bool> buyProduct(String productId) async {
    final gate = purchaseGate;
    final product = catalog.byId(productId);
    if (gate == null || product == null || !product.enabled) return false;
    if (isPurchased(product)) return false;
    final r = await gate.buy(productId);
    if (r.status != BuyStatus.success) return false;

    // 消費型・1回きりは、取引IDが無い/処理済みなら付与しない。
    final consumable = product.kind == ProductKind.coinPack ||
        product.kind == ProductKind.lifeRefill ||
        product.kind == ProductKind.starterPack;
    final tx = r.transactionId;
    if (consumable) {
      if (tx == null || _purchases.credited.contains(tx)) return false;
      _purchases = _purchases.copyWith(credited: [..._purchases.credited, tx]);
    }
    switch (product.kind) {
      case ProductKind.adsRemoval:
        _purchases = _purchases.copyWith(adsRemoved: true);
      case ProductKind.coinPack:
        _eco = economy.addCoins(current, product.coins);
      case ProductKind.lifeRefill:
        _eco = current.copyWith(lives: economyConfig.maxLives);
      case ProductKind.unlock:
        _purchases = _purchases.copyWith(
            grants: {..._purchases.grants, ...product.grants}.toList());
      case ProductKind.starterPack:
        _eco = economy.addCoins(current, product.coins);
        _purchases = _purchases.copyWith(
          grants: {..._purchases.grants, ...product.grants}.toList(),
          usedOnce: [..._purchases.usedOnce, product.id],
        );
    }
    notifyListeners();
    telemetry.log(TelemetryEvent.purchase(productId));
    await _saveEconomy();
    await _savePurchases();
    return true;
  }

  /// 購入の復元(買い切りのみ。コインやライフ回復は復元されない)。
  Future<bool> restorePurchases() async {
    final gate = purchaseGate;
    if (gate == null) return false;
    final has = await gate.restore();
    _purchases = _withOwned(
      _purchases.copyWith(adsRemoved: has),
      catalog,
      await gate.ownedProducts(),
    );
    notifyListeners();
    await _savePurchases();
    return has;
  }

  Future<void> _savePurchases() => VersionedJsonStore(kv)
      .save(purchasesKey, purchasesSchema, _purchases.toJson());

  Future<void> _saveEconomy() =>
      VersionedJsonStore(kv).save(economyKey, economySchema, current.toJson());
}
