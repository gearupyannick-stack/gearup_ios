// lib/services/sound_manager.dart
// Central low-level audio player using just_audio.
// Exposes playSfx(Sfx) and pooling for low-latency SFX.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

/// All SFX variants present in assets/sounds/ (match your file names).
/// Keep names short but explicit, PascalCase to match file naming.
enum Sfx {
  SfxTap,
  SfxTap2,
  SfxTap3,
  SfxCorrect,
  SfxCorrect2,
  SfxCorrect3,
  SfxIncorrect,
  SfxIncorrectSoft,
  SfxStreakUp,
  SfxLifeGained,
  SfxLifeLost,
  SfxAchievement,
  SfxFanfareSmall,
  SfxFanfareMedium,
  SfxFanfareBig,
  SfxWhooshIn,
  SfxWhooshOut,
  SfxNotification,
  SfxError,
  SfxNewHighScore,
  SfxCountdownTick,
  SfxPageFlip,
}

class SoundManager with WidgetsBindingObserver {
  SoundManager._internal();
  static final SoundManager instance = SoundManager._internal();

  // Preference keys
  static const _kMusicEnabledKey = 'audio_music_enabled';
  static const _kSfxEnabledKey = 'audio_sfx_enabled';
  static const _kMusicVolumeKey = 'audio_music_volume';
  static const _kSfxVolumeKey = 'audio_sfx_volume';
  static const _kHapticsEnabledKey = 'audio_haptics_enabled';

  // Players
  final AudioPlayer _musicPlayer = AudioPlayer();
  final int _sfxPoolSize = 6; // increased pool to avoid cut-offs
  late final List<AudioPlayer> _sfxPlayers;

  // Settings
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  bool _hapticsEnabled = true;
  double _musicVolume = 0.35;
  double _sfxVolume = 0.9;

  // Map enum -> asset path (must match file names in assets/sounds/)
  static String _sfxPath(Sfx s) {
    switch (s) {
      case Sfx.SfxTap: return 'assets/sounds/SfxTap.wav';
      case Sfx.SfxTap2: return 'assets/sounds/SfxTap2.wav';
      case Sfx.SfxTap3: return 'assets/sounds/SfxTap3.wav';
      case Sfx.SfxCorrect: return 'assets/sounds/SfxCorrect.wav';
      case Sfx.SfxCorrect2: return 'assets/sounds/SfxCorrect2.wav';
      case Sfx.SfxCorrect3: return 'assets/sounds/SfxCorrect3.wav';
      case Sfx.SfxIncorrect: return 'assets/sounds/SfxIncorrect.wav';
      case Sfx.SfxIncorrectSoft: return 'assets/sounds/SfxIncorrectSoft.wav';
      case Sfx.SfxStreakUp: return 'assets/sounds/SfxStreakUp.wav';
      case Sfx.SfxLifeGained: return 'assets/sounds/SfxLifeGained.wav';
      case Sfx.SfxLifeLost: return 'assets/sounds/SfxLifeLost.wav';
      case Sfx.SfxAchievement: return 'assets/sounds/SfxAchievement.wav';
      case Sfx.SfxFanfareSmall: return 'assets/sounds/SfxFanfareSmall.wav';
      case Sfx.SfxFanfareMedium: return 'assets/sounds/SfxFanfareMedium.wav';
      case Sfx.SfxFanfareBig: return 'assets/sounds/SfxFanfareBig.wav';
      case Sfx.SfxWhooshIn: return 'assets/sounds/SfxWhooshIn.wav';
      case Sfx.SfxWhooshOut: return 'assets/sounds/SfxWhooshOut.wav';
      case Sfx.SfxNotification: return 'assets/sounds/SfxNotification.wav';
      case Sfx.SfxError: return 'assets/sounds/SfxError.wav';
      case Sfx.SfxNewHighScore: return 'assets/sounds/SfxNewHighScore.wav';
      case Sfx.SfxCountdownTick: return 'assets/sounds/SfxCountdownTick.wav';
      case Sfx.SfxPageFlip: return 'assets/sounds/SfxPageFlip.wav';
    }
  }

