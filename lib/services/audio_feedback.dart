// lib/services/audio_feedback.dart
// Central high-level audio router: SoundEvent -> Sfx variants.
// Use AudioFeedback.instance.playEvent(SoundEvent.tap) everywhere.

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'sound_manager.dart';

enum SoundEvent {
  tap,
  answerCorrect,
  answerWrong,
  streak,
  lifeGained,
  lifeLost,
  achievement,
  challengeComplete,
  notification,
  error,
  pageOpen,
  pageClose,
  countdownTick,
  pageFlip,
  newHighscore,
}

class AudioFeedback {
  AudioFeedback._internal();
  static final AudioFeedback instance = AudioFeedback._internal();

  final Random _rng = Random();

  // Map high-level events to Sfx variants (weighted lists possible)
  final Map<SoundEvent, List<Sfx>> _mapping = {
    SoundEvent.tap: [Sfx.SfxTap, Sfx.SfxTap2, Sfx.SfxTap3],
    SoundEvent.answerCorrect: [Sfx.SfxCorrect, Sfx.SfxCorrect2, Sfx.SfxCorrect3],
    SoundEvent.answerWrong: [Sfx.SfxIncorrect, Sfx.SfxIncorrectSoft],
    SoundEvent.streak: [Sfx.SfxStreakUp],
    SoundEvent.lifeGained: [Sfx.SfxLifeGained],
    SoundEvent.lifeLost: [Sfx.SfxLifeLost],
    SoundEvent.achievement: [Sfx.SfxAchievement],
    SoundEvent.challengeComplete: [Sfx.SfxFanfareSmall, Sfx.SfxFanfareMedium, Sfx.SfxFanfareBig],
    SoundEvent.notification: [Sfx.SfxNotification],
    SoundEvent.error: [Sfx.SfxError],
    SoundEvent.pageOpen: [],
    SoundEvent.pageClose: [],
    SoundEvent.countdownTick: [Sfx.SfxCountdownTick],
    SoundEvent.pageFlip: [],
    SoundEvent.newHighscore: [Sfx.SfxNewHighScore, Sfx.SfxAchievement],
  };

  // Throttle intervals (ms) per event
  final Map<SoundEvent, int> _minIntervalMs = {
    SoundEvent.tap: 60,
    SoundEvent.answerCorrect: 50,
    SoundEvent.answerWrong: 80,
    SoundEvent.streak: 200,
    SoundEvent.lifeGained: 200,
    SoundEvent.lifeLost: 200,
    SoundEvent.achievement: 700,
    SoundEvent.challengeComplete: 700,
    SoundEvent.notification: 300,
    SoundEvent.error: 200,
    SoundEvent.pageOpen: 150,
    SoundEvent.pageClose: 150,
    SoundEvent.countdownTick: 90,
    SoundEvent.pageFlip: 140,
    SoundEvent.newHighscore: 900,
  };

  // Basic priority (higher => more important)
  final Map<SoundEvent, int> _priority = {
    SoundEvent.challengeComplete: 10,
    SoundEvent.achievement: 9,
    SoundEvent.newHighscore: 9,
    SoundEvent.lifeLost: 6,
    SoundEvent.lifeGained: 6,
    SoundEvent.answerWrong: 4,
    SoundEvent.answerCorrect: 5,
    SoundEvent.tap: 1,
    SoundEvent.pageOpen: 1,
    SoundEvent.pageClose: 1,
  };

  final Map<SoundEvent, DateTime> _lastPlayed = {};

  Future<void> playEvent(SoundEvent event, { Map<String, dynamic>? meta, bool force = false }) async {
    try {
      final now = DateTime.now();
      final last = _lastPlayed[event];
      final minMs = _minIntervalMs[event] ?? 0;
      if (!force && last != null && now.difference(last).inMilliseconds < minMs) {
        if (kDebugMode) debugPrint('AudioFeedback: throttled $event');
        return;
      }

      // Don't let low-priority sounds interrupt a recent very-high-priority sound
      if (!force && _lastPlayed.isNotEmpty) {
        final recentEntry = _lastPlayed.entries.reduce((a,b) => a.value.isAfter(b.value) ? a : b);
        final recentEvent = recentEntry.key;
        final recentPriority = _priority[recentEvent] ?? 0;
        final thisPriority = _priority[event] ?? 0;
        final recentAge = now.difference(recentEntry.value).inMilliseconds;
        if (recentPriority >= 8 && recentAge < 700 && thisPriority < recentPriority) {
          if (kDebugMode) debugPrint('AudioFeedback: skipping $event due to recent $recentEvent');
          return;
        }
      }

      // Special case: challengeComplete with stars
      if (event == SoundEvent.challengeComplete && meta != null && meta['stars'] is int) {
        final stars = (meta['stars'] as int).clamp(0, 3);
        await _playFanfareForStars(stars);
        _lastPlayed[event] = DateTime.now();
        return;
      }

      final variants = _mapping[event];
      if (variants == null || variants.isEmpty) {
        if (kDebugMode) debugPrint('AudioFeedback: no mapping for $event');
        return;
      }

      final chosen = variants[_rng.nextInt(variants.length)];

      // Small variety - SoundManager already does speed variance. Just call it.
      await SoundManager.instance.playSfx(chosen);

      _lastPlayed[event] = DateTime.now();
    } catch (e) {
      if (kDebugMode) debugPrint('AudioFeedback error: $e');
    }
  }

  Future<void> _playFanfareForStars(int stars) async {
    switch (stars) {
      case 1:
        await SoundManager.instance.playSfx(Sfx.SfxFanfareSmall);
        break;
      case 2:
        await SoundManager.instance.playSfx(Sfx.SfxFanfareMedium);
        break;
      case 3:
      default:
        await SoundManager.instance.playSfx(Sfx.SfxFanfareBig);
        break;
    }
  }

  // Utility: change mapping at runtime
  void setMapping(SoundEvent event, List<Sfx> variants) {
    _mapping[event] = variants;
  }

  // Force play ignoring throttles
  Future<void> playEventForce(SoundEvent event, { Map<String, dynamic>? meta }) async {
    return playEvent(event, meta: meta, force: true);
  }
}