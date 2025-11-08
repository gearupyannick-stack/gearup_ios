// training_page.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

// Keep existing relative imports to your challenge pages:
import 'challenges/brand_challenge_page.dart';
import 'challenges/models_by_brand_challenge_page.dart';
import 'challenges/model_challenge_page.dart';
import 'challenges/origin_challenge_page.dart';
import 'challenges/engine_type_challenge_page.dart';
import 'challenges/max_speed_challenge_page.dart';
import 'challenges/acceleration_challenge_page.dart';
import 'challenges/power_challenge_page.dart';
import 'challenges/special_feature_challenge_page.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/premium_service.dart';
import '../services/ad_service.dart';
import '../services/audio_feedback.dart'; // keep your audio hook if used

typedef VoidAsync = Future<void> Function();

class TrainingPage extends StatefulWidget {
  final VoidAsync? onLifeWon;
  final VoidCallback? recordChallengeCompletion;
  const TrainingPage({Key? key, this.onLifeWon, this.recordChallengeCompletion}) : super(key: key);

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  // define which challenges are gated (the rest will be free always)
  static const List<String> _gatedTitles = [
    'Origin',
    'Engine Type',
    'Max Speed',
    'Acceleration',
    'Power',
    'Special Feature',
  ];

  // free (always open)
  static final List<_Challenge> _alwaysFree = [
    _Challenge('Brand', BrandChallengePage()),
    _Challenge('Models by Brand', ModelsByBrandChallengePage()),
    _Challenge('Model', ModelChallengePage()),
  ];

  // gated list
  static final List<_Challenge> _gated = [
    _Challenge('Origin', OriginChallengePage()),
    _Challenge('Engine Type', EngineTypeChallengePage()),
    _Challenge('Max Speed', MaxSpeedChallengePage()),
    _Challenge('Acceleration', AccelerationChallengePage()),
    _Challenge('Power', PowerChallengePage()),
    _Challenge('Special Feature', SpecialFeatureChallengePage()),
  ];

  // merged list for display order (you can reorder if desired)
  late final List<_Challenge> _challenges = [
    ..._alwaysFree,
    ..._gated,
  ];

  // Free daily limit for gated challenges

  @override
  void initState() {
    super.initState();
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}

    // Make sure PremiumService is initialized in app start (Main). If not, ensure init is called elsewhere.
  }

  String _translateModuleName(String title) {
    switch (title) {
      case 'Brand': return 'training.moduleBrand'.tr();
      case 'Models by Brand': return 'challenges.modelsByBrand'.tr();
      case 'Model': return 'training.moduleModel'.tr();
      case 'Origin': return 'training.moduleOrigin'.tr();
      case 'Engine Type': return 'training.moduleEngineType'.tr();
      case 'Max Speed': return 'training.moduleMaxSpeed'.tr();
      case 'Acceleration': return 'training.moduleAcceleration'.tr();
      case 'Power': return 'training.modulePower'.tr();
      case 'Special Feature': return 'challenges.specialFeature'.tr();
      default: return title;
    }
  }

  Future<void> _maybeStartChallenge(String title, Widget page) async {
    final premium = PremiumService.instance;

    // If this title is gated and user is not premium, check the daily limit.
    final bool isGated = _gatedTitles.contains(title);
    if (isGated && !premium.isPremium) {
      // If they reached the daily free limit, show dialog with ad option
      if (!premium.canStartTrainingNow()) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('training.dailyLimitReached'.tr()),
            content: Text('training.upgradePremium'.tr()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.close'.tr())),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  // Show rewarded ad
                  try {
                    final shown = await AdService.instance.showRewardedTrainingTrials(
                      onGrantedTrials: (RewardItem reward) {
                        // Grant +5 training attempts
                        // Note: You may want to add actual tracking of ad-granted trials
                        // For now, we'll just show a success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('training.attemptsGranted'.tr())),
                        );
                      },
                    );
                    if (!shown) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('lives.adUnavailable'.tr())),
                      );
                    }
                  } catch (e) {
                    debugPrint('Error showing training trials ad: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('home.errorShowingAd'.tr(namedArgs: {'error': e.toString()}))),
                    );
                  }
                },
                child: Text('lives.watchAd'.tr()),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushNamed('/premium');
                },
                child: Text('premium.purchaseButton'.tr(namedArgs: {'price': ''})),
              ),
            ],
          ),
        );
        return;
      }
      // Record the attempt for gated category only for non-premium users
      await premium.recordTrainingStart();
    }

    // Navigate to challenge
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    // optional callback
    widget.recordChallengeCompletion?.call();

    // increment challenge counter (and show interstitial per your rule every 5)
    try {
      await AdService.instance.incrementChallengeAndMaybeShow();
    } catch (e) {
      debugPrint('AdService.incrementChallengeAndMaybeShow error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = PremiumService.instance;
    final isPremium = premium.isPremium;
    // Show remaining for gated challenges only
    final remaining = isPremium ? '∞' : premium.remainingTrainingAttempts().toString();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + remaining counter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fitness_center, size: 18),
                        const SizedBox(width: 6),
                        Text('training.attemptsRemaining'.tr(namedArgs: {'count': remaining}), style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                    if (!isPremium)
                      TextButton(
                        onPressed: () => Navigator.of(context).pushNamed('/premium'),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                        child: Text('training.goPremium'.tr(), style: const TextStyle(fontSize: 13)),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Buttons grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: 1.2, crossAxisSpacing: 12, mainAxisSpacing: 12,
                ),
                itemCount: _challenges.length,
                itemBuilder: (context, index) {
                  final c = _challenges[index];
                  final bool isGatedItem = _gatedTitles.contains(c.title);
                  return ElevatedButton(
                    onPressed: () => _maybeStartChallenge(c.title, c.page),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Stack(
                      children: [
                        Center(child: Text(_translateModuleName(c.title), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16))),
                        if (isGatedItem)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Icon(Icons.lock, size: 16, color: premium.isPremium ? Colors.amber : Colors.white70),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Challenge {
  final String title;
  final Widget page;
  const _Challenge(this.title, this.page);
}