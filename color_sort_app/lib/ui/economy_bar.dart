import 'package:flutter/material.dart';

import '../game/app_state.dart';
import '../l10n/strings.dart';
import 'shop_screen.dart';

/// ライフとコインの表示。アイコンに加えて数字でも示す(色・形だけに頼らない)。
class EconomyBar extends StatelessWidget {
  const EconomyBar({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final next = app.nextLifeAt;
        return Semantics(
          container: true,
          child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Chip(
                key: const Key('lives'),
                icon: Icons.favorite,
                text: t.tr(
                    'lives', {'n': '${app.lives}/${economyConfig.maxLives}'}),
              ),
              if (next != null)
                Text(
                  t.tr('nextLife', {'time': _hhmm(next)}),
                  key: const Key('nextLife'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              _Chip(
                key: const Key('coins'),
                icon: Icons.monetization_on,
                text: t.tr('coins', {'n': app.coins}),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(text),
        ],
      );
}

/// ライフ切れの案内。広告窓口があるときだけ回復ボタンを出す。
Future<void> showNoLivesDialog(BuildContext context, AppState app) {
  final t = L10n.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('noLives'),
      title: Text(t.tr('noLivesTitle')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.tr('noLivesBody')),
          const SizedBox(height: 8),
          EconomyBar(app: app),
        ],
      ),
      actions: [
        if (app.adGate != null)
          FilledButton(
            key: const Key('watchAd'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () async {
              final ok = await app.restoreLifeWithAd();
              if (ok && ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(t.tr('watchAd')),
          ),
        if (app.shopAvailable)
          TextButton(
            key: const Key('noLivesShop'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ShopScreen(app: app)),
              );
            },
            child: Text(t.tr('openShop')),
          ),
        TextButton(
          key: const Key('closeDialog'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.tr('close')),
        ),
      ],
    ),
  );
}

/// 「次のライフは12:30ごろ」の時刻部分(急かさない言い方にするため時刻で示す)。
String _hhmm(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:'
      '${l.minute.toString().padLeft(2, '0')}';
}
