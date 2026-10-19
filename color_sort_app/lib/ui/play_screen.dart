import 'package:flutter/material.dart';
import 'package:puzzle_core/foundation.dart';

import '../game/app_state.dart';
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
        if (mounted) setState(() => _reward = reward);
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
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: EconomyBar(app: widget.app),
                ),
                Expanded(
                  child: SingleChildScrollView(
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
                              onTap: () => game.tap(i),
                            ),
                        ],
                      ),
                    ),
                  ),
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
                    onNext: hasNext && widget.app.canPlay
                        ? () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => PlayScreen(
                                  app: widget.app,
                                  index: widget.index + 1,
                                ),
                              ),
                            )
                        : null,
                    onBack: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
        );
      },
    );
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
    required this.onNext,
    required this.onBack,
  });

  final int stars;
  final int reward;
  final VoidCallback? onNext;
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
                  child: Text(t.tr('next')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
