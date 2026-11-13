import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SirenService {
  static AudioPlayer? _player;
  static bool _isPlaying = false;
  static bool _isStarting = false;

  static bool get isPlaying => _isPlaying;

  static AudioPlayer _getPlayer() {
    if (_player == null) {
      _player = AudioPlayer();
      _player!.onPlayerStateChanged.listen((state) {
        _isPlaying = (state == PlayerState.playing);
      });
    }
    return _player!;
  }

  /// Starts the loud emergency deterrent siren with audio focus and looping.
  /// Returns true if playback succeeded, false if an error occurred.
  static Future<bool> startSiren() async {
    if (_isPlaying) return true;
    if (_isStarting) return false;
    _isStarting = true;

    try {
      final player = _getPlayer();

      // Configure alarm audio attributes for high audibility on Android
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
        ),
      );

      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(1.0);
      await player.play(AssetSource('sounds/siren_alarm.wav'));
      _isPlaying = true;
      return true;
    } catch (e) {
      debugPrint('[SirenService] Failed to play siren audio: $e');
      _isPlaying = false;
      return false;
    } finally {
      _isStarting = false;
    }
  }

  /// Stops the emergency siren immediately.
  static Future<void> stopSiren() async {
    try {
      if (_player != null) {
        await _player!.stop();
      }
    } catch (e) {
      debugPrint('[SirenService] Error stopping siren: $e');
    } finally {
      _isPlaying = false;
    }
  }

  static Future<void> dispose() async {
    try {
      if (_player != null) {
        await _player!.stop();
        await _player!.dispose();
        _player = null;
      }
    } catch (_) {}
    _isPlaying = false;
  }
}
