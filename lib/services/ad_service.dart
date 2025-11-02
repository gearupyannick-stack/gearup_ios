// lib/services/ad_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AdService: singleton manager for Mobile Ads + UMP consent + counters.
/// - Handles 2 interstitials and 3 rewarded ads (based on your mapping)
/// - Counters:
///    * every 2 races => Interstitial_Race
///    * every 5 challenges => Interstitial_Challenge
class AdService {
  AdService._privateConstructor();
  static final AdService instance = AdService._privateConstructor();

  bool _initialized = false;
  bool useTestAds = false;

  // --- iOS Production ad unit IDs ---
  // ⚠️ IMPORTANT: Replace these with your actual iOS ad unit IDs from AdMob Console
  // These are PLACEHOLDER values - you need to create iOS ad units in AdMob
  final String _interstitialRaceUnit =
      'ca-app-pub-3327975632345057/3650339117'; 
  final String _interstitialChallengeUnit =
      'ca-app-pub-3327975632345057/1314043718'; 

  final String _rewardedHomeLifeUnit =
      'ca-app-pub-3327975632345057/1254333960'; 
  final String _rewardedHomePassUnit =
      'ca-app-pub-3327975632345057/8729499309'; 
  final String _rewardedTrainingTrialsUnit =
      'ca-app-pub-3327975632345057/3940207055'; 

  // Google sample test IDs (work on both iOS and Android)
  final String _testInterstitial =
      'ca-app-pub-3940256099942544/4411468910'; // iOS test interstitial
  final String _testRewarded =
      'ca-app-pub-3940256099942544/1712485313'; // iOS test rewarded

  // In-memory ads
  InterstitialAd? _interstitialRace;
  InterstitialAd? _interstitialChallenge;

  RewardedAd? _rewardedHomeLife;
  RewardedAd? _rewardedHomePass;
  RewardedAd? _rewardedTrainingTrials;

  // SharedPreferences keys
  static const String _kRaceCounterKey = 'prefs_race_inter_count';
  static const String _kChallengeCounterKey = 'prefs_challenge_inter_count';

  // Thresholds
  static const int _raceThreshold = 2;
  static const int _challengeThreshold = 5;

  SharedPreferences? _prefs;

  /// Initialize the service (call from main before runApp ideally).
  /// set testMode=true while developing on your device/emulator.
  Future<void> init({bool testMode = false}) async {
    if (_initialized) return;
    useTestAds = testMode;

    _prefs = await SharedPreferences.getInstance();

    // Initialize UMP consent flow
    await _initUMP();

    // Initialize Mobile Ads
    await MobileAds.instance.initialize();
    debugPrint('MobileAds initialized');

    if (useTestAds) {
      // Optionally register test devices; "TEST_EMULATOR" is a placeholder
      final config = RequestConfiguration(testDeviceIds: <String>["TEST_EMULATOR"]);
      await MobileAds.instance.updateRequestConfiguration(config);
    }

    // Preload ads
    _loadAllInterstitials();
    _loadAllRewardeds();

    _initialized = true;
  }

  Future<void> _initUMP() async {
    try {
      // Use google_mobile_ads UMP helpers (ConsentRequestParameters, ConsentInformation, ConsentForm...)
      final params = ConsentRequestParameters(); // default OK; you can add debug settings if needed

      // requestConsentInfoUpdate uses callback-style API
      final completer = Completer<void>();

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          // success: consent info updated
          debugPrint('UMP: consent info updated');

          try {
            final available = await ConsentInformation.instance.isConsentFormAvailable();
            debugPrint('UMP: consent form available = $available');
            if (available) {
              // load and show the form if required (this loads + shows if needed)
              await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
                if (error != null) {
                  debugPrint('UMP: consent form dismissed with error: ${error.message}');
                } else {
                  debugPrint('UMP: consent form dismissed (no error)');
                }
              });
            }
          } catch (e) {
            debugPrint('UMP: error while loading/showing consent form: $e');
          }

