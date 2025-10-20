// lib/services/premium_service.dart
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Central place to manage Premium entitlement and training limits.
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  static const String _kIsPremium = 'isPremium';
  static const String _kTrainCount = 'training_attempts_today';
  static const String _kTrainDate = 'training_attempts_date';

  // Free daily limit for gated training challenges (set to 5 as requested)
  static const int freeDailyTrainingLimit = 5;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  int _attemptsToday = 0;
  int get attemptsToday => _attemptsToday;

  String _attemptsDate = '';
  String get attemptsDate => _attemptsDate;

  /// Initialize from SharedPreferences (call this at app start).
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_kIsPremium) ?? false;

    final today = _yyyyMmDd(DateTime.now());
    _attemptsDate = prefs.getString(_kTrainDate) ?? today;
    _attemptsToday = prefs.getInt(_kTrainCount) ?? 0;
    if (_attemptsDate != today) {
      _attemptsDate = today;
      _attemptsToday = 0;
      await _persistAttempts();
    }
  }

  /// Mark premium/unpremium and persist.
  Future<void> setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsPremium, value);
  }

  /// Whether ads should be shown (true when NOT premium).
  bool get shouldShowAds => !_isPremium;

  /// Can start a gated training challenge now?
  bool canStartTrainingNow() {
    if (_isPremium) return true;
    return _attemptsToday < freeDailyTrainingLimit;
  }

  /// Remaining gated attempts for the day (9999 for premium).
  int remainingTrainingAttempts() {
    if (_isPremium) return 9999;
    return (freeDailyTrainingLimit - _attemptsToday).clamp(0, freeDailyTrainingLimit);
  }

  /// Record one gated training attempt (no-op for premium).
  Future<void> recordTrainingStart() async {
    if (_isPremium) return;
    final today = _yyyyMmDd(DateTime.now());
    if (_attemptsDate != today) {
      _attemptsDate = today;
      _attemptsToday = 0;
    }
    _attemptsToday += 1;
    await _persistAttempts();
  }

  Future<void> _persistAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTrainCount, _attemptsToday);
    await prefs.setString(_kTrainDate, _attemptsDate);
  }

  String _yyyyMmDd(DateTime d) =>
      "${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}";
}