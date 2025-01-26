import 'package:just_audio/just_audio.dart';

class AudioController {
  final AudioPlayer _player = AudioPlayer();
  String? _currentType;

  Future<void> playAudio(String type) async {
    if (_currentType == type && _player.playing) {
      await _player.pause();
      return;
    }
    
    if (_currentType == type && !_player.playing) {
      await _player.play();
      return;
    }

    _currentType = type;
    String assetPath;
    switch (type) {
      case 'sleep':
        assetPath = 'assets/audio/sleep.wav';
        break;
      case 'light':
        assetPath = 'assets/audio/light.wav';
        break;
      case 'deep':
        assetPath = 'assets/audio/deep.wav';
        break;
      case 'rem':
        assetPath = 'assets/audio/rem.wav';
        break;
      default:
        return;
    }

    await _player.setAsset(assetPath);
    await _player.setLoopMode(LoopMode.all);
    await _player.play();
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  bool isPlaying(String type) {
    return _currentType == type && _player.playing;
  }

  bool isPaused(String type) {
    return _currentType == type && !_player.playing;
  }
} 