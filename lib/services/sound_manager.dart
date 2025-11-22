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
///
/// Sound Design Notes:
/// - Consider replacing current sounds with softer, more pleasant alternatives
/// - Use lower frequencies and gentler attack/decay for educational app context
/// - Target audience: learners in a focused, non-competitive environment
enum Sfx {
  // === UI Interactions ===
  // Button taps, menu selections (should be subtle, non-intrusive)
  SfxTap,
  SfxTap2,
  SfxTap3,

  // === Quiz Feedback ===
  // Correct answers (positive reinforcement, uplifting but not jarring)
  SfxCorrect,
  SfxCorrect2,
  SfxCorrect3,
  // Incorrect answers (gentle discouragement, educational tone)
  SfxIncorrect,
  SfxIncorrectSoft,

  // === Game Progress Events ===
  // Progression indicators (motivational, celebratory)
  SfxStreakUp,
  SfxLifeGained,
  SfxLifeLost,

  // === Achievements & Rewards ===
  // Major accomplishments (celebratory, memorable)
  SfxAchievement,
  SfxNewHighScore,
  SfxFanfareSmall,    // 1 star
  SfxFanfareMedium,   // 2 stars
  SfxFanfareBig,      // 3 stars

  // === Page Transitions ===
  // Navigation feedback (smooth, fluid)
  SfxWhooshIn,
  SfxWhooshOut,
  SfxPageFlip,

  // === System Notifications ===
  // Alerts and errors (attention-getting but not alarming)
  SfxNotification,
  SfxError,
  SfxCountdownTick,
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

  // Music tracks should be in OGG format for smaller file size
  // Recommended tracks:
  //   - Menu/Home: Upbeat, welcoming (90-110 BPM)
  //   - Training/Quiz: Focused, calm (70-90 BPM)
  //   - Challenges: Energetic, motivating (110-130 BPM)
  //   - Race Mode: Fast-paced, exciting (130-150 BPM)
  //
  // Example implementation:
  // static String _musicPathMenu() => 'assets/music/menu_theme.ogg';
  // static String _musicPathTraining() => 'assets/music/training_theme.ogg';
  // static String _musicPathChallenge() => 'assets/music/challenge_theme.ogg';
  // static String _musicPathRace() => 'assets/music/race_theme.ogg';

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);

    // Audio session configuration
    // Using .ambient + mixWithOthers allows users to play their own music (Spotify, etc.)
    // while using the app. For a learning app, this is often preferred behavior.
    //
    // Alternative: Use .soloAmbient (no mixWithOthers) for full audio control:
    // - Respects device silent switch
    // - Stops other audio when app starts
    // - More appropriate if you add prominent background music
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
  ///
  /// Usage examples:
  /// - await SoundManager.instance.playMusic(MusicTrack.menu);
  /// - await SoundManager.instance.playMusic(MusicTrack.training);
  /// - await SoundManager.instance.stopMusic();
  ///
  /// Consider creating a MusicTrack enum similar to Sfx enum:
  /// enum MusicTrack { menu, training, challenge, race }
  Future<void> playMusic(String assetPath) async {
    try {
      await _musicPlayer.setAsset(assetPath);
      await _musicPlayer.setLoopMode(LoopMode.one);
      await _musicPlayer.setVolume(_musicEnabled ? _musicVolume : 0.0);
      if (_musicEnabled) await _musicPlayer.play();
    } catch (e) {
      debugPrint('SoundManager.playMusic error: $e');
    }
  }

  Future<void> stopMusic() async => _musicPlayer.stop();

  Future<void> pauseMusic() async => _musicPlayer.pause();

  Future<void> resumeMusic() async {
    if (_musicEnabled && _musicPlayer.audioSource != null) {
      await _musicPlayer.play();
    }
  }

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