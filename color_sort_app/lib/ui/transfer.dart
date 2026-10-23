import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_core/foundation.dart' show Translator;

import '../game/app_state.dart';
import '../l10n/strings.dart';

/// 引き継ぎ。機種変更のときに、コードで進行・コイン・町を移す(サーバーは使わない)。
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key, required this.app});

  final AppState app;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _input = TextEditingController();
  String? _code;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _create() async {
    final code = await widget.app.createTransferCode();
    if (mounted) setState(() => _code = code);
  }

  Future<void> _import(Translator t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('transferConfirm'),
        title: Text(t.tr('transfer.confirmTitle')),
        content: Text(t.tr('transfer.confirmBody')),
        actions: [
          TextButton(
            key: const Key('transferCancel'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.tr('cancel')),
          ),
          FilledButton(
            key: const Key('transferOk'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.tr('transfer.confirmOk')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await widget.app.applyTransferCode(_input.text);
    if (!mounted) return;
    _say(t.tr(done ? 'transfer.done' : 'transfer.invalid'));
    if (done) _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.tr('transfer.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.tr('transfer.intro')),
          const SizedBox(height: 16),
          Text(t.tr('transfer.makeTitle'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.tonal(
            key: const Key('transfer-create'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _create,
            child: Text(t.tr('transfer.make')),
          ),
          if (_code != null) ...[
            const SizedBox(height: 8),
            Text(t.tr('transfer.madeNote')),
            const SizedBox(height: 8),
            Row(children: [
              OutlinedButton.icon(
                key: const Key('transfer-copy'),
                style:
                    OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.copy),
                label: Text(t.tr('transfer.copy')),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _code!));
                  if (mounted) _say(t.tr('transfer.copied'));
                },
              ),
            ]),
          ],
          const Divider(height: 40),
          Text(t.tr('transfer.loadTitle'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            key: const Key('transfer-input'),
            controller: _input,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: t.tr('transfer.hint'),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('transfer-load'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => _import(t),
            child: Text(t.tr('transfer.load')),
          ),
          const SizedBox(height: 16),
          Text(t.tr('transfer.purchaseNote'),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
