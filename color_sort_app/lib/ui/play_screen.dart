import 'package:flutter/material.dart';

import '../game/app_state.dart';
import '../game/game_controller.dart';
import '../l10n/strings.dart';
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

  @override
  void initState() {
    super.initState();
    game = GameController(widget.app.pack.levels[widget.index])
      ..addListener(_onChange);
  }

  @override
  void dispose() {
    game.dispose();
    super.dispose();
  }

  void _onChange() {
    if (game.won && !_recorded) {
      _recorded = true;
      widget.app.recordWin(
        widget.index,
        moves: game.moves,
        stars: game.stars ?? 1,
      );
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
                _Message(game: game),
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
                        onPressed: game.restart,
                        icon: const Icon(Icons.refresh),
                        label: Text(t.tr('restart')),
                      ),
                    ],
                  ),
                ),
                if (game.won)
                  _WinPanel(
                    stars: game.stars ?? 1,
                    onNext: hasNext
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

  /// タップ領域 44pt 以上。
  static final _big = FilledButton.styleFrom(minimumSize: const Size(48, 48));
}

/// 失敗の理由・行き詰まりを短い文で見せる。
class _Message extends StatelessWidget {
  const _Message({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    String? text;
    if (game.stuck) {
      text = t.tr('stuck');
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
    required this.onNext,
    required this.onBack,
  });

  final int stars;
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
