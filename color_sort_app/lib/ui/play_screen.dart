import 'package:flutter/material.dart';
import 'package:puzzle_core/foundation.dart';

import '../game/app_state.dart';
import '../game/art.dart';
import '../game/game_controller.dart';
import '../l10n/strings.dart';
import 'economy_bar.dart';
import 'tube_widget.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.app, required this.index});

  final AppState app;
  final int index;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  late final GameController game;
  bool _recorded = false;
  bool _stuckCharged = false; // 行き詰まりでのライフ消費は1回のプレイにつき1回
  bool _lifeLost = false;
  int _reward = 0;
  bool _restNudge = false;
  bool _hinting = false; // ヒントを計算中(二重に押せない)
  late int _attempt; // 何回目の挑戦か(1始まり。やり直しで増える)

  @override
  void initState() {
    super.initState();
    game = GameController(_level)..addListener(_onChange);
    _attempt = widget.app.progress.recordOf(_level.id).attempts + 1;
    widget.app.telemetry.log(TelemetryEvent.levelStart(_level.id, _attempt));
  }

  LevelEntry get _level => widget.app.pack.levels[widget.index];

  @override
  void dispose() {
    game.dispose();
    super.dispose();
  }

  void _onChange() {
    if (game.won && !_recorded) {
      _recorded = true;
      widget.app.telemetry
          .log(TelemetryEvent.levelWin(_level.id, _attempt, game.moves));
      widget.app
          .recordWin(widget.index, moves: game.moves, stars: game.stars ?? 1)
          .then((reward) {
        if (mounted) {
          setState(() {
            _reward = reward;
            _restNudge = widget.app.takeRestNudge();
          });
        }
      });
    }
    if (game.stuck && !_stuckCharged) {
      _stuckCharged = true;
      widget.app.telemetry
          .log(TelemetryEvent.levelFail(_level.id, _attempt, game.moves));
      widget.app.recordFail(widget.index);
      widget.app.loseLife().then((lost) {
        if (mounted) setState(() => _lifeLost = lost);
      });
    }
  }

  String? get _background =>
      widget.app.art.stageBackground(widget.app.globalLevelIndex(widget.index));

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final hasNext = widget.index + 1 < widget.app.pack.levels.length;
        return Scaffold(
          appBar: AppBar(
            title: Text(t.tr('level', {'n': widget.index + 1})),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    t.tr('moves', {'count': game.moves}),
                    key: const Key('moves'),
                  ),
                ),
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
                      // 盤面と競合しないよう、背景を白で薄めて落ち着かせる。
                      colorFilter: const ColorFilter.mode(
                          Color(0x66FFFFFF), BlendMode.srcOver),
                    ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: EconomyBar(app: widget.app),
                  ),
                  Expanded(
                    // 容器は、使える幅・高さに全部収まる大きさに縮める(下段が切れないように)。
                    // 縮めても足りない(極端に小さい画面・文字拡大)ときだけ、スクロールで見せる。
                    child: LayoutBuilder(builder: (context, box) {
                      final unit = _fitUnit(
                        count: game.board.tubes.length,
                        maxWidth: box.maxWidth - 32,
                        maxHeight: box.maxHeight - 32,
                        useArt: widget.app.art.has('tube_back') &&
                            widget.app.art.has('tube_front'),
                      );
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (var i = 0; i < game.board.tubes.length; i++)
                                TubeWidget(
                                  key: Key('tube-$i'),
                                  index: i,
                                  tube: game.board.tubes[i],
                                  lock: game.board.locks[i],
                                  usable: game.board.isUsable(i),
                                  selected: game.selected == i,
                                  hintRole: game.hint == null
                                      ? HintRole.none
                                      : game.hint!.$1 == i
                                          ? HintRole.from
                                          : game.hint!.$2 == i
                                              ? HintRole.to
                                              : HintRole.none,
                                  art: widget.app.art,
                                  theme: widget.app.art.themeFor(widget.app
                                      .globalLevelIndex(widget.index)),
                                  unit: unit,
                                  onTap: () => game.tap(i),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  _Message(game: game, lifeLost: _lifeLost),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          key: const Key('undo'),
                          style: _big,
                          onPressed: game.canUndo ? game.undo : null,
                          icon: const Icon(Icons.undo),
                          label: Text(t.tr('undo')),
                        ),
                        FilledButton.tonalIcon(
                          key: const Key('restart'),
                          style: _big,
                          onPressed: () {
                            game.restart();
                            _attempt++;
                            widget.app.telemetry.log(
                                TelemetryEvent.levelStart(_level.id, _attempt));
                            setState(() {
                              _stuckCharged = false;
                              _lifeLost = false;
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(t.tr('restart')),
                        ),
                        FilledButton.tonalIcon(
                          key: const Key('hint'),
                          style: _big,
                          onPressed: game.won || game.stuck || _hinting
                              ? null
                              : _showHint,
                          icon: const Icon(Icons.lightbulb_outline),
                          label: Text(
                            '${t.tr('hint')} (${t.tr('extraTubeCost', {
                                  'n': widget.app.hintCost
                                })})',
                          ),
                        ),
                        FilledButton.tonalIcon(
                          key: const Key('extraTube'),
                          style: _big,
                          onPressed: game.extraTubeUsed || game.won
                              ? null
                              : _buyExtraTube,
                          icon: const Icon(Icons.add_box_outlined),
                          label: Text(
                            '${t.tr('extraTube')} (${t.tr('extraTubeCost', {
                                  'n': widget.app.extraTubeCost
                                })})',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (game.won)
                    _WinPanel(
                      stars: game.stars ?? 1,
                      reward: _reward,
                      restNudge: _restNudge ? restNudgeEvery : 0,
                      nextIsChapter: !hasNext,
                      onNext: widget.app.canPlay &&
                              (hasNext || widget.app.nextAvailablePack != null)
                          ? () async {
                              final nav = Navigator.of(context);
                              var next = widget.index + 1;
                              if (!hasNext) {
                                // 最後の面: 遊べる次のチャプターへ(行き来は面選択から自由)
                                await widget.app
                                    .selectPack(widget.app.nextAvailablePack!);
                                next = widget.app.nextLevelIndex;
                              }
                              nav.pushReplacement(MaterialPageRoute(
                                builder: (_) => PlayScreen(
                                  app: widget.app,
                                  index: next,
                                ),
                              ));
                            }
                          : null,
                      onBack: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 容器が全部収まる 1スロットの大きさ。標準(46)から、収まるまで縮める(下限 30)。
  /// 横に並べる本数は、幅に入るだけ(標準の幅)で決まり、足りなければ段が増える。
  static double _fitUnit({
    required int count,
    required double maxWidth,
    required double maxHeight,
    required bool useArt,
  }) {
    const spacing = 12.0;
    var unit = TubeWidget.defaultUnit;
    final minUnit = TubeWidget.minUnitFor(useArt: useArt);
    while (unit > minUnit) {
      final w = TubeWidget.widthFor(unit, useArt: useArt);
      final perRow =
          ((maxWidth + spacing) / (w + spacing)).floor().clamp(1, count);
      final rows = (count / perRow).ceil();
      final h = TubeWidget.heightFor(unit, useArt: useArt);
      if (rows * h + (rows - 1) * spacing <= maxHeight) return unit;
      unit -= 1;
    }
    return minUnit;
  }

  /// 先に手を探し、見つかったときだけコインを払う(見つからなければ課金しない)。
  Future<void> _showHint() async {
    final t = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!widget.app.canAffordHint) {
      messenger.showSnackBar(SnackBar(content: Text(t.tr('notEnoughCoins'))));
      return;
    }
    setState(() => _hinting = true);
    final move = await widget.app.hintSolver(game.board);
    if (!mounted) return;
    setState(() => _hinting = false);
    if (move == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.tr('hintNone'))));
      return;
    }
    if (!await widget.app.buyHint() || !mounted) return;
    widget.app.telemetry
        .log(TelemetryEvent.boosterUsed(_level.id, hintBooster));
    // 読み上げ・色以外の手がかりとして、文でも示す(盤面の下のひとこと欄。
    // スナックバーだと下のボタンを隠すので使わない)。
    game.showHint(move);
  }

  Future<void> _buyExtraTube() async {
    final t = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await widget.app.buyExtraTube();
    if (!mounted) return;
    if (ok) {
      widget.app.telemetry
          .log(TelemetryEvent.boosterUsed(_level.id, extraTubeBooster));
      game.addTube();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(t.tr('notEnoughCoins'))));
    }
  }

  /// タップ領域 44pt 以上。
  static final _big = FilledButton.styleFrom(minimumSize: const Size(48, 48));
}

