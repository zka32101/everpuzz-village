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

  static const _columns = 4;

  String _name(Translator t, String id) => t.tr('building.$id');

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

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
    if (err != null && mounted) _say(_errorText(t, err));
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
      if (err != null && mounted) _say(_errorText(t, err));
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
    final label = p == null
        ? t.tr('townEmptyCell')
        : '${_name(t, p.buildingId)}, ${t.tr('stageOf', {'n': p.stage})}';
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: p == null
              ? scheme.surfaceContainerHighest
              : _color(context, app.townConfig.byId(p.buildingId)!.category),
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
          if (app.canClaimGift)
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
                    for (var i = 0; i < dwellers; i++)
                      const Icon(Icons.emoji_people, size: 20),
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
      body: ListenableBuilder(
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
                      style:
                          TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: () => setState(() => _moving = null),
                      child: Text(t.tr('cancel')),
                    ),
                  ],
                ),
              Expanded(
                child: GridView.builder(
                  key: const Key('townGrid'),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columns,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: cells,
                  itemBuilder: (context, i) => _cell(context, t, i),
                ),
              ),
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
                      child: OutlinedButton(
                        key: const Key('chooseLevel'),
                        style: OutlinedButton.styleFrom(
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
    );
  }
}
