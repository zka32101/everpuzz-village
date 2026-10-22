import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/app_state.dart';
import 'town_snapshot.dart';

/// 町が変わったら、ホーム画面ウィジェット用の絵を作って端末側(Android/iOS)へ渡す。
/// 端末側が未対応でも、アプリの動作には影響しない(失敗は黙って無視)。
class HomeWidgetSync {
  HomeWidgetSync(
    this.app, {
    MethodChannel? channel,
    this.debounce = const Duration(seconds: 2),
    Future<ui.Image?> Function(String id)? loadImage,
  })  : _channel = channel ?? const MethodChannel(channelName),
        _loadImage = loadImage ?? TownSnapshot.assetLoader;

  static const channelName = 'everpuzz/home_widget';

  final AppState app;
  final Duration debounce;
  final MethodChannel _channel;
  final Future<ui.Image?> Function(String id) _loadImage;
  Timer? _timer;
  String? _last;

  void start() {
    app.addListener(_schedule);
    _schedule();
  }

  void dispose() {
    app.removeListener(_schedule);
    _timer?.cancel();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(sync()));
  }

  /// 絵を作って渡す。同じ中身なら何もしない。渡したら true。
  @visibleForTesting
  Future<bool> sync() async {
    final snap = TownSnapshot(
      placements: app.townState.placements,
      cells: app.townRules.cellCount(app.clearedLevels),
      background:
          app.art.stageBackground(app.globalLevelIndex(app.nextLevelIndex)),
    );
    if (snap.signature == _last) return false;
    try {
      final png = await snap.render(_loadImage, art: app.art);
      if (png == null) return false;
      await _channel.invokeMethod<void>('update', {'png': png});
      _last = snap.signature;
      return true;
    } on MissingPluginException {
      return false; // 端末側が未対応
    } catch (_) {
      return false;
    }
  }
}
