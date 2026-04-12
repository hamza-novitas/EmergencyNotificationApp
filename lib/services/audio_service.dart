import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Plays the emergency ringtone on loop, bypassing the iOS silent switch,
/// using AVAudioSession category `.playback`.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  AudioPlayer? _player;
  bool _configured = false;

  /// Configure the audio session once (call from main or on first use).
  Future<void> _configure() async {
    if (_configured) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        // .playback bypasses the iOS silent/ringer switch
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        // Android: use ALARM stream so it plays over Do Not Disturb
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          flags: AndroidAudioFlags.audibilityEnforced,
          usage: AndroidAudioUsage.alarm,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientExclusive,
        androidWillPauseWhenDucked: false,
      ));
      _configured = true;
    } catch (e) {
      debugPrint('[AudioService] configure failed: $e');
    }
  }

  /// Starts looping the bundled emergency MP3 at full volume.
  Future<void> playLoop() async {
    try {
      await _configure();

      final session = await AudioSession.instance;
      await session.setActive(true);

      await _player?.stop();
      _player?.dispose();
      _player = AudioPlayer();

      await _player!.setLoopMode(LoopMode.one);
      await _player!.setVolume(1.0);
      await _player!.setAsset('assets/audio/emergency_voice.mp3');
      await _player!.play();
    } catch (e) {
      debugPrint('[AudioService] playLoop failed: $e');
    }
  }

  /// Stops audio and deactivates the session so other apps can resume.
  Future<void> stop() async {
    try {
      await _player?.stop();
      _player?.dispose();
      _player = null;

      final session = await AudioSession.instance;
      await session.setActive(
        false,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      );
    } catch (e) {
      debugPrint('[AudioService] stop failed: $e');
    }
  }
}