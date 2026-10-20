import 'package:flutter/material.dart';

import '../game/app_state.dart';
import '../game/purchases.dart';
import 'package:puzzle_core/foundation.dart' show Translator;

import '../l10n/strings.dart';

/// 店。広告削除(ライフ制限も外れる)とコインパック。確率要素は無い。
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.app});

  final AppState app;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late final Future<Map<String, String>> _prices =
      widget.app.purchaseGate!.prices(widget.app.shopProducts.map((p) => p.id));
  bool _busy = false;

  Future<void> _run(Future<bool> Function() action, String okKey) async {
    setState(() => _busy = true);
    final ok = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L10n.of(context).tr(okKey))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final app = widget.app;
    return Scaffold(
      appBar: AppBar(title: Text(t.tr('shop'))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => FutureBuilder<Map<String, String>>(
          future: _prices,
          builder: (context, snap) {
            final prices = snap.data ?? const <String, String>{};
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final p in app.shopProducts)
                  _tile(context, t, p, prices[p.id]),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('restore'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: _busy
                      ? null
                      : () => _run(app.restorePurchases, 'restored'),
                  child: Text(t.tr('restore')),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tile(
      BuildContext context, Translator t, ShopProduct p, String? price) {
    final app = widget.app;
    final owned = app.isPurchased(p);
    final (title, note) = switch (p.kind) {
      ProductKind.adsRemoval => (t.tr('adsRemoval'), t.tr('adsRemovalNote')),
      ProductKind.coinPack => (t.tr('coinPack', {'n': p.coins}), null),
      ProductKind.lifeRefill => (t.tr('lifeRefill'), t.tr('lifeRefillNote')),
      _ => (t.tr('product.${p.id}'), t.tr('product.${p.id}.note')),
    };
    // ライフが満タン・広告削除済みならライフ回復は買えない。
    final blocked = p.kind == ProductKind.lifeRefill &&
        (app.adsRemoved || app.lives >= economyConfig.maxLives);
    return Card(
      child: ListTile(
        key: Key('product_${p.id}'),
        title: Text(title),
        subtitle: note == null ? null : Text(note),
        trailing: owned
            ? Text(t.tr('owned'))
            : FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                // 価格が取れていない商品は買わせない。
                onPressed: _busy || price == null || blocked
                    ? null
                    : () => _run(() => app.buyProduct(p.id), 'purchased'),
                child: Text(price ?? '—'),
              ),
      ),
    );
  }
}