  static String _musicPathTraining() => 'assets/sounds/SfxWhooshIn.wav'; // placeholder

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);

    // Audio session configuration
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.ambient,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.game,
        flags: AndroidAudioFlags.none,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));

    final prefs = await SharedPreferences.getInstance();
    _musicEnabled = prefs.getBool(_kMusicEnabledKey) ?? true;
    _sfxEnabled = prefs.getBool(_kSfxEnabledKey) ?? true;
    _hapticsEnabled = prefs.getBool(_kHapticsEnabledKey) ?? true;
    _musicVolume = prefs.getDouble(_kMusicVolumeKey) ?? 0.35;
    _sfxVolume = prefs.getDouble(_kSfxVolumeKey) ?? 0.9;

    await _musicPlayer.setLoopMode(LoopMode.one);
    await _musicPlayer.setVolume(_musicEnabled ? _musicVolume : 0.0);

    _sfxPlayers = List.generate(_sfxPoolSize, (_) => AudioPlayer());
    for (final p in _sfxPlayers) {
      await p.setVolume(_sfxEnabled ? _sfxVolume : 0.0);
    }
  }

  // App lifecycle: pause/resume music as appropriate
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _musicPlayer.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_musicEnabled && _musicPlayer.audioSource != null) _musicPlayer.play();
    }
  }

  // ===== getters/setters for prefs =====
  bool get musicEnabled => _musicEnabled;
  bool get sfxEnabled => _sfxEnabled;
  bool get hapticsEnabled => _hapticsEnabled;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  Future<void> setMusicEnabled(bool v) async {
    _musicEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMusicEnabledKey, v);
    await _musicPlayer.setVolume(v ? _musicVolume : 0.0);
    if (v && _musicPlayer.audioSource != null) await _musicPlayer.play();
  }

  Future<void> setSfxEnabled(bool v) async {
    _sfxEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSfxEnabledKey, v);
    for (final p in _sfxPlayers) await p.setVolume(v ? _sfxVolume : 0.0);
  }

  Future<void> setHapticsEnabled(bool v) async {
    _hapticsEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHapticsEnabledKey, v);
  }

  Future<void> setMusicVolume(double v) async {
    _musicVolume = v.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kMusicVolumeKey, _musicVolume);
    if (_musicEnabled) await _musicPlayer.setVolume(_musicVolume);
  }

  Future<void> setSfxVolume(double v) async {
    _sfxVolume = v.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kSfxVolumeKey, _sfxVolume);
    for (final p in _sfxPlayers) if (_sfxEnabled) await p.setVolume(_sfxVolume);
  }

  /// Preload SFX to warm decoders
  Future<void> preloadSfx([List<Sfx>? list]) async {
    final targets = list ?? Sfx.values;
    for (final s in targets) {
      final p = _sfxPlayers.first;
      try {
        await p.setAsset(_sfxPath(s));
        await p.stop();
      } catch (_) {
        // ignore missing assets during dev
      }
    }
  }

  /// Music controls (looped)
  Future<void> playMusicTraining() async {
    try {
      await _musicPlayer.setAsset(_musicPathTraining());
      await _musicPlayer.setLoopMode(LoopMode.one);
      await _musicPlayer.setVolume(_musicEnabled ? _musicVolume : 0.0);
      if (_musicEnabled) await _musicPlayer.play();
    } catch (e) {
      debugPrint('SoundManager.playMusicTraining error: $e');
    }
  }

  Future<void> stopMusic() async => _musicPlayer.stop();

  /// Play an Sfx enum (picks a free pooled player and plays asset).
  Future<void> playSfx(Sfx s) async {
    if (!_sfxEnabled) return;

    // Haptics mapped to categories
    if (_hapticsEnabled) {
      switch (s) {
        case Sfx.SfxTap:
        case Sfx.SfxTap2:
        case Sfx.SfxTap3:
          HapticFeedback.selectionClick();
          break;
        case Sfx.SfxCorrect:
        case Sfx.SfxCorrect2:
        case Sfx.SfxCorrect3:
        case Sfx.SfxAchievement:
          HapticFeedback.lightImpact();
          break;
        case Sfx.SfxIncorrect:
        case Sfx.SfxIncorrectSoft:
        case Sfx.SfxLifeLost:
          HapticFeedback.mediumImpact();
          break;
        default:
          break;
      }
    }

    final free = _sfxPlayers.firstWhere((p) => p.playing == false, orElse: () => _sfxPlayers[Random().nextInt(_sfxPlayers.length)]);
    try {
      await free.setAsset(_sfxPath(s));
      // small speed variance
      final speed = 1.0 + (Random().nextDouble() * 0.08 - 0.04);
      await free.setSpeed(speed);
      await free.seek(Duration.zero);
      await free.play();
    } catch (e) {
      debugPrint('SoundManager.playSfx error: $e');
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    for (final p in _sfxPlayers) await p.dispose();
    await _musicPlayer.dispose();
  }
}