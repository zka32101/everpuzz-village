import 'package:flutter/material.dart';

import '../game/app_state.dart';
import '../l10n/strings.dart';
import 'play_screen.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.tr('appTitle'))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 96,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: app.pack.levels.length,
          itemBuilder: (context, i) {
            final unlocked = app.isUnlocked(i);
            final stars = app.progress.recordOf(app.pack.levels[i].id).stars;
            return Semantics(
              button: true,
              enabled: unlocked,
              label: unlocked
                  ? '${t.tr('level', {'n': i + 1})}, ${t.tr('stars', {
                          'n': stars
                        })}'
                  : '${t.tr('level', {'n': i + 1})}, ${t.tr('levelLocked')}',
              child: ExcludeSemantics(
                child: Material(
                  color: unlocked
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    key: Key('level-$i'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: unlocked
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PlayScreen(app: app, index: i),
                              ),
                            )
                        : null,
                    child: Center(
                      child: FittedBox(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              unlocked
                                  ? Text(
                                      '${i + 1}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    )
                                  : const Icon(Icons.lock_outline),
                              if (unlocked)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var s = 0; s < 3; s++)
                                      Icon(
                                        s < stars
                                            ? Icons.star
                                            : Icons.star_border,
                                        size: 14,
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
