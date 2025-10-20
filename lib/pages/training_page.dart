// training_page.dart
import 'package:flutter/material.dart';

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

import '../services/premium_service.dart';
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

  Future<void> _maybeStartChallenge(String title, Widget page) async {
    final premium = PremiumService.instance;

    // If this title is gated and user is not premium, check the daily limit.
    final bool isGated = _gatedTitles.contains(title);
    if (isGated && !premium.isPremium) {
      // If they reached the daily free limit, show upgrade dialog
      if (!premium.canStartTrainingNow()) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Daily limit reached"),
            content: const Text(
              "Free users can try 5 gated Training challenges per day.\n\n"
              "Upgrade to Premium for unlimited Training and unlimited lives.",
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushNamed('/premium');
                },
                child: const Text("Upgrade"),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Training", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Icon(Icons.fitness_center, size: 18),
                    const SizedBox(width: 6),
                    Text("Gated remaining: $remaining", style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    if (!isPremium)
                      TextButton(onPressed: () => Navigator.of(context).pushNamed('/premium'), child: const Text("Upgrade")),
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
                        Center(child: Text(c.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16))),
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