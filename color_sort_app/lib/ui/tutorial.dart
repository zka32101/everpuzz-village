import 'package:flutter/material.dart';

import '../game/app_state.dart';
import '../l10n/strings.dart';

/// はじめての案内。急かさず、いつでも飛ばせる。設定の「あそびかた」からも見直せる。
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.app, this.firstRun = false});

  final AppState app;

  /// 初回の自動表示か。初回は終えたら「見た」を記録して町へ進む。見直しは閉じるだけ。
  final bool firstRun;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  static const _icons = [
    Icons.touch_app_outlined,
    Icons.palette_outlined,
    Icons.undo,
    Icons.home_work_outlined,
  ];

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (widget.firstRun) {
      await widget.app.markTutorialSeen();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final last = _page == _icons.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.tr('tutorial.title')),
        automaticallyImplyLeading: false,
        actions: [
          if (!last)
            TextButton(
              key: const Key('tutorial-skip'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _finish,
              child: Text(t.tr('tutorial.skip')),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                key: const Key('tutorial-pages'),
                controller: _controller,
                itemCount: _icons.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_icons[i],
                            size: 96,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 24),
                        Text(t.tr('tutorial.t${i + 1}'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 12),
                        Text(t.tr('tutorial.b${i + 1}'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // いま何枚目かを、点と文字(「1/4」)の両方で示す。
            Text('${_page + 1}/${_icons.length}',
                key: const Key('tutorial-count')),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                key: Key(last ? 'tutorial-done' : 'tutorial-next'),
                style: FilledButton.styleFrom(minimumSize: const Size(160, 52)),
                onPressed: last
                    ? _finish
                    : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                child: Text(t.tr(last ? 'tutorial.done' : 'tutorial.next')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
