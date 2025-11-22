import 'package:shared_preferences/shared_preferences.dart';

/// Enum-like representation of tutorial stages.
class TutorialStage {
  static const int notStarted = 0;
  static const int topRow = 1;
  static const int tabsReady = 2;
  static const int completed = 3;
}

/// Centralized helper that manages tutorial stage persistence and migration.
class TutorialService {
  TutorialService._private();

  static final TutorialService instance = TutorialService._private();

  static const String _stageKey = 'tutorial_stage';
  static const String _completedKey = 'tutorial_completed';
  static const String _legacyHasSeenKey = 'hasSeenTutorial';
  static const String firstFlagStartedKey = 'tutorial_first_flag_started';
  static const Map<String, String> _tabIntroKeys = {
    'home': 'tutorial_intro_home_shown',
    'training': 'tutorial_intro_training_shown',
    'race': 'tutorial_intro_race_shown',
    'library': 'tutorial_intro_library_shown',
    'profile': 'tutorial_intro_profile_shown',
  };

  SharedPreferences? _prefs;

  Future<void> init() async {
    final prefs = await _ensurePrefs();

    if (!prefs.containsKey(_stageKey)) {
      final bool legacySeen = prefs.getBool(_legacyHasSeenKey) ?? false;
      final int defaultStage =
          legacySeen ? TutorialStage.completed : TutorialStage.notStarted;
      await prefs.setInt(_stageKey, defaultStage);
      await prefs.setBool(_completedKey, defaultStage == TutorialStage.completed);
    } else {
      final int currentStage =
          prefs.getInt(_stageKey) ?? TutorialStage.notStarted;
      await prefs.setBool(_completedKey, currentStage == TutorialStage.completed);
      if (currentStage == TutorialStage.completed) {
        await prefs.setBool(_legacyHasSeenKey, true);
      }
    }
  }

  Future<int> getTutorialStage() async {
    final prefs = await _ensurePrefs();
    return prefs.getInt(_stageKey) ?? TutorialStage.notStarted;
  }

  Future<void> setTutorialStage(int stage) async {
    final prefs = await _ensurePrefs();
    await prefs.setInt(_stageKey, stage);
    if (stage == TutorialStage.completed) {
      await prefs.setBool(_completedKey, true);
      await prefs.setBool(_legacyHasSeenKey, true);
    } else {
      await prefs.setBool(_completedKey, false);
    }
  }

  Future<void> advanceToTabsStage() async {
    await setTutorialStage(TutorialStage.tabsReady);
  }

  Future<void> markTutorialCompleted() async {
    await setTutorialStage(TutorialStage.completed);
  }

  Future<void> resetTutorial() async {
    final prefs = await _ensurePrefs();
    await prefs.setInt(_stageKey, TutorialStage.notStarted);
    await prefs.setBool(_completedKey, false);
    await prefs.setBool(_legacyHasSeenKey, false);
    await prefs.remove(firstFlagStartedKey);
    for (final key in _tabIntroKeys.values) {
      await prefs.remove(key);
    }
  }

  Future<bool> isTutorialCompleted() async {
    final prefs = await _ensurePrefs();
    return prefs.getBool(_completedKey) ?? false;
  }

  Future<void> setFirstFlagStarted(bool value) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(firstFlagStartedKey, value);
  }

  Future<bool> isFirstFlagStarted() async {
    final prefs = await _ensurePrefs();
    return prefs.getBool(firstFlagStartedKey) ?? false;
  }

  Future<bool> hasShownTabIntro(String page) async {
    final prefs = await _ensurePrefs();
    return prefs.getBool(_tabIntroKeys[page] ?? 'tutorial_intro_$page') ?? false;
  }

  Future<void> markTabIntroShown(String page) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(_tabIntroKeys[page] ?? 'tutorial_intro_$page', true);
  }

  Future<void> resetTabIntros() async {
    final prefs = await _ensurePrefs();
    for (final key in _tabIntroKeys.values) {
      await prefs.remove(key);
    }
  }

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }
}
