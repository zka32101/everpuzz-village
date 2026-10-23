import 'package:flutter/material.dart';

import '../game/app_state.dart';
import '../l10n/strings.dart';

/// 町のあゆみ。数字を競わず、いままでを眺めるだけの画面。
class JourneyScreen extends StatelessWidget {
  const JourneyScreen({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.tr('journey.title'))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final j = app.journey;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(t.tr('journey.intro')),
              const SizedBox(height: 12),
              _row(context, Icons.flag_outlined, t.tr('journey.levels'),
                  '${j.levelsCleared} / ${j.levelsTotal}',
                  key: const Key('journey-levels')),
              _row(context, Icons.star_outline, t.tr('journey.stars'),
                  '${j.stars} / ${j.starsMax}',
                  key: const Key('journey-stars')),
              _row(context, Icons.home_work_outlined, t.tr('journey.buildings'),
                  '${j.buildingsPlaced}',
                  key: const Key('journey-buildings')),
              _row(context, Icons.trending_up, t.tr('journey.stages'),
                  '${j.buildingStages}',
                  key: const Key('journey-stages')),
              _row(context, Icons.emoji_people_outlined,
                  t.tr('journey.dwellers'), '${j.dwellers}',
                  key: const Key('journey-dwellers')),
              _row(context, Icons.eco_outlined, t.tr('journey.seasons'),
                  '${j.seasonsDone}',
                  key: const Key('journey-seasons')),
              const Divider(height: 32),
              Text(t.tr('journey.areas'),
                  style: Theme.of(context).textTheme.titleMedium),
              for (final a in j.areas)
                _row(
                  context,
                  a.available ? Icons.map_outlined : Icons.lock_outline,
                  t.tr('area.${a.id}'),
                  a.available
                      ? '${a.levelsCleared} / ${a.levelsTotal}  ·  '
                          '${t.tr('journey.buildingsShort', {
                              'n': a.buildings
                            })}'
                      : t.tr('journey.notYet'),
                  key: Key('journey-area-${a.id}'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value,
      {Key? key}) {
    return ListTile(
      key: key,
      minVerticalPadding: 8,
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