/// 失敗の理由・行き詰まりを短い文で見せる。
class _Message extends StatelessWidget {
  const _Message({required this.game, required this.lifeLost});

  final GameController game;
  final bool lifeLost;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    String? text;
    if (game.stuck) {
      text = t.tr(lifeLost ? 'stuckLifeLost' : 'stuck');
    } else if (game.hint != null) {
      final h = game.hint!;
      text = t.tr('hintText', {'from': h.$1 + 1, 'to': h.$2 + 1});
    } else if (game.lastError != null) {
      text = t.tr(switch (game.lastError!) {
        MoveError.locked => 'errLocked',
        MoveError.full => 'errFull',
        MoveError.color => 'errColor',
        MoveError.done => 'errDone',
      });
    }
    return SizedBox(
      height: 40,
      child: Center(
        child: text == null
            ? null
            : Semantics(
                liveRegion: true,
                child: Text(
                  text,
                  key: const Key('message'),
                  textAlign: TextAlign.center,
                ),
              ),
      ),
    );
  }
}

class _WinPanel extends StatelessWidget {
  const _WinPanel({
    required this.stars,
    required this.reward,
    this.restNudge = 0,
    required this.onNext,
    this.nextIsChapter = false,
    required this.onBack,
  });

  final int stars;
  final int reward;

  /// 0 でなければ、続けてクリアした面数を添えた休憩の案内を出す。
  final int restNudge;
  final VoidCallback? onNext;

  /// 次が同じパックの次の面ではなく、次のチャプターの最初であること。
  final bool nextIsChapter;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Container(
      key: const Key('win'),
      width: double.infinity,
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            t.tr('winTitle'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          // 星は数でも伝える(色・形だけに頼らない)。
          Semantics(
            label: t.tr('stars', {'n': stars}),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Icon(i < stars ? Icons.star : Icons.star_border, size: 32),
              ],
            ),
          ),
          if (reward > 0)
            Text(t.tr('reward', {'n': reward}), key: const Key('reward')),
          if (restNudge > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                t.tr('restNudge', {'n': restNudge}),
                key: const Key('restNudge'),
                textAlign: TextAlign.center,
              ),
            ),
          Wrap(
            spacing: 12,
            children: [
              TextButton(
                key: const Key('back'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onBack,
                child: Text(t.tr('back')),
              ),
              if (onNext != null)
                FilledButton(
                  key: const Key('next'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: onNext,
                  child: Text(t.tr(nextIsChapter ? 'nextChapter' : 'next')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