          completer.complete();
        },
        (FormError error) {
          // failure to update consent info
          debugPrint('UMP: requestConsentInfoUpdate failed: ${error.message}');
          completer.complete();
        },
      );

      // wait for the callbacks to finish before returning
      await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('UMP: requestConsentInfoUpdate timed out');
        return;
      });
    } catch (e) {
      debugPrint('UMP init error: $e');
      // non-fatal: continue — ads may still function (non-personalized) until consent status resolved
    }
  }

  // ---------------------------
  // Helper to choose test or prod unit
  // ---------------------------
  String _chooseUnit({required bool rewarded, required String prodUnit}) {
    if (useTestAds) return rewarded ? _testRewarded : _testInterstitial;
    return prodUnit;
  }

  // ---------------------------
  // INTERSTITIALS
  // ---------------------------
  void _loadAllInterstitials() {
    _loadInterstitialRace();
    _loadInterstitialChallenge();
  }

  void _loadInterstitialRace() {
    final unitId = _chooseUnit(rewarded: false, prodUnit: _interstitialRaceUnit);
    InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Interstitial (Race) loaded');
          _interstitialRace = ad;
          _interstitialRace!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial (Race) failed to load: ${err.message}');
          _interstitialRace = null;
          Future.delayed(const Duration(seconds: 10), _loadInterstitialRace);
        },
      ),
    );
  }

  void _loadInterstitialChallenge() {
    final unitId = _chooseUnit(rewarded: false, prodUnit: _interstitialChallengeUnit);
    InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Interstitial (Challenge) loaded');
          _interstitialChallenge = ad;
          _interstitialChallenge!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial (Challenge) failed to load: ${err.message}');
          _interstitialChallenge = null;
          Future.delayed(const Duration(seconds: 10), _loadInterstitialChallenge);
        },
      ),
    );
  }

  Future<int> _getInt(String key) async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.getInt(key) ?? 0;
  }

  Future<void> _setInt(String key, int v) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(key, v);
  }

  /// Call at the end of a race (whenever you want to count this race for the interstitial rule)
  Future<void> incrementRaceAndMaybeShow() async {
    int count = await _getInt(_kRaceCounterKey);
    count += 1;
    if (count >= _raceThreshold) {
      final shown = await _tryShowInterstitial(_interstitialRace);
      if (shown) {
        await _setInt(_kRaceCounterKey, 0);
        _loadInterstitialRace();
      } else {
        // keep the counter to try again later
        await _setInt(_kRaceCounterKey, count);
        _loadInterstitialRace();
      }
    } else {
      await _setInt(_kRaceCounterKey, count);
    }
  }

  /// Call at the end of a challenge (training/home "challenge" flow)
  Future<void> incrementChallengeAndMaybeShow() async {
    int count = await _getInt(_kChallengeCounterKey);
    count += 1;
    if (count >= _challengeThreshold) {
      final shown = await _tryShowInterstitial(_interstitialChallenge);
      if (shown) {
        await _setInt(_kChallengeCounterKey, 0);
        _loadInterstitialChallenge();
      } else {
        await _setInt(_kChallengeCounterKey, count);
        _loadInterstitialChallenge();
      }
    } else {
      await _setInt(_kChallengeCounterKey, count);
    }
  }

  Future<bool> _tryShowInterstitial(InterstitialAd? ad) async {
    if (ad == null) {
      debugPrint('Interstitial not ready');
      return false;
    }
    final completer = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('Interstitial shown'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Interstitial dismissed');
        completer.complete(true);
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('Interstitial failed to show: ${err.message}');
        completer.complete(false);
        ad.dispose();
      },
    );
    ad.show();
    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
      debugPrint('Interstitial show timeout');
      try { ad.dispose(); } catch (_) {}
      return false;
    });
  }

  // ---------------------------
  // REWARDED ADS
  // ---------------------------
  void _loadAllRewardeds() {
    _loadRewardedHomeLife();
    _loadRewardedHomePass();
    _loadRewardedTrainingTrials();
  }

  void _loadRewardedHomeLife() {
    final unitId = _chooseUnit(rewarded: true, prodUnit: _rewardedHomeLifeUnit);
    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Rewarded (Home Life) loaded');
          _rewardedHomeLife = ad;
        },
        onAdFailedToLoad: (err) {
          debugPrint('Rewarded (Home Life) failed to load: ${err.message}');
          _rewardedHomeLife = null;
          Future.delayed(const Duration(seconds: 10), _loadRewardedHomeLife);
        },
      ),
    );
  }

  void _loadRewardedHomePass() {
    final unitId = _chooseUnit(rewarded: true, prodUnit: _rewardedHomePassUnit);
    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Rewarded (Home Pass) loaded');
          _rewardedHomePass = ad;
        },
        onAdFailedToLoad: (err) {
          debugPrint('Rewarded (Home Pass) failed to load: ${err.message}');
          _rewardedHomePass = null;
          Future.delayed(const Duration(seconds: 10), _loadRewardedHomePass);
        },
      ),
    );
  }

  void _loadRewardedTrainingTrials() {
    final unitId = _chooseUnit(rewarded: true, prodUnit: _rewardedTrainingTrialsUnit);
    debugPrint('AdService: loading Rewarded (Training Trials) unit=$unitId (testMode=$useTestAds)');
    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdService: Rewarded (Training Trials) loaded');
          _rewardedTrainingTrials = ad;
          // Ensure onAdFailedToShow / dismissed handlers are set before show
          // (we will set fullScreenContentCallback when showing)
        },
        onAdFailedToLoad: (err) {
          debugPrint('AdService: Rewarded (Training Trials) failed to load - code=${err.code} message=${err.message}');
          _rewardedTrainingTrials = null;
          // retry after short delay
          Future.delayed(const Duration(seconds: 8), _loadRewardedTrainingTrials);
        },
      ),
    );
  }

  Future<bool> _tryShowRewarded(RewardedAd? ad, {required Function(RewardItem) onEarned}) async {
    if (ad == null) {
      debugPrint('Rewarded ad not ready');
      return false;
    }

    final completer = Completer<bool>();
    bool _earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('Rewarded shown'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Rewarded dismissed');
        // If the reward was earned, report success; otherwise false.
        if (!completer.isCompleted) completer.complete(_earned);
        try { ad.dispose(); } catch (_) {}
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('Rewarded failed to show: ${err.message}');
        if (!completer.isCompleted) completer.complete(false);
        try { ad.dispose(); } catch (_) {}
      },
    );

    try {
      // onUserEarnedReward signature can differ between versions; handle common signature:
      final dynamic _onUserEarnedReward = (dynamic a, [dynamic b]) {
        RewardItem? reward;
        if (a is RewardItem) {
          reward = a;
        } else if (b is RewardItem) {
          reward = b;
        }

        if (reward == null) {
          debugPrint('User earned reward called but no RewardItem found (a=${a.runtimeType}, b=${b.runtimeType})');
          // don't mark as earned if we can't interpret reward
          if (!completer.isCompleted) completer.complete(false);
          return;
        }

        debugPrint('User earned reward: ${reward.amount} ${reward.type}');
        _earned = true;
        try {
          onEarned(reward);
        } catch (e) {
          debugPrint('onEarned callback failed: $e');
        }
        if (!completer.isCompleted) completer.complete(true);
      };

      // call show with dynamic wrapper to support either API signature
      ad.show(onUserEarnedReward: _onUserEarnedReward);
    } catch (e) {
      debugPrint('Exception while calling show(): $e');
      if (!completer.isCompleted) completer.complete(false);
      try { ad.dispose(); } catch (_) {}
    }

    // Nullify the in-memory ad reference at the caller side (caller already does in many places).
    // Wait for the result (with a reasonable timeout).
    bool result = false;
    try {
      result = await completer.future.timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('Rewarded show timeout or error: $e');
      result = false;
    }

    debugPrint('Rewarded show result = $result (earned=$_earned)');
    return result;
  }

  Future<bool> showRewardedHomeLife({required Function onEarnedLife}) async {
    final ad = _rewardedHomeLife;
    debugPrint('AdService: showRewardedHomeLife called, ad ready=${ad != null}');
    final shown = await _tryShowRewarded(ad, onEarned: (reward) {
      try {
        onEarnedLife();
      } catch (e) {
        debugPrint('Error in onEarnedLife callback: $e');
      }
    });
    _loadRewardedHomeLife();
    debugPrint('AdService: showRewardedHomeLife returned $shown');
    return shown;
  }

  /// Show rewarded for home pass (skip/question pass).
  Future<bool> showRewardedHomePass({required Function onPassed}) async {
    final ad = _rewardedHomePass;
    final shown = await _tryShowRewarded(ad, onEarned: (reward) {
      onPassed();
    });
    _loadRewardedHomePass();
    return shown;
  }

  bool get isRewardedTrainingReady => _rewardedTrainingTrials != null;
  Future<void> ensureRewardedTrainingLoaded() async {
    if (_rewardedTrainingTrials == null) _loadRewardedTrainingTrials();
  }

  /// Show rewarded for training trials (+5 trials).
  /// onGrantedTrials is called when the user actually earns the reward.
  Future<bool> showRewardedTrainingTrials({required Function(RewardItem) onGrantedTrials}) async {
    // Make sure there's an ad loaded
    if (_rewardedTrainingTrials == null) {
      debugPrint('AdService: showRewardedTrainingTrials -> no ad loaded');
      return false;
    }

    final completer = Completer<bool>();
    final RewardedAd ad = _rewardedTrainingTrials!;

    // When the ad is dismissed or fails to show, complete(false) if not already completed.
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('AdService: Rewarded shown'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AdService: Rewarded dismissed');
        if (!completer.isCompleted) completer.complete(false);
        try { ad.dispose(); } catch (_) {}
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('AdService: Rewarded failed to show: ${err.message}');
        if (!completer.isCompleted) completer.complete(false);
        try { ad.dispose(); } catch (_) {}
      },
    );

    // Show the ad and wait for onUserEarnedReward to fire.
    // Use a dynamic wrapper to support either (RewardItem) or (RewardedAd, RewardItem) signatures.
    try {
      // dynamic wrapper so we work across google_mobile_ads versions
      final dynamic _onUserEarnedReward = (dynamic a, [dynamic b]) {
        RewardItem? reward;
        // case A: (RewardItem)
        if (a is RewardItem) {
          reward = a;
        }
        // case B: (RewardedAd, RewardItem)
        else if (b is RewardItem) {
          reward = b;
        }

        if (reward == null) {
          debugPrint('AdService: onUserEarnedReward called but no RewardItem found (a=${a.runtimeType}, b=${b.runtimeType})');
          // still try to complete if needed
          if (!completer.isCompleted) completer.complete(false);
          return;
        }

        debugPrint('AdService: User earned reward: ${reward.amount} ${reward.type}');
        try {
          onGrantedTrials(reward);
        } catch (e) {
          debugPrint('AdService: onGrantedTrials callback error: $e');
        }
        if (!completer.isCompleted) completer.complete(true);
      };

      // Pass the dynamic wrapper to show(). Cast to dynamic so analyzer doesn't check typedef.
      ad.show(onUserEarnedReward: _onUserEarnedReward);
    } catch (e) {
      debugPrint('AdService: Exception while calling show(): $e');
      if (!completer.isCompleted) completer.complete(false);
      try { ad.dispose(); } catch (_) {}
    }

    // Nullify the field so a subsequent call triggers reload
    _rewardedTrainingTrials = null;

    // start reload for next time
    Future.delayed(const Duration(milliseconds: 300), _loadRewardedTrainingTrials);

    // Wait for reward (with a reasonable timeout)
    bool result = false;
    try {
      result = await completer.future.timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('AdService: showRewardedTrainingTrials timeout or error: $e');
      result = false;
    }

    debugPrint('AdService: showRewardedTrainingTrials result=$result');
    return result;
  }

  /// Dispose all ads
  void disposeAll() {
    try {
      _interstitialRace?.dispose();
      _interstitialChallenge?.dispose();
      _rewardedHomeLife?.dispose();
      _rewardedHomePass?.dispose();
      _rewardedTrainingTrials?.dispose();
    } catch (_) {}
  }
}
