import 'package:audioplayers/audioplayers.dart';

/// 効果音の種類。ファイルは `assets/sfx/<名前>.wav`。やさしい短い音だけ。
enum Sfx { select, pour, error, win, place, coin }

/// 効果音の窓口。端末の音は [AudioPlayersSound]、テストや音なしは [NoSound]。
abstract interface class SoundPlayer {
  Future<void> play(Sfx sfx);
}

class NoSound implements SoundPlayer {
  const NoSound();

  @override
  Future<void> play(Sfx sfx) async {}
}

/// audioplayers で鳴らす。失敗しても遊びは止めない(黙って無視)。
/// 重なっても切れないよう、音ごとに専用のプレーヤーを持つ。
class AudioPlayersSound implements SoundPlayer {
  AudioPlayersSound() {
    for (final s in Sfx.values) {
      _players[s] = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
    }
  }

  final _players = <Sfx, AudioPlayer>{};

  @override
  Future<void> play(Sfx sfx) async {
    try {
      final p = _players[sfx]!;
      await p.stop();
      await p.play(AssetSource('sfx/${sfx.name}.wav'));
    } on Object {
      // 音が出せなくても、遊びには影響しない。
    }
  }
}
