// lib/services/analytics_service.dart

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Singleton service for Firebase Analytics tracking
/// Provides centralized methods for logging events and user properties
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? _observer;

  /// Initialize Firebase Analytics
  Future<void> init() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      debugPrint('AnalyticsService: Initialized successfully');
    } catch (e) {
      debugPrint('AnalyticsService: Initialization error: $e');
    }
  }

  /// Get the analytics observer for navigation tracking
  FirebaseAnalyticsObserver? get observer => _observer;

  // ============================================================================
  // USER PROPERTIES
  // ============================================================================

  /// Set user property for segmentation
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    try {
      await _analytics?.setUserProperty(name: name, value: value);
      debugPrint('Analytics: Set user property $name = $value');
    } catch (e) {
      debugPrint('Analytics: Error setting user property: $e');
    }
  }

  /// Set user ID (Firebase UID)
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics?.setUserId(id: userId);
      debugPrint('Analytics: Set user ID: $userId');
    } catch (e) {
      debugPrint('Analytics: Error setting user ID: $e');
    }
  }

  /// Update all user properties at once
  Future<void> updateUserProperties({
    required String userType, // "premium", "free", "guest"
    required int totalGears,
    required int currentTrack,
    required int currentLevel,
    required int dayStreak,
    required String authMethod, // "apple", "anonymous"
    int? trainingSessionsCompleted,
  }) async {
    await setUserProperty(name: 'user_type', value: userType);
    await setUserProperty(name: 'total_gears', value: totalGears.toString());
    await setUserProperty(name: 'current_track', value: currentTrack.toString());
    await setUserProperty(name: 'current_level', value: currentLevel.toString());
    await setUserProperty(name: 'daily_streak', value: dayStreak.toString());
    await setUserProperty(name: 'auth_method', value: authMethod);
    if (trainingSessionsCompleted != null) {
      await setUserProperty(
        name: 'training_sessions',
        value: trainingSessionsCompleted.toString(),
      );
    }
  }

  // ============================================================================
  // SCREEN TRACKING
  // ============================================================================

  /// Log screen view
  Future<void> logScreenView({
    required String screenName,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _analytics?.logScreenView(
        screenName: screenName,
        screenClass: screenName,
      );
      if (parameters != null && parameters.isNotEmpty) {
        await logEvent(name: '${screenName}_view', parameters: parameters);
      }
      debugPrint('Analytics: Screen view - $screenName');
    } catch (e) {
      debugPrint('Analytics: Error logging screen view: $e');
    }
  }

  // ============================================================================
  // GENERIC EVENT LOGGING
  // ============================================================================

  /// Log a custom event with parameters
  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      // Convert all values to strings or numbers for Firebase
      final cleanParams = parameters?.map<String, Object>((key, value) {
        if (value is bool) {
          return MapEntry(key, value ? 'true' : 'false');
        }
        return MapEntry(key, value as Object);
      });

      await _analytics?.logEvent(
        name: name,
        parameters: cleanParams,
      );
      debugPrint('Analytics: Event - $name ${cleanParams ?? ""}');
    } catch (e) {
      debugPrint('Analytics: Error logging event $name: $e');
    }
  }

  // ============================================================================
  // APP LIFECYCLE EVENTS
  // ============================================================================

  Future<void> logAppOpen() async {
    await _analytics?.logAppOpen();
  }

  Future<void> logFirstOpen() async {
    await logEvent(name: 'first_open');
  }

  Future<void> logTutorialBegin() async {
    await _analytics?.logTutorialBegin();
  }

  Future<void> logTutorialComplete() async {
    await _analytics?.logTutorialComplete();
  }

  Future<void> logTutorialSkip() async {
    await logEvent(name: 'tutorial_skip');
  }

  // ============================================================================
  // AUTHENTICATION EVENTS
  // ============================================================================

  Future<void> logSignUp({required String method}) async {
    await _analytics?.logSignUp(signUpMethod: method);
  }

  Future<void> logLogin({required String method}) async {
    await _analytics?.logLogin(loginMethod: method);
  }

  Future<void> logSignOut() async {
    await logEvent(name: 'sign_out');
  }

  Future<void> logAccountLinked({
    required String fromMethod,
    required String toMethod,
  }) async {
    await logEvent(name: 'account_linked', parameters: {
      'from_method': fromMethod,
      'to_method': toMethod,
    });
  }

  // ============================================================================
  // LIVES SYSTEM EVENTS
  // ============================================================================

  Future<void> logLifeLost({
    required String context,
    required int livesRemaining,
  }) async {
    await logEvent(name: 'life_lost', parameters: {
      'context': context,
      'lives_remaining': livesRemaining,
    });
  }

  Future<void> logLifeEarned({
    required String source, // "training", "ad", "rate_app", "timer"
    required int livesNow,
  }) async {
    await logEvent(name: 'life_earned', parameters: {
      'source': source,
      'lives_now': livesNow,
    });
  }

  Future<void> logLivesPopupOpened({required int currentLives}) async {
    await logEvent(name: 'lives_popup_opened', parameters: {
      'current_lives': currentLives,
    });
  }

  // ============================================================================
  // CHALLENGE EVENTS (Home Page)
  // ============================================================================

  Future<void> logChallengeStarted({
    required String challengeType, // "logo", "flag"
    required String challengeName,
    required int livesBefore,
  }) async {
    await logEvent(name: 'challenge_started', parameters: {
      'challenge_type': challengeType,
      'challenge_name': challengeName,
      'lives_before': livesBefore,
    });
  }

  Future<void> logChallengeCompleted({
    required String challengeType,
    required String challengeName,
    required bool correct,
    required int livesAfter,
  }) async {
    await logEvent(name: 'challenge_completed', parameters: {
      'challenge_type': challengeType,
      'challenge_name': challengeName,
      'correct': correct ? 'true' : 'false',
      'lives_after': livesAfter,
    });
  }

  Future<void> logFlagTapped({
    required int levelNumber,
    required int trackNumber,
  }) async {
    await logEvent(name: 'flag_tapped', parameters: {
      'level_number': levelNumber,
      'track_number': trackNumber,
    });
  }

  Future<void> logLevelCompleted({
    required int track,
    required int level,
    required int flagsCorrect,
    required int flagsTotal,
    required int timeSeconds,
  }) async {
    await logEvent(name: 'level_completed', parameters: {
      'track': track,
      'level': level,
      'flags_correct': flagsCorrect,
      'flags_total': flagsTotal,
      'time_seconds': timeSeconds,
      'accuracy': ((flagsCorrect / flagsTotal) * 100).round(),
    });
  }

  Future<void> logLevelFailed({
    required int track,
    required int level,
    required int flagsCorrect,
    required int flagsTotal,
  }) async {
    await logEvent(name: 'level_failed', parameters: {
      'track': track,
      'level': level,
      'flags_correct': flagsCorrect,
      'flags_total': flagsTotal,
    });
  }

  // ============================================================================
  // DAILY STREAK EVENTS
  // ============================================================================

  Future<void> logStreakUpdated({
    required int newStreakCount,
    required String streakTitle,
  }) async {
    await logEvent(name: 'streak_updated', parameters: {
      'new_streak_count': newStreakCount,
      'streak_title': streakTitle,
    });
  }

  Future<void> logStreakMilestone({required int milestone}) async {
    await logEvent(name: 'streak_milestone', parameters: {
      'milestone': milestone,
    });
  }

  Future<void> logCalendarViewed() async {
    await logEvent(name: 'calendar_viewed');
  }

  Future<void> logDailyGoalCompleted({required int challengesCompleted}) async {
    await logEvent(name: 'daily_goal_completed', parameters: {
      'challenges_completed': challengesCompleted,
    });
  }

  // ============================================================================
  // TRAINING MODE EVENTS
  // ============================================================================

  Future<void> logTrainingStarted({
    required String module, // "brand", "model", etc.
    required bool isPremium,
    int? attemptsRemaining,
  }) async {
    await logEvent(name: 'training_started', parameters: {
      'module': module,
      'is_premium': isPremium ? 'true' : 'false',
      if (attemptsRemaining != null) 'attempts_remaining': attemptsRemaining,
    });
  }

  Future<void> logTrainingCompleted({
    required String module,
    required int correctCount,
    required int totalQuestions,
    required int timeSeconds,
  }) async {
    final score = '$correctCount/$totalQuestions';
    await logEvent(name: 'training_completed', parameters: {
      'module': module,
      'score': score,
      'correct_count': correctCount,
      'total_questions': totalQuestions,
      'time_seconds': timeSeconds,
      'accuracy': ((correctCount / totalQuestions) * 100).round(),
    });
  }

  Future<void> logTrainingQuestionAnswered({
    required String module,
    required int questionNumber,
    required bool correct,
    required int timeToAnswerSeconds,
  }) async {
    await logEvent(name: 'training_question_answered', parameters: {
      'module': module,
      'question_number': questionNumber,
      'correct': correct ? 'true' : 'false',
      'time_to_answer': timeToAnswerSeconds,
    });
  }

  Future<void> logTrainingLimitReached() async {
    await logEvent(name: 'training_limit_reached');
  }

  Future<void> logTrainingAdWatched() async {
    await logEvent(name: 'training_ad_watched');
  }

  Future<void> logTrainingUpgradePrompted() async {
    await logEvent(name: 'training_upgrade_prompted');
  }

  Future<void> logTrainingPersonalBest({
    required String module,
    required int newScore,
    required int previousBest,
  }) async {
    await logEvent(name: 'training_personal_best', parameters: {
      'module': module,
      'new_score': newScore,
      'previous_best': previousBest,
      'improvement': newScore - previousBest,
    });
  }

  Future<void> logTrainingPerfectScore({required String module}) async {
    await logEvent(name: 'training_perfect_score', parameters: {
      'module': module,
    });
  }

  // ============================================================================
  // ACHIEVEMENT EVENTS
  // ============================================================================

  Future<void> logAchievementUnlocked({
    required String achievementId,
    required String achievementName,
    required String category,
  }) async {
    await logEvent(name: 'achievement_unlocked', parameters: {
      'achievement_id': achievementId,
      'achievement_name': achievementName,
      'category': category,
    });
  }

  Future<void> logAchievementViewed({required String achievementId}) async {
    await logEvent(name: 'achievement_viewed', parameters: {
      'achievement_id': achievementId,
    });
  }

  Future<void> logAchievementsPageViewed({
    required int unlockedCount,
    required int lockedCount,
  }) async {
    await logEvent(name: 'achievements_page_viewed', parameters: {
      'unlocked_count': unlockedCount,
      'locked_count': lockedCount,
      'total': unlockedCount + lockedCount,
    });
  }

  // ============================================================================
  // LIBRARY & CAR BROWSING EVENTS
  // ============================================================================

  Future<void> logLibraryOpened() async {
    await logEvent(name: 'library_opened');
  }

  Future<void> logBrandSelected({required String brandName}) async {
    await logEvent(name: 'brand_selected', parameters: {
      'brand_name': brandName,
    });
  }

  Future<void> logCarViewed({
    required String brand,
    required String model,
  }) async {
    await logEvent(name: 'car_viewed', parameters: {
      'brand': brand,
      'model': model,
    });
  }

  // ============================================================================
  // PROFILE & SETTINGS EVENTS
  // ============================================================================

  Future<void> logProfileViewed() async {
    await logEvent(name: 'profile_viewed');
  }

  Future<void> logProfileEdited({required List<String> changedFields}) async {
    await logEvent(name: 'profile_edited', parameters: {
      'changed_fields': changedFields.join(','),
    });
  }

  Future<void> logPreloadImagesStarted() async {
    await logEvent(name: 'preload_images_started');
  }

  Future<void> logPreloadImagesCompleted({
    required int downloaded,
    required int cached,
    required int failed,
  }) async {
    await logEvent(name: 'preload_images_completed', parameters: {
      'downloaded': downloaded,
      'cached': cached,
      'failed': failed,
    });
  }

  Future<void> logTutorialReplayed() async {
    await logEvent(name: 'tutorial_replayed');
  }

  // ============================================================================
  // MILESTONE EVENTS
  // ============================================================================

  Future<void> logGearMilestone({
    required int milestone,
    required int currentGears,
  }) async {
    await logEvent(name: 'gear_milestone', parameters: {
      'milestone': milestone,
      'current_gears': currentGears,
    });
  }

  Future<void> logTrackUnlocked({required int trackNumber}) async {
    await logEvent(name: 'track_unlocked', parameters: {
      'track_number': trackNumber,
    });
  }

  // ============================================================================
  // MONETIZATION EVENTS (Ads & Premium)
  // ============================================================================

  Future<void> logViewPremiumPage() async {
    await logEvent(name: 'view_premium_page');
  }

  Future<void> logBeginCheckout({required String product}) async {
    await _analytics?.logBeginCheckout(
      value: 0.0,
      currency: 'USD',
      items: [
        AnalyticsEventItem(itemName: product, itemId: product),
      ],
    );
  }

  Future<void> logPurchase({
    required String product,
    required double value,
    required String currency,
  }) async {
    await _analytics?.logPurchase(
      value: value,
      currency: currency,
      items: [
        AnalyticsEventItem(itemName: product, itemId: product),
      ],
    );
  }

  Future<void> logAdImpression({
    required String adType, // "interstitial", "rewarded"
    String? adLocation,
  }) async {
    await _analytics?.logAdImpression(
      adPlatform: 'admob',
      adFormat: adType,
      adSource: adLocation,
    );
  }

  Future<void> logRewardedAdEarned({
    required String rewardType, // "life", "training_trials"
    int? rewardValue,
  }) async {
    await logEvent(name: 'rewarded_ad_earned', parameters: {
      'reward_type': rewardType,
      if (rewardValue != null) 'reward_value': rewardValue,
    });
  }

  Future<void> logAdLoadFailed({required String adType}) async {
    await logEvent(name: 'ad_load_failed', parameters: {
      'ad_type': adType,
    });
  }

  // ============================================================================
  // ERROR & PERFORMANCE TRACKING
  // ============================================================================

  Future<void> logImageLoadFailed({required String filePath}) async {
    await logEvent(name: 'image_load_failed', parameters: {
      'file_path': filePath,
    });
  }

  Future<void> logFirebaseError({
    required String errorType,
    required String errorMessage,
  }) async {
    await logEvent(name: 'firebase_error', parameters: {
      'error_type': errorType,
      'error_message': errorMessage,
    });
  }
}
