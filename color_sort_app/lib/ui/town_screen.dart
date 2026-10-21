import 'package:color_sort/color_sort.dart'
    show BuildingDef, Placement, TownError;
import 'package:flutter/material.dart';
import 'package:puzzle_core/foundation.dart' show Translator;

import '../game/app_state.dart';
import '../game/art.dart';
import '../l10n/strings.dart';
import 'economy_bar.dart';
import 'level_select_screen.dart';
import 'play_screen.dart';
import 'shop_screen.dart';
import 'town_walk.dart';

/// ホーム = 町。置く・育てる・動かす。素材が届くまでは、図形+名前で代用する。
class TownScreen extends StatefulWidget {
  const TownScreen({super.key, required this.app});

  final AppState app;

  @override
  State<TownScreen> createState() => _TownScreenState();
}

class _TownScreenState extends State<TownScreen> {
  /// 「動かす」中の建物ID。
  String? _moving;
  bool _showingMilestone = false;

  AppState get app => widget.app;

  /// 町の背景は、いま遊ぶ面の段階に合わせて変わる。
  String? get _background => app.art.stageBackground(app.nextLevelIndex);

  static const _columns = 4;

  String _name(Translator t, String id) => t.tr('building.$id');

  /// 建物を置く・育てたときに添える、いまの季節の資材の名前(演出と文言だけ)。
  String _materials(Translator t, String id, int stage) => app
      .materialsFor(id, stage)
      .map((m) => t.tr('material.$m'))
      .join(t.tr('materialJoin'));

