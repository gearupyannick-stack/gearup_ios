import 'package:flutter/foundation.dart';               // Nécessaire pour VoidCallback
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static final AdManager instance = AdManager._internal();

  // → IDs de vos placements (interstitiel & rewarded)  
  static const String _interstitialAdUnitId = 'ca-app-pub-3327975632345057/7615269398';
  static const String _rewardedAdUnitId    = 'ca-app-pub-3327975632345057/2190825974';

  InterstitialAd? _interstitialAd;
  RewardedAd?     _rewardedAd;
  int _trainingCounter = 0;
  int _homeCounter     = 0;

  AdManager._internal();

  /// Initialise le SDK et charge à la fois interstitiel et rewarded.
  Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadInterstitial();
    _loadRewardedAd();
  }

  /// Charge une pub interstitielle en arrière-plan.
  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Charge une Rewarded Ad en arrière-plan.
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Indique si une Rewarded Ad est prête à être affichée.
  bool get isRewardedAdReady => _rewardedAd != null;

  /// À appeler après chaque challenge de training terminé.
  /// Affiche une pub toutes les 2 sessions.  
  void notifyTrainingCompleted() {
    _trainingCounter++;
    if (_trainingCounter >= 2) {
      _trainingCounter = 0;
      showAdIfAvailable();
    }
  }

  /// À appeler après chaque essai “Home” (flag tap),
  /// qu’il soit réussi ou non.  
  /// Affiche une pub toutes les 4 tentatives.
  void notifyHomeAttempt() {
    _homeCounter++;
    if (_homeCounter >= 4) {
      _homeCounter = 0;
      showAdIfAvailable();
    }
  }

  /// Montre l’interstitielle si prête, puis recharge.
  void showAdIfAvailable() {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitial();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitial();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    }
  }

  /// Affiche la Rewarded Ad et appelle [onEarned] quand la pub a été regardée.
  void showRewardedAd({required VoidCallback onEarned}) {
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadRewardedAd();
        },
      );
      _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        onEarned();
      });
      _rewardedAd = null;
    }
  }
}
