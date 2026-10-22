import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_core/foundation.dart' show Translator;
import 'package:puzzle_core/meta.dart';

import '../game/app_state.dart';
import '../l10n/strings.dart';
import 'shop_screen.dart';

/// ビルド時に渡す版の表記(`--dart-define=APP_VERSION=1.0.0`)。無ければ版は出さない。
const appVersion = String.fromEnvironment('APP_VERSION');

/// プライバシーポリシー・利用規約のURL(`--dart-define=PRIVACY_URL=...` / `TERMS_URL=...`)。
/// 無ければその項目は出さない(公開前に必ず用意する)。
const privacyUrl = String.fromEnvironment('PRIVACY_URL');
const termsUrl = String.fromEnvironment('TERMS_URL');

/// puzzle_core の標準メニュー構成に渡す、このアプリの状況。
MenuContext menuContextOf(AppState app) => MenuContext(
      shopAvailable: app.shopAvailable,
      privacyUrl: privacyUrl.isEmpty ? null : privacyUrl,
      termsUrl: termsUrl.isEmpty ? null : termsUrl,
      appVersion: appVersion,
      supportedLanguages: supportedLocales.toList(),
      credits: const [
        CreditEntry(titleKey: 'credit.images', body: 'credit.imagesBody'),
        CreditEntry(titleKey: 'credit.engine', body: 'credit.engineBody'),
      ],
    );

IconData _icon(String name) => switch (name) {
      'shop' => Icons.storefront,
      'settings' => Icons.settings,
      _ => Icons.info_outline,
    };

/// ホームの上部に並べる標準のメニュー(ショップ → 設定 → 情報)。
List<Widget> menuActions(BuildContext context, AppState app) {
  final t = L10n.of(context);
  return [
    for (final e in buildMenu(menuContextOf(app)))
      IconButton(
        key: Key('menu-${e.action.name}'),
        tooltip: t.tr(e.labelKey),
        icon: Icon(_icon(e.icon)),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => switch (e.action) {
            MenuAction.shop => ShopScreen(app: app),
            MenuAction.settings => SettingsScreen(app: app),
            MenuAction.info => InfoScreen(app: app),
          },
        )),
      ),
  ];
}

/// 設定。項目は標準の構成(`buildSettings`)に従う。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final ctx = menuContextOf(app);
    return Scaffold(
      appBar: AppBar(title: Text(t.tr('menu.settings'))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => ListView(
          children: [
            for (final section in buildSettings(ctx)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(t.tr(section.titleKey),
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              for (final item in section.items) _tile(context, t, ctx, item),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(
      BuildContext context, Translator t, MenuContext ctx, SettingItem item) {
    final s = app.settings;
    switch (item.id) {
      case SettingId.language:
        return ListTile(
          key: const Key('setting-language'),
          minVerticalPadding: 12,
          title: Text(t.tr(item.labelKey)),
          trailing: DropdownButton<String?>(
            key: const Key('languageDropdown'),
            value: s.languageOverride,
            onChanged: (v) => app.updateSettings(v == null
                ? s.copyWith(clearLanguage: true)
                : s.copyWith(languageOverride: v)),
            items: [
              DropdownMenuItem(
                  value: null, child: Text(t.tr('settings.languageDevice'))),
              for (final l in ctx.supportedLanguages)
                DropdownMenuItem(value: l, child: Text(t.tr('language.$l'))),
            ],
          ),
        );
      case SettingId.reduceMotion:
        return SwitchListTile(
          key: const Key('setting-reduceMotion'),
          title: Text(t.tr(item.labelKey)),
          value: s.reduceMotion,
          onChanged: (v) => app.updateSettings(s.copyWith(reduceMotion: v)),
        );
      case SettingId.restorePurchases:
        return ListTile(
          key: const Key('setting-restore'),
          minVerticalPadding: 12,
          title: Text(t.tr(item.labelKey)),
          onTap: () async {
            await app.restorePurchases();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.tr('settings.restored'))));
            }
          },
        );
      case SettingId.deleteData:
        return ListTile(
          key: const Key('setting-delete'),
          minVerticalPadding: 12,
          title: Text(t.tr(item.labelKey),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          onTap: () => _confirmDelete(context, t),
        );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Translator t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('deleteDialog'),
        title: Text(t.tr('settings.deleteTitle')),
        content: Text(t.tr('settings.deleteBody')),
        actions: [
          TextButton(
            key: const Key('deleteCancel'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.tr('settings.cancel')),
          ),
          TextButton(
            key: const Key('deleteConfirm'),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.tr('settings.deleteConfirm')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await app.resetProgress();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.tr('settingsDeleted'))));
    }
  }
}

/// 情報(プライバシー・規約・クレジット・版)。項目は標準の構成(`buildInfo`)に従う。
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key, required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final ctx = menuContextOf(app);
    return Scaffold(
      appBar: AppBar(title: Text(t.tr('menu.info'))),
      body: ListView(
        children: [
          for (final item in buildInfo(ctx))
            switch (item.kind) {
              InfoKind.link => ListTile(
                  key: Key('info-${item.id.name}'),
                  minVerticalPadding: 12,
                  title: Text(t.tr(item.labelKey)),
                  subtitle: Text(item.value!),
                  trailing: const Icon(Icons.copy),
                  // リンクを開く部品は入れていないので、URLをコピーする。
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: item.value!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL copied')));
                    }
                  },
                ),
              InfoKind.credits => Column(
                  key: const Key('info-credits'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(t.tr(item.labelKey),
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    for (final c in ctx.credits)
                      ListTile(
                        title: Text(t.tr(c.titleKey)),
                        subtitle: Text(t.tr(c.body)),
                      ),
                  ],
                ),
              InfoKind.version => ListTile(
                  key: const Key('info-version'),
                  title: Text(t.tr(item.labelKey)),
                  trailing: Text(item.value!),
                ),
            },
        ],
      ),
    );
  }
}