  /// ひとことの知らせ。下のボタン(あそぶ・面を選ぶ)を隠さないよう、その上に浮かせる。
  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
    ));

  String _errorText(Translator t, TownError e) => switch (e) {
        TownError.notEnoughCoins => t.tr('notEnoughCoins'),
        _ => t.tr('townNothingToPlace'),
      };

  Future<void> _tapCell(int cell) async {
    final t = L10n.of(context);
    final moving = _moving;
    if (moving != null) {
      setState(() => _moving = null);
      final err = await app.moveBuilding(moving, cell);
      if (err != null && err != TownError.sameCell && mounted) {
        _say(_errorText(t, err));
      }
      return;
    }
    final p = app.townState.at(cell);
    if (p == null) {
      await _showPlace(cell);
    } else {
      await _showDetail(p);
    }
  }

  Future<void> _showPlace(int cell) async {
    final t = L10n.of(context);
    final options = app.townRules.placeable(app.townState, app.clearedLevels);
    final picked = await showModalBottomSheet<BuildingDef>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          key: const Key('placeSheet'),
          shrinkWrap: true,
          children: [
            ListTile(title: Text(t.tr('townPlaceTitle'))),
            if (options.isEmpty)
              ListTile(title: Text(t.tr('townNothingToPlace'))),
            for (final b in options)
              ListTile(
                key: Key('place_${b.id}'),
                minVerticalPadding: 12,
                leading: _icon(b.category),
                title: Text(_name(t, b.id)),
                trailing: Text(t.tr('coinCost', {'n': b.costs.first})),
                enabled: app.coins >= b.costs.first,
                onTap: () => Navigator.of(ctx).pop(b),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final err = await app.placeBuilding(picked.id, cell);
    if (!mounted) return;
    if (err != null) {
      _say(_errorText(t, err));
    } else {
      _say(t.tr('townPlaced', {
        'name': _name(t, picked.id),
        'materials': _materials(t, picked.id, 1),
      }));
    }
  }

  Future<void> _showDetail(Placement p) async {
    final t = L10n.of(context);
    final def = app.townConfig.byId(p.buildingId)!;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          key: const Key('detailSheet'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_name(t, def.id), style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(t.tr('stageOf', {'n': p.stage})),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (p.stage < BuildingDef.stages)
                  FilledButton(
                    key: const Key('upgrade'),
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: app.coins >= def.upgradeCost(p.stage)
                        ? () => Navigator.of(ctx).pop('upgrade')
                        : null,
                    child: Text('${t.tr('upgrade')} (${t.tr('coinCost', {
                          'n': def.upgradeCost(p.stage)
                        })})'),
                  )
                else
                  Text(t.tr('stageMax')),
                OutlinedButton(
                  key: const Key('move'),
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => Navigator.of(ctx).pop('move'),
                  child: Text(t.tr('move')),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (action == 'upgrade') {
      final err = await app.upgradeBuilding(p.buildingId);
      if (!mounted) return;
      if (err != null) {
        _say(_errorText(t, err));
      } else {
        final stage = app.townState.placementOf(p.buildingId)?.stage ?? 2;
        _say(t.tr('townGrown', {
          'name': _name(t, p.buildingId),
          'materials': _materials(t, p.buildingId, stage),
        }));
      }
    } else if (action == 'move') {
      setState(() => _moving = p.buildingId);
    }
  }

  Icon _icon(String category) => Icon(switch (category) {
        'home' => Icons.home,
        'nature' => Icons.park,
        'life' => Icons.storefront,
        _ => Icons.flag,
      });

  Color _color(BuildContext context, String category) {
    final s = Theme.of(context).colorScheme;
    return switch (category) {
      'home' => s.primaryContainer,
      'nature' => s.tertiaryContainer,
      'life' => s.secondaryContainer,
      _ => s.errorContainer,
    };
  }

  Widget _cell(BuildContext context, Translator t, int cell) {
    final p = app.townState.at(cell);
    final scheme = Theme.of(context).colorScheme;
    final hasArt = p != null && app.art.has('${p.buildingId}_s${p.stage}');
    final label = p == null
        ? t.tr('townEmptyCell')
        : '${_name(t, p.buildingId)}, ${t.tr('stageOf', {'n': p.stage})}';
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: hasArt
              ? Colors.transparent
              : p == null
                  ? scheme.surfaceContainerHighest
                  : _color(
                      context, app.townConfig.byId(p.buildingId)!.category),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: Key('cell-$cell'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => _tapCell(cell),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Center(
                child: p == null
                    ? const Icon(Icons.add)
                    : _building(context, t, p),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasKobitoArt =>
      app.art.has('kobito_01') &&
      app.art.has('kobito_02') &&
      app.art.has('kobito_03');

  /// 町のマス(スクロール可)と、その上を歩くこびと。
  Widget _townArea(BuildContext context, Translator t, int cells) {
    const pad = 16.0;
    const gap = 8.0;
    final dwellers = app.dwellers;
    final walkers = dwellers > 0 &&
        app.art.has('kobito_01') &&
        app.art.has('kobito_02') &&
        app.art.has('kobito_03');
    return LayoutBuilder(
      builder: (context, c) {
        final cell = (c.maxWidth - pad * 2 - gap * (_columns - 1)) / _columns;
        final rows = (cells / _columns).ceil();
        final height = pad * 2 + rows * cell + (rows - 1) * gap;
        return SingleChildScrollView(
          child: Column(children: [
            SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GridView.builder(
                    key: const Key('townGrid'),
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(pad),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _columns,
                      mainAxisSpacing: gap,
                      crossAxisSpacing: gap,
                    ),
                    itemCount: cells,
                    itemBuilder: (context, i) => _cell(context, t, i),
                  ),
                  if (walkers)
                    Positioned.fill(
                      child: DwellerLayer(
                        key: const Key('dwellerLayer'),
                        count: dwellers,
                        walk: DwellerWalk(columns: _columns, cells: cells),
                        cellSize: cell,
                        gap: gap,
                        padding: pad,
                        carry: [
                          for (final m in app.currentSeason?.materials ??
                              const <String>[])
                            if (app.art.has('material_$m')) 'material_$m',
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _seasonStrip(context, t),
          ]),
        );
      },
    );
  }

  /// 終えた季節の飾りを並べる細い帯(画像があれば画像、無ければ季節の名前の文字)。
  Widget _seasonStrip(BuildContext context, Translator t) {
    final done = app.seasonsDone;
    if (done == 0) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: t.tr('seasonStrip'),
      child: SizedBox(
        key: const Key('seasonStrip'),
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (var i = 0; i < done; i++)
              _seasonObject(t, app.townConfig.seasons[i].theme),
          ],
        ),
      ),
    );
  }

  Widget _seasonObject(Translator t, String theme) {
    final id = 'season_$theme';
    final label = t.tr('season.$theme.object');
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: label,
        child: app.art.has(id)
            ? Image.asset(
                ArtCatalog.assetOf(id),
                key: Key('season-$theme'),
                height: 52,
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => Chip(label: Text(label)),
              )
            : Chip(key: Key('season-$theme'), label: Text(label)),
      ),
    );
  }

  /// こびと1人。画像があれば3種を順に、無ければアイコン。
  Widget _dweller(int i) {
    final id = 'kobito_0${i % 3 + 1}';
    if (!app.art.has(id)) return const Icon(Icons.emoji_people, size: 20);
    return Image.asset(
      ArtCatalog.assetOf(id),
      width: 32,
      height: 32,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => const Icon(Icons.emoji_people, size: 20),
    );
  }

  /// 建物。画像があれば画像(マスの下端にそろえる)、なければ図形+名前+段階の文字。
  Widget _building(BuildContext context, Translator t, Placement p) {
    final def = app.townConfig.byId(p.buildingId)!;
    final fallback = FittedBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _icon(def.category),
          Text(_name(t, p.buildingId)),
          Text(t.tr('stageOf', {'n': p.stage}),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
    final id = '${p.buildingId}_s${p.stage}';
    if (!app.art.has(id)) return fallback;
    return Image.asset(
      ArtCatalog.assetOf(id),
      key: Key('art-$id'),
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      // 名前・段階は文字でも示す(絵だけに頼らない)ので Semantics は外側で付く。
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  /// 贈り物・新しい建物の知らせ・こびと。急かさない、静かな表示。
  Widget _extras(BuildContext context, Translator t) {
    final newIds = app.newBuildingIds;
    final dwellers = app.dwellers;
    // 完成・満開の知らせは1回だけ、描画のあとで出す。
    final milestone = app.pendingTownMilestone;
    if (milestone != null && !_showingMilestone) {
      _showingMilestone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            key: Key('milestone_$milestone'),
            title: Text(t.tr(milestone == 'complete'
                ? 'townCompleteTitle'
                : 'townBloomTitle')),
            content: Text(t.tr(milestone == 'complete'
                ? 'townCompleteBody'
                : 'townBloomBody')),
            actions: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(t.tr('ok')),
              ),
            ],
          ),
        );
        await app.acknowledgeMilestone(milestone);
        _showingMilestone = false;
      });
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (newIds.isNotEmpty)
            Card(
              key: const Key('newBuilding'),
              child: ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text(t.tr('townNewBuilding', {
                  'name': newIds.map((id) => _name(t, id)).join('、'),
                })),
                trailing: TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: app.acknowledgeNewBuildings,
                  child: Text(t.tr('ok')),
                ),
              ),
            ),
          if (newIds.isEmpty && app.newSeasonObjects.isNotEmpty)
            Card(
              key: const Key('newSeasonObject'),
              child: ListTile(
                leading: const Icon(Icons.local_florist),
                title: Text(t.tr('townSeasonObject', {
                  'name': app.newSeasonObjects
                      .map((i) => t.tr(
                          'season.${app.townConfig.seasons[i].theme}.object'))
                      .join(t.tr('materialJoin')),
                })),
                trailing: TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: app.acknowledgeSeasonObjects,
                  child: Text(t.tr('ok')),
                ),
              ),
            ),
          if (newIds.isEmpty &&
              app.newSeasonObjects.isEmpty &&
              app.canClaimGift)
            Card(
              key: const Key('gift'),
              child: ListTile(
                leading: const Icon(Icons.card_giftcard),
                title: Text(t.tr('townGift')),
                subtitle:
                    Text(t.tr('townGiftGot', {'n': app.townConfig.dailyGift})),
                trailing: FilledButton(
                  key: const Key('claimGift'),
                  style:
                      FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: app.claimGift,
                  child: Text(t.tr('townGiftClaim')),
                ),
              ),
            ),
          if (dwellers > 0)
            Semantics(
              label: t.tr('dwellers', {'n': dwellers}),
              child: ExcludeSemantics(
                child: Wrap(
                  key: const Key('dwellers'),
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!_hasKobitoArt)
                      for (var i = 0; i < dwellers; i++) _dweller(i),
                    Text(t.tr('dwellers', {'n': dwellers})),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _play() {
    if (!app.canPlay) {
      showNoLivesDialog(context, app);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlayScreen(app: app, index: app.nextLevelIndex)));
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.tr('appTitle')),
        actions: [
          if (app.shopAvailable)
            IconButton(
              key: const Key('openShop'),
              tooltip: t.tr('openShop'),
              icon: const Icon(Icons.storefront),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ShopScreen(app: app))),
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          image: _background == null
              ? null
              : DecorationImage(
                  image: AssetImage(ArtCatalog.assetOf(_background!)),
                  fit: BoxFit.cover,
                  colorFilter: const ColorFilter.mode(
                      Color(0x66FFFFFF), BlendMode.srcOver),
                ),
        ),
        child: ListenableBuilder(
          listenable: app,
          builder: (context, _) {
            final cells = app.townRules.cellCount(app.clearedLevels);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: EconomyBar(app: app),
                ),
                _extras(context, t),
                if (_moving != null)
                  MaterialBanner(
                    key: const Key('moveBanner'),
                    content: Text(t.tr('moveHint')),
                    actions: [
                      TextButton(
                        style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48)),
                        onPressed: () => setState(() => _moving = null),
                        child: Text(t.tr('cancel')),
                      ),
                    ],
                  ),
                Expanded(child: _townArea(context, t, cells)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: const Key('play'),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 52)),
                          onPressed: _play,
                          child: Text(t.tr('play')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        // 背景の絵の上でも読めるよう、塗りのあるボタンにする。
                        child: FilledButton.tonal(
                          key: const Key('chooseLevel'),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 52)),
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => LevelSelectScreen(app: app))),
                          child: Text(t.tr('chooseLevel')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
