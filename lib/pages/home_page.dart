import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:csv/csv.dart';
import '../services/audio_feedback.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../services/language_service.dart';

/// Raw track point definitions for tracks 2 & 3.
final Map<int, List<Offset>> _tracks = {
  2: [
    Offset(550, 1), Offset(550, 300), Offset(550, 600), Offset(550, 830),
    Offset(515, 855), Offset(500, 857), Offset(443, 855), Offset(423, 830),
    Offset(420, 778), Offset(420, 702), Offset(410, 637), Offset(405, 437),
    Offset(420, 208), Offset(410, 86), Offset(390, 70), Offset(350, 61),
    Offset(192, 79), Offset(84, 67), Offset(44, 99), Offset(40, 141),
    Offset(73, 175), Offset(105, 172), Offset(135, 155), Offset(155, 158),
    Offset(174, 197), Offset(195, 215), Offset(224, 205), Offset(255, 160),
    Offset(265, 155), Offset(285, 149), Offset(285, 200), Offset(285, 268),
    Offset(262, 300), Offset(235, 283), Offset(97, 240), Offset(65, 249),
    Offset(46, 269), Offset(47, 341), Offset(75, 375), Offset(107, 380),
    Offset(140, 370), Offset(165, 370), Offset(181, 395), Offset(206, 420),
    Offset(225, 415), Offset(265, 365), Offset(278, 350), Offset(297, 356),
    Offset(297, 483), Offset(282, 505), Offset(251, 500), Offset(105, 450),
    Offset(68, 455), Offset(50, 479), Offset(52, 529), Offset(72, 585),
    Offset(116, 585), Offset(146, 568), Offset(165, 565), Offset(178, 579),
    Offset(199, 625), Offset(224, 630), Offset(265, 568), Offset(279, 560),
    Offset(289, 560), Offset(298, 570), Offset(300, 700), Offset(280, 712),
    Offset(256, 709), Offset(120, 665), Offset(79, 665), Offset(60, 700),
    Offset(60, 800), Offset(60, 830), Offset(70, 840), Offset(110, 785),
    Offset(135, 770), Offset(150, 765), Offset(175, 778), Offset(187, 827),
    Offset(220, 827), Offset(240, 810), Offset(300, 805), Offset(324, 805),
    Offset(339, 819), Offset(340, 900), Offset(350, 920), Offset(370, 935),
    Offset(500, 920), Offset(530, 930), Offset(545, 1010)
  ],
  3: [
    Offset(360, 1), Offset(355, 26), Offset(331, 39), Offset(247, 68),
    Offset(246, 94), Offset(267, 107), Offset(352, 83), Offset(374, 98),
    Offset(361, 142), Offset(300, 165), Offset(213, 158), Offset(159, 75),
    Offset(137, 71), Offset(89, 108), Offset(74, 157), Offset(87, 255),
    Offset(103, 275), Offset(143, 283), Offset(159, 265), Offset(134, 181),
    Offset(141, 161), Offset(166, 156), Offset(183, 170), Offset(208, 260),
    Offset(226, 271), Offset(269, 286), Offset(268, 306), Offset(182, 359),
    Offset(178, 382), Offset(216, 430), Offset(262, 447), Offset(370, 431),
    Offset(391, 402), Offset(383, 365), Offset(283, 386), Offset(264, 366),
    Offset(274, 340), Offset(370, 312), Offset(399, 267), Offset(444, 239),
    Offset(468, 251), Offset(516, 354), Offset(514, 402), Offset(458, 440),
    Offset(442, 482), Offset(534, 491), Offset(530, 510), Offset(490, 550),
    Offset(387, 580), Offset(383, 613), Offset(410, 631), Offset(551, 595),
    Offset(569, 621), Offset(534, 668), Offset(405, 694), Offset(330, 654),
    Offset(319, 537), Offset(254, 483), Offset(227, 491), Offset(166, 586),
    Offset(136, 573), Offset(125, 480), Offset(87, 502), Offset(64, 544),
    Offset(90, 800), Offset(119, 835), Offset(159, 833), Offset(157, 813),
    Offset(144, 719), Offset(168, 701), Offset(194, 715), Offset(218, 809),
    Offset(253, 819), Offset(311, 831), Offset(353, 877), Offset(361, 899),
    Offset(360, 901), Offset(355, 926), Offset(331, 939), Offset(247, 968),
    Offset(246, 994), Offset(267, 1007), Offset(352, 983), Offset(374, 998),
    Offset(361, 1042), Offset(300, 1065)
  ],
};

/// Difficulty mappings for quizzes.
final List<int> _easyQuestions   = [1, 2, 3, 6];
final List<int> _mediumQuestions = [4, 5, 11, 12];
final List<int> _hardQuestions   = [7, 8, 9, 10];

// Simple fallback helper to return an AssetImage for our assets/model/ images.
// If the passed name is already a full assets/... path we keep it as-is.
ImageProvider _assetImageProvider(String name) {
  final assetPath = name.startsWith('assets/') ? name : 'assets/model/$name';
  return AssetImage(assetPath);
}

class HomePage extends StatefulWidget {
  final GlobalKey? firstFlagKey;
  final int currentLives;
  final int Function() getLives;
  final dynamic livesStorage;
  final VoidCallback onChallengeFail;
  final ValueChanged<int> onGearUpdate;
  final VoidCallback? recordChallengeCompletion;
  final GlobalKey? levelProgressKey;

  const HomePage({
    Key? key,
    required this.currentLives,
    required this.getLives,
    required this.livesStorage,
    required this.onChallengeFail,
    required this.onGearUpdate,
    this.recordChallengeCompletion,
    this.firstFlagKey,
    this.levelProgressKey,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

// --- Audio + streak mixin used by many question State classes ---
mixin AudioAnswerMixin<T extends StatefulWidget> on State<T> {
  // streak local to each State instance
  int _streak = 0;

  void _audioPlayTap() {
    try { AudioFeedback.instance.playEvent(SoundEvent.tap); } catch (_) {}
  }

  void _audioPlayAnswerCorrect() {
    try { AudioFeedback.instance.playEvent(SoundEvent.answerCorrect); } catch (_) {}
  }

  void _audioPlayAnswerWrong() {
    try { AudioFeedback.instance.playEvent(SoundEvent.answerWrong); } catch (_) {}
  }

  void _audioPlayStreak({int? milestone}) {
    try {
      if (milestone != null) {
        AudioFeedback.instance.playEvent(SoundEvent.streak, meta: {'milestone': milestone});
      } else {
        AudioFeedback.instance.playEvent(SoundEvent.streak);
      }
    } catch (_) {}
  }

  void _audioPlayPageFlip() {
    try { AudioFeedback.instance.playEvent(SoundEvent.pageFlip); } catch (_) {}
  }

}
class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin, AudioAnswerMixin {
  bool _didInitDependencies = false;
  int _consecutiveFails = 0;
  bool _isShowingAdAction = false;

  // ─── Stats helpers ──────────────────────────────────────────────────────────
  Future<void> _incrementChallengesAttempted() async {
    final prefs = await SharedPreferences.getInstance();
    int curr = prefs.getInt('challengesAttemptedCount') ?? 0;
    await prefs.setInt('challengesAttemptedCount', curr + 1);
  }

  Future<void> _incrementQuestionAttemptCount() async {
    final prefs = await SharedPreferences.getInstance();
    int curr = prefs.getInt('questionAttemptCount') ?? 0;
    await prefs.setInt('questionAttemptCount', curr + 1);
  }

  Future<void> _incrementCorrectAnswerCount() async {
    final prefs = await SharedPreferences.getInstance();
    int curr = prefs.getInt('correctAnswerCount') ?? 0;
    await prefs.setInt('correctAnswerCount', curr + 1);
  }
  // ────────────────────────────────────────────────────────────────────────────

  /// Watch ad to pass a question
  Future<void> _onWatchAdToPass(Future<void> Function() onPassAction) async {
    if (_isShowingAdAction) return;
    setState(() => _isShowingAdAction = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('lives.loadingAd'.tr())));

    try {
      final shown = await AdService.instance.showRewardedHomePass(
        onPassed: () async {
          // This callback runs when the ad grant is received.
          try {
            await onPassAction();
          } catch (e) {
            debugPrint('onPassAction failed: $e');
          }
        },
      );

      messenger.clearSnackBars();

      if (shown) {
        messenger.showSnackBar(SnackBar(content: Text('home.passedGoodLuck'.tr())));
      } else {
        messenger.showSnackBar(SnackBar(content: Text('lives.adUnavailable'.tr())));
      }
    } catch (e) {
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text('home.errorShowingAd'.tr(namedArgs: {'error': e.toString()}))));
      debugPrint('Error in _onWatchAdToPass: $e');
    } finally {
      if (mounted) setState(() => _isShowingAdAction = false);
    }
  }

  // Fractional track1 flags (extended for more points).
  static const List<Offset> _flagFractionsTrack1 = [
    Offset(0.0977, 0.0000),
    Offset(0.1025, 0.0208),
    Offset(0.1270, 0.0500),
    Offset(0.1465, 0.0550),
    Offset(0.1768, 0.0550),
    Offset(0.2070, 0.0658),
    Offset(0.2100, 0.0964),
    Offset(0.1807, 0.1230),
    Offset(0.1094, 0.1257),
    Offset(0.0977, 0.1426),
    Offset(0.0977, 0.1764),
    Offset(0.1270, 0.2012),
    Offset(0.1953, 0.2077),
    Offset(0.3252, 0.2057),
    Offset(0.3594, 0.1882),
    Offset(0.3682, 0.1536),
    Offset(0.3984, 0.1427),
    Offset(0.5000, 0.1471),
    Offset(0.5273, 0.1706),
    Offset(0.5176, 0.1955),
    Offset(0.4883, 0.2083),
    Offset(0.4434, 0.2299),
    Offset(0.4316, 0.2411),
    Offset(0.4229, 0.2753),
    Offset(0.3926, 0.2936),
    Offset(0.2705, 0.3030),
    Offset(0.2480, 0.3193),
    Offset(0.2266, 0.3503),
    Offset(0.1826, 0.3587),
    Offset(0.0820, 0.3685),
    Offset(0.0508, 0.3997),
    Offset(0.0781, 0.4264),
    Offset(0.1123, 0.4427),
    Offset(0.2305, 0.4427),
    Offset(0.2627, 0.4372),
    Offset(0.2793, 0.4049),
    Offset(0.3125, 0.3789),
    Offset(0.4209, 0.3893),
    Offset(0.4551, 0.4121),
    Offset(0.4297, 0.4495),
    Offset(0.4102, 0.4557),
    Offset(0.3516, 0.4701),
    Offset(0.3418, 0.5013),
    Offset(0.3223, 0.5143),
    Offset(0.2637, 0.5176),
    Offset(0.1270, 0.5208),
    Offset(0.0977, 0.5534),
    Offset(0.0977, 0.5892),
    Offset(0.1074, 0.6100),
    Offset(0.1465, 0.6250),
    Offset(0.1758, 0.6322),
    Offset(0.1953, 0.6374),
    Offset(0.2070, 0.6549),
    Offset(0.2100, 0.6849),
    Offset(0.1807, 0.7122),
  ];

  /// Same indexing as `_tracks`, but stored as values between 0.0–1.0
  final Map<int, List<Offset>> _fractionalTracks = {
    for (var entry in _tracks.entries)
      entry.key: entry.value
        .map((pt) => Offset(pt.dx / _originalTrackWidth, pt.dy / _originalTrackHeight))
        .toList(),
  };

  // Original track dimensions (used as the “1.0×1.0” baseline):
  static const double _originalTrackWidth  = 1024;
  static const double _originalTrackHeight = 1536;

  List<Offset> get _currentPathPoints {
    final media     = MediaQuery.of(context);
    final paddingTop    = media.padding.top;
    final paddingBottom = media.padding.bottom;
    final availW    = media.size.width;
    final availH    = media.size.height - paddingTop - paddingBottom;

    // Uniform scale factor to fit the 1024×1536 image
    final scale = math.min(availW / _originalTrackWidth, availH / _originalTrackHeight);

    // Letterbox offsets to center the image
    final dx = (availW - _originalTrackWidth * scale) / 2;
    final dy = 0.05 * _originalTrackHeight;

    if (_currentTrack == 1) {
      // track1 already fractional, same approach
      return _flagFractionsTrack1.map((f) {
        return Offset(
          f.dx * _originalTrackWidth  * scale + dx,
          f.dy * _originalTrackHeight * scale + dy,
        );
      }).toList();
    } else {
      final raw = _tracks[_currentTrack]!; // list of raw Offsets in 1024×1536
      return raw.map((off) {
        return Offset(
          off.dx * scale + dx,
          off.dy * scale + dy,
        );
      }).toList();
    }
  }

  // ─── Animation & car state ──────────────────────────────────────────────────
  late AnimationController _controller;
  late Animation<Offset> _animation;
  int _currentIndex = 0;
  late Offset _previousOffset;
  double _carAngle = 0.0;

  final ScrollController _scrollController = ScrollController();
  int _sessionsCompleted = 0;
  // ignore: unused_field
  bool _awaitingFlagTap = false;
  bool _retryButtonActive = false;
  // ignore: unused_field
  bool _showRetryButton = false;
  late Set<int> _flagIndices;
  final Map<int, String> _flagStatus     = {};
  final Map<int, String> _challengeColors = {};
  final Map<int, int>    _previousScores  = {};
  List<Map<String, String>> carData = [];
  int _gearCount            = 0;
  int _gearCountBeforeLevel = 0;
  bool _isCorrectionRun               = false;
  // ignore: unused_field
  bool _gateOpen                      = false;
  int _currentTrack = 1; // 1, 2, or 3.
  // petit tracker de séries (comme dans acceleration)
  int _streak = 0;

  /// Number of questions this level uses.
  int getQuizQuestionCount() {
    int level = _sessionsCompleted + 1;
    int cnt = level + 2;
    if ((_currentTrack == 2 || _currentTrack == 3) && cnt > 10) return 10;
    return cnt;
  }

  /// Gear requirement for this level.
  int getGearRequirement() {
    int level = _sessionsCompleted + 1;
    if (_currentTrack == 3 && level >= 20) return 220;
    return (level + 2) * 10;
  }

  int _requiredGearsForCurrentLevel() => getGearRequirement();

  int _calculateGearCountBeforeLevel(int lvl) {
    int total = 0;
    for (int i = 1; i <= lvl; i++) {
      total += (_currentTrack == 3 && i >= 20) ? 220 : (30 + (i - 1) * 10);
    }
    return total;
  }

  List<int> get _flagIndicesSorted {
    final int lvl = _sessionsCompleted + 1;

    if (_currentTrack == 1) {
      // Track 1 always has exactly these 10 flags
      return [4, 9, 14, 19, 24, 26, 29, 34, 39, 44];
    }

    else if (_currentTrack == 2) {
      // Base flags for Track 2
      const base2 = [1, 7, 11, 16, 31, 37, 50, 60, 73, 87];
      if (lvl <= 8) {
        return base2;
      } else {
        // Extra flags you start unlocking at level 9+
        const extras2 = [2, 3, 13, 20, 26, 40, 53, 56, 66, 71, 78, 82];
        final count2 = (lvl - 8).clamp(0, extras2.length);
        return [
          ...base2,
          ...extras2.take(count2),
        ];
      }
    }

    else { // Track 3
      // Base flags for Track 3
      const base3 = [3, 12, 18, 27, 35, 45, 55, 63, 70, 74];
      if (lvl <= 8) {
        return base3;
      } else {
        // Extra flags you start unlocking at level 9+
        const extras3 = [6, 9, 15, 21, 30, 37, 40, 50, 52, 60, 64, 72];
        final count3 = (lvl - 8).clamp(0, extras3.length);
        return [
          ...base3,
          ...extras3.take(count3),
        ];
      }
    }
  }

  int _maxLevelsForTrack() {
    if (_currentTrack == 1) return 10;
    if (_currentTrack == 2) return 20;
    return 30;
  }

  int get _finalFlagIndex {
    if (_currentTrack == 1) {
      // base flags for track 1
      const base1 = [4, 9, 14, 19, 24, 26, 29, 34, 39, 44];
      return base1.last;
    } else if (_currentTrack == 2) {
      // base flags for track 2
      const base2 = [1, 7, 11, 16, 31, 37, 50, 60, 73, 87];
      return base2.last;  // always 87
    } else {
      // base flags for track 3
      const base3 = [3, 12, 18, 27, 35, 45, 55, 63, 70, 74];
      return base3.last;
    }
  }

  @override
  void initState() {
    super.initState();
    // play page open sound
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.addListener(() {
      setState(() {
        final currentOffset = _animation.value;
        final dx = currentOffset.dx - _previousOffset.dx;
        final dy = currentOffset.dy - _previousOffset.dy;
        if (dx.abs() > 0.0001 || dy.abs() > 0.0001) {
          _carAngle = math.atan2(dy, dx);
        }
        _previousOffset = currentOffset;
      });
    });
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentIndex++;
        if (_currentIndex < _currentPathPoints.length) {
          if (_flagIndices.contains(_currentIndex)) {
            final challengeNumber = _challengeNumberForFlag(_currentIndex);
            final prevColor = _challengeColors[challengeNumber];
            if (_currentIndex != _finalFlagIndex) {
              if (!_isCorrectionRun) {
                if (prevColor == 'yellow' || prevColor == 'orange' || prevColor == 'green') {
                  _animateToNextPoint();
                } else {
                  _awaitingFlagTap = true;
                  setState(() {});
                }
              } else {
                if (prevColor == 'green') {
                  _animateToNextPoint();
                } else {
                  _awaitingFlagTap = true;
                  setState(() {});
                }
              }
            } else {
              _awaitingFlagTap = true;
              setState(() {});
            }
          } else {
            if (_currentIndex < _currentPathPoints.length - 1) {
              _animateToNextPoint();
            } else {
              if (_sessionsCompleted < _maxLevelsForTrack()) {
                _scrollByOneTrackImage();
              }
            }
          }
        } else {
          if (_sessionsCompleted < _maxLevelsForTrack()) {
            _scrollByOneTrackImage();
          }
        }
      }
    });

    _loadGearCount().then((_) {
      _loadProgressFromStorage().then((_) async {
        await _loadConsecutiveFails();
        // ici vos setState/init animation habituels
        _previousOffset = _currentPathPoints.first;
        _animation = AlwaysStoppedAnimation<Offset>(_previousOffset);
        if (_currentPathPoints.length > 1) {
          _animateToNextPoint();
        }
      });
    });

    _loadCarData();
    _flagIndices = Set<int>.from(_flagIndicesSorted);
    for (int idx in _flagIndices) {
      _flagStatus[idx] = 'red';
    }
  }

  Future<void> _saveGearCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gearCount', _gearCount);
    await prefs.setInt('currentLevel', _sessionsCompleted);
    await prefs.setInt('gearCountBeforeLevel', _gearCountBeforeLevel);
  }

  /// Track gear updates in Analytics
  void _trackGearUpdate(int previousGearCount, int newGearCount, {String? source}) {
    final gearsEarned = newGearCount - previousGearCount;
    if (gearsEarned <= 0) return;

    // Track gears earned event
    AnalyticsService.instance.logEvent(
      name: 'gears_earned',
      parameters: {
        'gears_earned': gearsEarned,
        'total_gears': newGearCount,
        'source': source ?? 'challenge',
        'track': _currentTrack,
        'level': _sessionsCompleted + 1,
      },
    );

    // Check for gear milestones
    const milestones = [100, 500, 1000, 5000, 10000];
    for (final milestone in milestones) {
      if (previousGearCount < milestone && newGearCount >= milestone) {
        AnalyticsService.instance.logGearMilestone(
          milestone: milestone,
          currentGears: newGearCount,
        );
        debugPrint('🎉 Gear milestone reached: $milestone');
      }
    }
  }

  Future<void> _loadGearCount() async {
    final prefs = await SharedPreferences.getInstance();
    _gearCount = prefs.getInt('gearCount') ?? 0;
    if (_gearCount < 750) {
      _currentTrack = 1;
      _gearCountBeforeLevel = 0;
    } else if (_gearCount < 3250) {
      _currentTrack = 2;
      _gearCountBeforeLevel = 750;
    } else {
      _currentTrack = 3;
      _gearCountBeforeLevel = 3250;
    }
    int extraGears = _gearCount - _gearCountBeforeLevel;
    int maxLevelsInTrack = _maxLevelsForTrack();
    int currentTrackLevel = 0;
    for (int lvl = 1; lvl <= maxLevelsInTrack; lvl++) {
      int requiredForLevel = (_currentTrack == 3 && lvl >= 20) ? 220 : (30 + (lvl - 1) * 10);
      if (extraGears >= requiredForLevel) {
        extraGears -= requiredForLevel;
        currentTrackLevel = lvl;
      } else {
        break;
      }
    }
    _sessionsCompleted = currentTrackLevel;
    _gearCountBeforeLevel += _calculateGearCountBeforeLevel(currentTrackLevel);
    widget.onGearUpdate(_gearCount);
    setState(() {
      _flagIndices = Set<int>.from(_flagIndicesSorted);
    });
  }

  // Audio helper wrappers — place-les dans _HomePageState
  void _audioPlayTap() {
    try { AudioFeedback.instance.playEvent(SoundEvent.tap); } catch (_) {}
  }

  void _audioPlayAnswerCorrect() {
    try { AudioFeedback.instance.playEvent(SoundEvent.answerCorrect); } catch (_) {}
  }

  void _audioPlayAnswerWrong() {
    try { AudioFeedback.instance.playEvent(SoundEvent.answerWrong); } catch (_) {}
  }

  void _audioPlayStreak({int? milestone}) {
    try {
      if (milestone != null) {
        AudioFeedback.instance.playEvent(SoundEvent.streak, meta: {'milestone': milestone});
      } else {
        AudioFeedback.instance.playEvent(SoundEvent.streak);
      }
    } catch (_) {}
  }

  void _audioPlayPageFlip() {
    try { AudioFeedback.instance.playEvent(SoundEvent.pageFlip); } catch (_) {}
  }


  Future<void> _showStuckPopup({required Future<void> Function() onPassAction}) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.amber.shade400, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Need a Little Help?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.3), width: 2),
              ),
              child: Column(
                children: [
                  Icon(Icons.emoji_objects, color: Colors.amber.shade300, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'This one\'s tricky! 🤔',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade200,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No worries - everyone learns at their own pace!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Choose an option:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 12),
            // Watch ad for hint button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.video_library, size: 22),
                label: const Text('Watch Video for Hint'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _onWatchAdToPass(onPassAction);
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                label: const Text(
                  'Keep Trying',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.grey[850],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFE53935), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[900]!.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.school, color: Colors.grey[300], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: Look closely at the car\'s unique features!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[300],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        actionsPadding: const EdgeInsets.only(bottom: 8, right: 8),
      ),
    );
  }

  Future<void> _loadCarData() async {
    try {
      final rawCsv = await rootBundle.loadString('assets/cars.csv');
      final List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(rawCsv);
      final descIndex = LanguageService.getDescriptionIndex(context);
      final featureIndex = LanguageService.getSpecialFeatureIndex(context);

      carData = rows.map<Map<String, String>>((values) {
        if (values.length > descIndex && values.length > featureIndex) {
          return {
            'brand': values[0].toString(),
            'model': values[1].toString(),
            'description': values[descIndex].toString(),
            'engineType': values[3].toString(),
            'topSpeed': values[4].toString(),
            'acceleration': values[5].toString(),
            'horsepower': values[6].toString(),
            'priceRange': values[7].toString(),
            'year': values[8].toString(),
            'origin': values[9].toString(),
            'specialFeature': values[featureIndex].toString(),
          };
        }
        return {};
      }).toList();
    } catch (e) {
      print("Error loading CSV: $e");
    }
  }

  Future<void> _loadProgressFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final colorMapJson = prefs.getString('challengeColors');
    final scoresMapJson = prefs.getString('previousScores');
    if (colorMapJson != null && colorMapJson.isNotEmpty) {
      final Map<String, dynamic> tempMap = jsonDecode(colorMapJson);
      _challengeColors.clear();
      tempMap.forEach((key, value) {
        final cNum = int.tryParse(key);
        if (cNum != null) {
          _challengeColors[cNum] = value;
        }
      });
    }
    if (scoresMapJson != null && scoresMapJson.isNotEmpty) {
      final Map<String, dynamic> tempScoresMap = jsonDecode(scoresMapJson);
      _previousScores.clear();
      tempScoresMap.forEach((key, value) {
        final flagIndex = int.tryParse(key);
        if (flagIndex != null) {
          _previousScores[flagIndex] = value;
        }
      });
    }
    if ((_gearCount - _gearCountBeforeLevel) == 0) {
      _resetFlagsForNewLevel();
      _currentIndex = _flagIndicesSorted.first - 1;
      _previousOffset = _currentPathPoints[_currentIndex];
      _controller.reset();
      _animateToNextPoint();
    } else {
      for (final entry in _challengeColors.entries) {
        final cNum = entry.key;
        final color = entry.value;
        final idxInList = cNum - 1;
        if (idxInList >= 0 && idxInList < _flagIndicesSorted.length) {
          final flagIndex = _flagIndicesSorted[idxInList];
          _flagStatus[flagIndex] = color;
        }
      }
    }
    if (_currentIndex == _finalFlagIndex && _challengeColors[_challengeNumberForFlag(_currentIndex)] != 'green') {
      _showRetryButton = true;
    }
    setState(() {});
  }

  Future<void> _saveProgressToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, String> colorMapToSave = {};
    _challengeColors.forEach((cNum, clr) {
      colorMapToSave[cNum.toString()] = clr;
    });
    final colorMapJson = jsonEncode(colorMapToSave);
    await prefs.setString('challengeColors', colorMapJson);
    final Map<String, int> scoresMapToSave = {};
    _previousScores.forEach((flagIndex, score) {
      scoresMapToSave[flagIndex.toString()] = score;
    });
    final scoresMapJson = jsonEncode(scoresMapToSave);
    await prefs.setString('previousScores', scoresMapJson);
  }

  void _resetFlagsForNewLevel() {
    _challengeColors.clear();
    _previousScores.clear();
    for (int idx in _flagIndices) {
      _flagStatus[idx] = 'red';
    }
  }

  void _correctMistakes() {
    setState(() {
      _isCorrectionRun = true;
      _currentIndex = 0;
      _previousOffset = _currentPathPoints.first;
      _controller.reset();
      _retryButtonActive = false;
    });
    _animateToNextPoint();
  }

  void _scrollByOneTrackImage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Make sure the controller’s attached
      if (!_scrollController.hasClients) return;

      // Ask the scrollable how tall its viewport really is
      final pageHeight = _scrollController.position.viewportDimension;

      // Scroll to exactly N×one-page down
      final targetOffset = pageHeight * _sessionsCompleted;

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  void _animateToNextPoint() {
    // 1) Grab the fractional lists for this track:
    final fracList = _currentTrack == 1
        ? _flagFractionsTrack1
        : _fractionalTracks[_currentTrack]!;

    // 2) Fractional start & end
    final startFrac = fracList[_currentIndex];
    final endFrac   = fracList[_currentIndex + 1];

    // 3) Animate tween between those fractions
    _animation = Tween<Offset>(
      begin: startFrac,
      end:   endFrac,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    // 4) Duration based on “distance” in fractional space
    final distFrac = (endFrac - startFrac).distance;
    _controller.duration = Duration(milliseconds: (distFrac * 3000).round());
    _controller.reset();
    _controller.forward();
  }

  int _challengeNumberForFlag(int flagIndex) {
    final idx = _flagIndicesSorted.indexOf(flagIndex);
    return idx + 1;
  }

  void showAchievementSnackBar(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('home.achievementUnlocked'.tr(namedArgs: {'title': title})),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }

  Future<void> unlockAchievement(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = prefs.getStringList('unlockedAchievements') ?? [];

    if (!unlocked.contains(id)) {
      unlocked.add(id);
      await prefs.setStringList('unlockedAchievements', unlocked);

      // show the popup
      showAchievementSnackBar(_getAchievementTitle(id));
    }
  }

  String _getAchievementTitle(String id) {
    switch (id) {
      case 'first_flag':
        return 'home.achievements.firstFlag'.tr();
      case 'level_complete':
        return 'home.achievements.levelComplete'.tr();
      case 'mid-track_milestone':
        return 'home.achievements.midTrackMilestone'.tr();
      case 'track_unlocker_i':
        return 'home.achievements.trackUnlockerI'.tr();
      case 'track_unlocker_ii':
        return 'home.achievements.trackUnlockerII'.tr();
      case 'clean_slate':
        return 'home.achievements.cleanSlate'.tr();
      case 'zero-life_loss':
        return 'home.achievements.zeroLifeLoss'.tr();
      case 'swift_racer':
        return 'home.achievements.swiftRacer'.tr();
      case 'gear_rookie':
        return 'home.achievements.gearRookie'.tr();
      case 'gear_grinder':
        return 'home.achievements.gearGrinder'.tr();
      case 'gear_tycoon':
        return 'home.achievements.gearTycoon'.tr();
      case 'second_chance':
        return 'home.achievements.secondChance'.tr();
      case 'perseverance':
        return 'home.achievements.perseverance'.tr();
      case 'track_conqueror':
        return 'home.achievements.trackConqueror'.tr();
      default:
        return id;
    }
  }

  void _onFlagTap(int flagIndex) async {
    // Compte cette tentative Home (success ou échec)

    // ignore: unused_local_variable
    bool lostLife = false;

    await _incrementChallengesAttempted();
    int currentLives = widget.getLives();
    if (currentLives <= 0) return;

    if (_currentIndex == flagIndex && !_retryButtonActive) {
      final challengeNumber = _challengeNumberForFlag(flagIndex);
      int totalQuestions = getQuizQuestionCount();
      int quizScore = 0;

      final prefs = await SharedPreferences.getInstance();
      final unlocked = prefs.getStringList('unlockedAchievements') ?? [];
      if (!unlocked.contains('first_flag')) {
        await unlockAchievement('first_flag');
        unlocked.add('first_flag');
        await prefs.setStringList('unlockedAchievements', unlocked);
      }

      // 🚀 --- SMART QUESTION SELECTION BASED ON LEVEL SIZE ---
      final Map<int, Future<bool> Function(int, {required int currentScore, required int totalQuestions})> methodByIndex = {
        1: _askRandomCarImageQuestion,
        2: _askRandomModelBrandQuestion,
        3: _askBrandImageChoiceQuestion,
        4: _askDescriptionToCarImageQuestion,
        5: _askModelOnlyImageQuestion,
        6: _askOriginCountryQuestion,
        7: _askSpecialFeatureQuestion,
        8: _askMaxSpeedQuestion,
        9: _askAccelerationQuestion,
        10: _askHorsepowerQuestion,
        11: _askDescriptionSlideshowQuestion,
        12: _askModelNameToBrandQuestion,
      };

      List<int> selectedIndices = [];
      if (totalQuestions <= 4) {
        selectedIndices = List.of(_easyQuestions)..shuffle();
        selectedIndices = selectedIndices.take(totalQuestions).toList();
      } else if (totalQuestions <= 8) {
        selectedIndices = []
          ..addAll((_easyQuestions..shuffle()).take(4))
          ..addAll((_mediumQuestions..shuffle()).take(totalQuestions - 4));
      } else {
        selectedIndices = []
          ..addAll((_easyQuestions..shuffle()).take(4))
          ..addAll((_mediumQuestions..shuffle()).take(4))
          ..addAll((_hardQuestions..shuffle()).take(totalQuestions - 8));
      }

      final questionMethods = selectedIndices.map((qIndex) => methodByIndex[qIndex]!).toList();
      // 🚀 --- END SMART SELECTION ---

      for (int i = 0; i < questionMethods.length; i++) {
        await _incrementQuestionAttemptCount();
        final method = questionMethods[i];
        bool correct = await method(
          i + 1,
          currentScore: quizScore,
          totalQuestions: questionMethods.length,
        );

        if (correct) {
          quizScore++;
          await _incrementCorrectAnswerCount();
        }
      }

      _awaitingFlagTap = false;

      if (!_isCorrectionRun) {
        if (_currentIndex != _finalFlagIndex) {
          if (quizScore >= (questionMethods.length / 2).ceil()) {
            _consecutiveFails = 0;
            await _saveConsecutiveFails();
            int prevScore = _previousScores[flagIndex] ?? 0;
            int delta = quizScore - prevScore;
            final previousGearCount = _gearCount;
            _gearCount += delta;
            _previousScores[flagIndex] = quizScore;

            // Track gear update
            _trackGearUpdate(previousGearCount, _gearCount, source: 'challenge');

            if (quizScore == questionMethods.length) {
              _flagStatus[flagIndex] = 'green';
              _challengeColors[challengeNumber] = 'green';
            } else if (quizScore >= (questionMethods.length * 0.75).ceil()) {
              _flagStatus[flagIndex] = 'yellow';
              _challengeColors[challengeNumber] = 'yellow';
            } else {
              _flagStatus[flagIndex] = 'orange';
              _challengeColors[challengeNumber] = 'orange';
            }

            await _saveGearCount();
            widget.onGearUpdate(_gearCount);
            _retryButtonActive = false;
            _animateToNextPoint();
            widget.recordChallengeCompletion?.call();
          } else {
            _consecutiveFails++;
            await _saveConsecutiveFails();
            lostLife = true;
            _flagStatus[flagIndex] = 'red';
            _challengeColors[challengeNumber] = 'red';
            widget.onChallengeFail();
            _retryButtonActive = false;

            if (_consecutiveFails >= 3) {
              // Offer the stuck popup and provide a pass-action that grants full success:
              await _showStuckPopup(onPassAction: () async {
                // 1) Reset fail counter and mark green (full success)
                setState(() {
                  _consecutiveFails = 0;
                  _flagStatus[flagIndex] = 'green';
                  _challengeColors[challengeNumber] = 'green';
                  _awaitingFlagTap = false;
                  _retryButtonActive = false;
                });

                // 2) Award the missing gears for this flag (treat ad as full score)
                final int prevScore = _previousScores[flagIndex] ?? 0;
                final int totalQuestions = questionMethods.length;
                final int delta = totalQuestions - prevScore;
                if (delta > 0) {
                  final previousGearCount = _gearCount;
                  _gearCount += delta;
                  _previousScores[flagIndex] = totalQuestions;
                  await _saveGearCount();
                  widget.onGearUpdate(_gearCount);
                  _trackGearUpdate(previousGearCount, _gearCount, source: 'ad_pass');
                  // count as a completed challenge for daily streaks / history
                  widget.recordChallengeCompletion?.call();
                }

                // 3) Persist progress and move forward
                await _saveProgressToStorage();
                // animate forward
                _animateToNextPoint();
              });
            }
          }
        } else {
          if (quizScore >= (questionMethods.length / 2).ceil()) {
            if (quizScore == questionMethods.length) {
              _flagStatus[flagIndex] = 'green';
              _challengeColors[challengeNumber] = 'green';
            } else if (quizScore >= (questionMethods.length * 0.75).ceil()) {
              _flagStatus[flagIndex] = 'yellow';
              _challengeColors[challengeNumber] = 'yellow';
            } else {
              lostLife = true;
              _flagStatus[flagIndex] = 'red';
              _challengeColors[challengeNumber] = 'red';
              widget.onChallengeFail();
              _retryButtonActive = false;
              _showRetryButton = true;
              await _saveProgressToStorage();
              setState(() {});
              return;
            }

            int prevScore = _previousScores[flagIndex] ?? 0;
            int delta = quizScore - prevScore;
            final previousGearCount = _gearCount;
            _gearCount += delta;
            _previousScores[flagIndex] = quizScore;

            // Track gear update
            _trackGearUpdate(previousGearCount, _gearCount, source: 'challenge');
            await _saveGearCount();
            widget.onGearUpdate(_gearCount);


            await prefs.setStringList('unlockedAchievements', unlocked);
          } else {
            lostLife = true;
            _flagStatus[flagIndex] = 'red';
            _challengeColors[challengeNumber] = 'red';
            widget.onChallengeFail();
            _retryButtonActive = false;
            _showRetryButton = true;
          }
        }
      } else {
        // Correction run logic
        int prevScore = _previousScores[flagIndex] ?? 0;

        if (quizScore > prevScore) {
          // Score improved during correction!

          // Award missing gears
          int delta = quizScore - prevScore;
          _gearCount += delta;
          _previousScores[flagIndex] = quizScore;

          // Update flag color based on new score
          if (quizScore == totalQuestions) {
            _flagStatus[flagIndex] = 'green';
            _challengeColors[challengeNumber] = 'green';
          } else if (quizScore >= (totalQuestions * 0.75).ceil()) {
            _flagStatus[flagIndex] = 'yellow';
            _challengeColors[challengeNumber] = 'yellow';
          } else if (quizScore >= (totalQuestions / 2).ceil()) {
            _flagStatus[flagIndex] = 'orange';
            _challengeColors[challengeNumber] = 'orange';
          }

          // Save and update
          await _saveGearCount();
          widget.onGearUpdate(_gearCount);

          widget.recordChallengeCompletion?.call();

          if (_flagStatus[flagIndex] == 'green') {
            // Full success: Move forward

            if (_currentIndex == _finalFlagIndex) {
              // ✅ Final flag reached
              _awaitingFlagTap = false;
              _retryButtonActive = false;
              _showRetryButton = false;
              await _saveProgressToStorage();
              setState(() {});
            } else {
              // ✅ Not final flag: animate forward
              _awaitingFlagTap = false;
              _retryButtonActive = false;
              _animateToNextPoint();
            }
          }
          // ❌ If not green: stay stuck at current flag
        } else {
          // No improvement: Lose a life
          widget.onChallengeFail();
        }
      }


      await _saveProgressToStorage();
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitDependencies) {
      _didInitDependencies = true;

      // Now safe to use MediaQuery
      _previousOffset = _currentPathPoints.first;
      _animation = AlwaysStoppedAnimation<Offset>(_previousOffset);

      if (_currentPathPoints.length > 1) {
        _animateToNextPoint();
      }
    }
  }

  Future<bool> _askMaxSpeedQuestion(int questionNumber, {required int currentScore, required int totalQuestions}) async {
    if (carData.isEmpty) return false;

    // Pick a random car
    final correctCar = (carData..shuffle()).first;
    final brand = correctCar['brand']!;
    final model = correctCar['model']!;
    final correctSpeed = correctCar['topSpeed'] ?? "???";
    final fileBase = _formatFileName(brand, model);

    // Build 4 max speed options
    final speedOptions = <String>{correctSpeed};
    while (speedOptions.length < 4) {
      final candidate = (carData..shuffle()).first['topSpeed'] ?? "???";
      speedOptions.add(candidate);
    }
    final options = speedOptions.toList()..shuffle();

    return (await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => _QuestionPage(
          content: _MaxSpeedQuestionContent(
            questionNumber: questionNumber,
            currentScore: currentScore,
            totalQuestions: totalQuestions,
            brand: brand,
            model: model,
            fileBase: fileBase,
            correctSpeed: correctSpeed,
            options: options,
          ),
        ),
      ),
    )) ?? false;
  }

  Future<bool> _askRandomModelBrandQuestion(int questionNumber, {required int currentScore, required int totalQuestions}) async {
    if (carData.isEmpty) return false;

    // Pick a random car
    final row = (carData..shuffle()).first;
    final brand = row['brand']!;
    final model = row['model']!;
    final fileBase = _formatFileName(brand, model);
    final correctAnswer = brand;

    // Build four brand name options
    final allBrands = carData.map((e) => e['brand']!).toSet().toList();
    final opts = <String>{correctAnswer};
    while (opts.length < 4) {
      opts.add((allBrands..shuffle()).first);
    }
    final options = opts.toList()..shuffle();

    // Full page: rotating images + brand name choices
    return (await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => _QuestionPage(
          content: _RandomModelBrandQuestionContent(
            questionNumber: questionNumber,
            currentScore: currentScore,
            totalQuestions: totalQuestions,
            fileBase: fileBase,
            correctAnswer: correctAnswer,
            options: options,
          ),
        ),
      ),
    )) ?? false;
  }

  Future<bool> _askModelNameToBrandQuestion(int questionNumber, {required int currentScore, required int totalQuestions}) async {
    if (carData.isEmpty) return false;

    // Pick a random car
    final correctCar = (carData..shuffle()).first;
    final brand = correctCar['brand']!;
    final model = correctCar['model']!;

    // Build 4 brand options
    final brandOptions = <String>{brand};
    while (brandOptions.length < 4) {
      final candidate = (carData..shuffle()).first['brand'] ?? "???";
      brandOptions.add(candidate);
    }
    final options = brandOptions.toList()..shuffle();

    return (await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => _QuestionPage(
          content: _ModelNameToBrandQuestionContent(
            questionNumber: questionNumber,
            currentScore: currentScore,
            totalQuestions: totalQuestions,
            model: model,
            correctBrand: brand,
            options: options,
          ),
        ),
      ),
    )) ?? false;
  }

  Future<bool> _askHorsepowerQuestion(int questionNumber, {required int currentScore, required int totalQuestions}) async {
    if (carData.isEmpty) return false;

    // Pick a random car
    final correctCar = (carData..shuffle()).first;
    final brand = correctCar['brand']!;
    final model = correctCar['model']!;
    final correctHorsepower = correctCar['horsepower'] ?? "???";
    final fileBase = _formatFileName(brand, model);

    // Build 4 horsepower options
    final horsepowerOptions = <String>{correctHorsepower};
    while (horsepowerOptions.length < 4) {
      final candidate = (carData..shuffle()).first['horsepower'] ?? "???";
      horsepowerOptions.add(candidate);
    }
    final options = horsepowerOptions.toList()..shuffle();

    return (await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => _QuestionPage(
          content: _HorsepowerQuestionContent(
            questionNumber: questionNumber,
            currentScore: currentScore,
            totalQuestions: totalQuestions,
            fileBase:          fileBase,
            correctAnswer:     correctHorsepower,
            options:           options,
          ),
        ),
      ),
    )) ?? false;
  }

  Future<bool> _askAccelerationQuestion(int questionNumber, {required int currentScore, required int totalQuestions}) async {
    if (carData.isEmpty) return false;

    // Pick a random car
    final correctCar = (carData..shuffle()).first;
    final brand = correctCar['brand']!;
    final model = correctCar['model']!;
    final correctAcceleration = correctCar['acceleration'] ?? "???";
    final fileBase = _formatFileName(brand, model);

    // Build 4 acceleration options
    final accelerationOptions = <String>{correctAcceleration};
    while (accelerationOptions.length < 4) {
      final candidate = (carData..shuffle()).first['acceleration'] ?? "???";
      accelerationOptions.add(candidate);
    }
    final options = accelerationOptions.toList()..shuffle();

    return (await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => _QuestionPage(
          content: _AccelerationQuestionContent(
            questionNumber:       questionNumber,
            currentScore:         currentScore,
            totalQuestions:       totalQuestions,
            brand:                brand,              // ← you forgot to pass these
            model:                model,
            fileBase:             fileBase,
            correctAcceleration:  correctAcceleration, // ← correct parameter name
            options:              options,
          ),
        ),
      ),
    )) ?? false;
  }

  Future<bool> _askRandomCarImageQuestion(int questionNumber, {required int currentScore, required int totalQuestions}) async {
    if (carData.isEmpty) return false;

    // pick a random car
    final row = (carData..shuffle()).first;
    final brand = row['brand'] ?? "???";
    final model = row['model'] ?? "???";
    final correctAnswer = "$brand $model";
    final fileBase = _formatFileName(brand, model);

    // build four options
    final optionsSet = <String>{correctAnswer};
    while (optionsSet.length < 4) {
      final d = (carData..shuffle()).first;
      optionsSet.add("${d['brand']} ${d['model']}");
    }
    final options = optionsSet.toList()..shuffle();

    return (await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => _QuestionPage(
          content: _RandomCarImageQuestionContent(
            questionNumber: questionNumber,
            currentScore: currentScore,
            totalQuestions: totalQuestions,
            fileBase: fileBase,
            correctAnswer: correctAnswer,
            options: options,
          ),
        ),
      ),
    )) ?? false;
  }

  Future<bool> _askBrandImageChoiceQuestion(int questionNumber, {required int currentScore, required int totalQuestions}) async {
    if (carData.isEmpty) return false;

    // Pick target brand
    final targetCar = (carData..shuffle()).first;
    final targetBrand = targetCar['brand']!;

    final optionCars = <Map<String, String>>{targetCar};
    while (optionCars.length < 4) {
      final candidate = (carData..shuffle()).first;
      if (candidate['brand'] != targetBrand) {
        optionCars.add(candidate);
      }
    }
    final options = optionCars.toList()..shuffle();

    return (await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => _QuestionPage(
          content: _BrandImageChoiceQuestionContent(
            questionNumber: questionNumber,
            currentScore: currentScore,
            totalQuestions: totalQuestions,
            targetBrand: targetBrand,
            imageBases: options.map((car) {
              final brand = car['brand']!;
              final model = car['model']!;
              return _formatFileName(brand, model);
            }).toList(),
            optionBrands: options.map((car) => car['brand']!).toList(),
            correctBrand: targetBrand,
          ),
        ),
      ),
    )) ?? false;
  }

  Future<bool> _askDescriptionToCarImageQuestion(int questionNumber, {required int currentScore, required int totalQuestions}) async {
    if (carData.isEmpty) return false;

    // Pick the correct car
    final correctCar = (carData..shuffle()).first;
    final correctDesc = correctCar['description'] ?? "???";
    final correctBrand = correctCar['brand']!;
    final correctModel = correctCar['model']!;

    // Build 3 wrong cars
    final optionsSet = <Map<String, String>>{correctCar};
    while (optionsSet.length < 4) {
      final candidate = (carData..shuffle()).first;
      if (candidate['description'] != correctDesc) {
        optionsSet.add(candidate);
      }
    }
    final options = optionsSet.toList()..shuffle();

    final imageBases = options.map((car) => _formatFileName(car['brand']!, car['model']!)).toList();
    final correctIndex = options.indexWhere((car) => car['brand'] == correctBrand && car['model'] == correctModel);

    return (await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => _QuestionPage(
          content: _DescriptionToCarImageQuestionContent(
            questionNumber: questionNumber,
            currentScore: currentScore,
            totalQuestions: totalQuestions,
            description: correctDesc,
            imageBases: imageBases,
            correctIndex: correctIndex,
          ),
        ),
      ),
    )) ?? false;
  }

  Future<bool> _askModelOnlyImageQuestion(int questionNumber, {required int currentScore, required int totalQuestions}) async {
    if (carData.isEmpty) return false;

    // Pick the correct car
    final correctCar = (carData..shuffle()).first;
    final correctBrand = correctCar['brand']!;
    final correctModel = correctCar['model']!;
    final correctFileBase = _formatFileName(correctBrand, correctModel);

    // Build 4 model name options
    final optionsSet = <String>{correctModel};
    while (optionsSet.length < 4) {
      final candidate = (carData..shuffle()).first['model']!;
      optionsSet.add(candidate);
    }
    final options = optionsSet.toList()..shuffle();

    return (await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => _QuestionPage(
          content: _ModelOnlyImageQuestionContent(
            questionNumber: questionNumber,
            currentScore: currentScore,
            totalQuestions: totalQuestions,
            fileBase: correctFileBase,
            correctModel: correctModel,
            options: options,
          ),
        ),
      ),
    )) ?? false;
  }

  Future<bool> _askDescriptionSlideshowQuestion(int questionNumber, {required int currentScore, required int totalQuestions}) async {
    if (carData.isEmpty) return false;

    // Pick a random car
    final correctCar = (carData..shuffle()).first;
    final brand = correctCar['brand']!;
    final model = correctCar['model']!;
    final correctDescription = correctCar['description'] ?? "???";
    final fileBase = _formatFileName(brand, model);

    // Build 4 description options
    final descriptionOptions = <String>{correctDescription};
    while (descriptionOptions.length < 4) {
      final candidate = (carData..shuffle()).first['description'] ?? "???";
      descriptionOptions.add(candidate);
    }
    final options = descriptionOptions.toList()..shuffle();

    return (await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => _QuestionPage(
          content: _DescriptionSlideshowQuestionContent(
            questionNumber: questionNumber,
            currentScore: currentScore,
            totalQuestions: totalQuestions,
            fileBase: fileBase,
            correctDescription: correctDescription,
            options: options,
          ),
        ),
      ),
    )) ?? false;
  }

Future<void> _saveConsecutiveFails() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('consecutiveFails', _consecutiveFails);
}

Future<void> _loadConsecutiveFails() async {
  final prefs = await SharedPreferences.getInstance();
  _consecutiveFails = prefs.getInt('consecutiveFails') ?? 0;
}

  Future<bool> _askSpecialFeatureQuestion(int questionNumber, {required int currentScore, required int totalQuestions}) async {
    if (carData.isEmpty) return false;

    // Pick a random car
    final correctCar = (carData..shuffle()).first;
    final brand = correctCar['brand']!;
    final model = correctCar['model']!;
    final correctFeature = correctCar['specialFeature'] ?? "???";
    final fileBase = _formatFileName(brand, model);

    // Build 4 feature options
    final featureOptions = <String>{correctFeature};
    while (featureOptions.length < 4) {
      final candidate = (carData..shuffle()).first['specialFeature'] ?? "???";
      featureOptions.add(candidate);
    }
    final options = featureOptions.toList()..shuffle();

    return (await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => _QuestionPage(
          content: _SpecialFeatureQuestionContent(
            questionNumber: questionNumber,
            currentScore: currentScore,
            totalQuestions: totalQuestions,
            brand: brand,
            model: model,
            fileBase: fileBase,
            correctFeature: correctFeature,
            options: options,
          ),
        ),
      ),
    )) ?? false;
  }

  Future<bool> _askOriginCountryQuestion(int questionNumber, {required int currentScore, required int totalQuestions}) async {
    if (carData.isEmpty) return false;

    // Pick a random car (brand + model)
    final randomCar = (carData..shuffle()).first;
    final brand = randomCar['brand']!;
    final model = randomCar['model']!;
    final fileBase = _formatFileName(brand, model);
    final origin = randomCar['origin'] ?? "???";

    // Build 4 country options
    final countryOptions = <String>{origin};
    while (countryOptions.length < 4) {
      final candidate = (carData..shuffle()).first['origin'] ?? "???";
      countryOptions.add(candidate);
    }
    final options = countryOptions.toList()..shuffle();

    return (await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => _QuestionPage(
          content: _OriginCountryQuestionContent(
            questionNumber: questionNumber,
            currentScore: currentScore,
            totalQuestions: totalQuestions,
            brand: brand,
            model: model,
            fileBase: fileBase,
            origin: origin,
            options: options,
          ),
        ),
      ),
    )) ?? false;
  }

  String _formatFileName(String brand, String model) {
    String input = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return input
        .split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join();
  }

  void _showTrackPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('home.tracks'.tr()),
          content: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTrackWidget(1),
                _buildTrackWidget(2),
                _buildTrackWidget(3),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () { Navigator.of(context).pop(); },
              child: Text('common.close'.tr()),
            )
          ],
        );
      },
    );
  }

  Widget _buildTrackWidget(int trackNumber) {
    bool unlocked = trackNumber <= _currentTrack;
    int maxLevels = trackNumber == 1 ? 10 : (trackNumber == 2 ? 20 : 30);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.0),
      width: 250,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'home.track'.tr(namedArgs: {'number': trackNumber.toString()}) + (unlocked ? "" : " (${'home.locked'.tr()})"),
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Transform.scale(
              scale: 0.8,
              child: Image.asset(
                'assets/home/track${trackNumber}.png',
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 8),
            unlocked
                ? Column(
                    children: List.generate(maxLevels, (index) {
                      int level = index + 1;
                      double progress = 0.0;
                      if (trackNumber < _currentTrack) {
                        progress = 1.0;
                      } else if (trackNumber == _currentTrack) {
                        if (level < (_sessionsCompleted + 1)) {
                          progress = 1.0;
                        } else if (level == (_sessionsCompleted + 1)) {
                          progress = (_gearCount - _gearCountBeforeLevel) / _requiredGearsForCurrentLevel();
                          progress = progress.clamp(0.0, 1.0);
                        } else {
                          progress = 0.0;
                        }
                      }
                      int requiredGears;
                      if (trackNumber == 1) {
                        requiredGears = level < 10 ? (level + 2) * 10 : 120;
                      } else if (trackNumber == 2) {
                        requiredGears = (level + 2) * 10;
                      } else {
                        if (level >= 20) {
                          requiredGears = 220;
                        } else {
                          requiredGears = (level + 2) * 10;
                        }
                      }
                      if (trackNumber == _currentTrack && level == (_sessionsCompleted + 1)) {
                        requiredGears = _requiredGearsForCurrentLevel();
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('home.levelRequired'.tr(namedArgs: {'level': level.toString(), 'gears': requiredGears.toString()}), style: const TextStyle(fontSize: 12)),
                            SizedBox(height: 2),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          ],
                        ),
                      );
                    }),
                  )
                : Container(
                    height: 232,
                    alignment: Alignment.center,
                    child: Icon(Icons.lock, size: 50, color: Colors.grey),
                  ),
          ],
        ),
      ),
    );
  }
 
  /// Picks the correct asset path for the given flagIndex’s status.
  String _flagAssetPath(int flagIndex) {
    final status = _flagStatus[flagIndex];
    switch (status) {
      case 'green':
        return 'assets/home/GreenFlag.png';
      case 'yellow':
        return 'assets/home/YellowFlag.png';
      case 'orange':
        return 'assets/home/OrangeFlag.png';
      default:
        return 'assets/home/RedFlag.png';
    }
  }

  @override
  void dispose() {
    try { AudioFeedback.instance.playEvent(SoundEvent.pageClose); } catch (_) {}
    // Si CETTE classe a des contrôleurs, dispose-les ici (sinon ne mets rien).
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // fractionally sized images:
        final flagSize = w * 0.11;      // ≈40px on a 360px-wide screen
        final carSize  = _currentTrack == 3
            ? w * 0.07                  // ≈25px
            : w * 0.083;                // ≈30px

        // “level” widget vertical positions:
        final levelTop = _currentTrack == 1
            ? h * 0.003                 // ≈2px
            : _currentTrack == 3
              ? h * 0.014               // ≈10px
              : h * 0.9;                // ≈510px on a 730px-high screen

        // “level” widget horizontal offsets:
        final levelRight = _currentTrack == 1 ? w * 0.042 : null;  // ≈15px
        final levelLeft  = _currentTrack == 2
            ? w * 0.14                 // ≈50px
            : _currentTrack == 3
              ? w * 0.7               // ≈300px
              : null;

        // retry/next button:
        final btnBottom = h * 0.07;    // ≈50px
        final btnRight  = w * 0.04;    // ≈15px

        final double tapSize = math.max(flagSize, 48.0);

        // ─── 1) Pick the fractional track points ────────────────
        final frac = _currentTrack == 1
          ? _flagFractionsTrack1
          : _fractionalTracks[_currentTrack]!;

        // give each track its own tweaked multipliers:
        double xMul, yMul;
        if (_currentTrack == 1) {
          xMul = 1.75;  // original values
          yMul = 1.7;
        } else if (_currentTrack == 2) {
          xMul = 1.67;   // adjust these until track 2 flags line up
          yMul = 1.6;
        } else /* track 3 */ {
          xMul = 1.8;   // adjust these until track 3 flags line up
          yMul = 1.7;
        }

        // ─── 3) Compute screen‐space points with multipliers ────
        final screenPoints = frac.map((f) {
          final dx = f.dx * w * xMul;
          final dy = f.dy * h * yMul;
          return Offset(dx, dy);
        }).toList();

        // ─── CAR ────────────────────────────────────────────────
        // animation.value is now a fraction 0…1
        final carFrac = _animation.value;
        final carScreen = Offset(
          carFrac.dx * w * xMul,
          carFrac.dy * h * yMul,
        );
        
        return Stack(children: [
          // ─── TRACK ─────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/home/track$_currentTrack.png',
              fit: BoxFit.fill,  // fills the full w×h
            ),
          ),

          // ─── FLAGS ─────────────────────────────
          for (var idx in _flagIndices)
            if (idx < screenPoints.length)
              Positioned(
                left: screenPoints[idx].dx - tapSize/2,
                top:  screenPoints[idx].dy - tapSize/2,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: (widget.currentLives == 0 || _retryButtonActive)
                        ? null
                        : () {
                            setState(() {
                              _showRetryButton = false;  // on désactive le flag “Retry”  
                            });
                            _onFlagTap(idx);             // et relance directement le challenge
                          },
                  child: SizedBox(
                    width: tapSize,
                    height: tapSize,
                    child: Center(
                      child: Image.asset(
                        _flagAssetPath(idx),
                        width: flagSize,
                        height: flagSize,
                      ),
                    ),
                  ),
                ),
              ),

          // ─── CAR ────────────────────────────────────────────────
          Positioned(
            left: carScreen.dx - carSize/2,
            top:  carScreen.dy - carSize/2,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: _carAngle,
                child: Image.asset('assets/home/car.png',
                  width: carSize,
                  height: carSize,
                ),
              ),
            ),
          ),

          // ─── Level + progress bar ─────────────────────────────────
          Positioned(
            top:   levelTop,
            right: levelRight,
            left:  levelLeft,
            child: GestureDetector(
              key: widget.levelProgressKey,
              onTap: _showTrackPopup,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF3D0000).withOpacity(0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Level text with trophy icon
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'home.level'.tr(namedArgs: {'number': (_sessionsCompleted + 1).toString()}),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Progress bar with animation
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      width: 140,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: (_gearCount - _gearCountBeforeLevel) /
                              _requiredGearsForCurrentLevel(),
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF3D0000),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Gear count display
                    Text(
                      '${(_gearCount - _gearCountBeforeLevel)}/${_requiredGearsForCurrentLevel()} ⚙',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Retry / Next Level / Next Track button ────────────────
          if (_currentIndex == _finalFlagIndex &&
              _challengeColors[_challengeNumberForFlag(_currentIndex)] != null)
            Positioned(
              bottom: btnBottom,
              right:  btnRight,
              child: Builder(
                builder: (context) {
                  final bool challengeCompleted =
                      _challengeColors[_challengeNumberForFlag(_currentIndex)] ==
                          'green';
                  final bool enoughGears = (_gearCount - _gearCountBeforeLevel) >=
                      _requiredGearsForCurrentLevel();
                  final bool lastLevel =
                      (_sessionsCompleted + 1) >= _maxLevelsForTrack();

                  // ─ Next Track ─
                  if (challengeCompleted && enoughGears && lastLevel && _currentTrack < 3) {
                    return SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          final unlocked =
                              prefs.getStringList("unlockedAchievements") ?? [];

                          // Unlock achievements as before
                          if (_currentTrack == 1 && !unlocked.contains("track_conqueror")) {
                            await unlockAchievement("track_conqueror");
                            unlocked.add("track_conqueror");
                          }
                          if (_currentTrack == 1 && _gearCount >= 750 && !unlocked.contains("track_unlocker_i")) {
                            await unlockAchievement("track_unlocker_i");
                            unlocked.add("track_unlocker_i");
                          }
                          if (_currentTrack == 2 && _gearCount >= 3250 && !unlocked.contains("track_unlocker_ii")) {
                            await unlockAchievement("track_unlocker_ii");
                            unlocked.add("track_unlocker_ii");
                          }
                          await prefs.setStringList('unlockedAchievements', unlocked);

                          setState(() {
                            _currentTrack++;
                            _flagIndices = Set<int>.from(_flagIndicesSorted);
                            _sessionsCompleted = 0;
                            _gearCountBeforeLevel = _gearCount;
                            _resetFlagsForNewLevel();
                            _currentIndex = 0;
                            _previousOffset = _currentPathPoints.first;
                            _controller.reset();
                          });

                          _animateToNextPoint();
                        },
                        child: Text('home.nextTrack'.tr()),
                      ),
                    );
                  }
                  // ─ Next Level ─
                  else if (challengeCompleted && enoughGears) {
                    return SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _sessionsCompleted++;
                            _gearCountBeforeLevel = _gearCount;
                            _gateOpen = true;
                            _resetFlagsForNewLevel();
                            _currentIndex = 0;
                            _previousOffset = _currentPathPoints.first;
                            _controller.reset();
                          });
                          Future.delayed(Duration(milliseconds: 50), () {
                            setState(() {
                              _flagIndices = Set<int>.from(_flagIndicesSorted);
                            });
                            _saveGearCount();
                            widget.onGearUpdate(_gearCount);
                            _scrollByOneTrackImage();
                            _animateToNextPoint();
                          });
                        },
                        child: Text('home.nextLevel'.tr()),
                      ),
                    );
                  }
                  // ─ Retry ─
                  else {
                    return SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isCorrectionRun = true;
                            _retryButtonActive = false;
                            _showRetryButton = false;
                          });
                          _correctMistakes();
                        },
                        child: Text('home.retry'.tr()),
                      ),
                    );
                  }
                },
              ),
            ),
        ],
      );
    }));
  }
}

// ── Full-screen question route ───────────────────────────────────────────────
class _QuestionPage extends StatelessWidget {
  final Widget content;
  const _QuestionPage({required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // disables back arrow
        title: Text('home.flagChallenge'.tr()),    // or any title you use
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(child: content),
      ),
    );
  }
}

/// Widget for Question 2 – pick the brand of a model
class _RandomModelBrandQuestionContent extends StatefulWidget {
  final int questionNumber;
  final int currentScore;
  final int totalQuestions;
  final String fileBase;
  final String correctAnswer;
  final List<String> options;

  const _RandomModelBrandQuestionContent({
    required this.questionNumber,
    required this.currentScore,
    required this.totalQuestions,
    required this.fileBase,
    required this.correctAnswer,
    required this.options,
  });

  @override
  State<_RandomModelBrandQuestionContent> createState() =>
      _RandomModelBrandQuestionContentState();
}

class _RandomModelBrandQuestionContentState
    extends State<_RandomModelBrandQuestionContent> with AudioAnswerMixin {
  bool _answered = false;
  String? _selectedBrand;

  void _onTap(String brand) {
    if (_answered) return;

    _audioPlayTap();

    final bool correct = brand == widget.correctAnswer;

    setState(() {
      _answered = true;
      _selectedBrand = brand;
      if (correct) {
        _streak += 1;
      } else {
        _streak = 0;
      }
    });

    if (correct) {
      _audioPlayAnswerCorrect();
      if (_streak > 0 && _streak % 3 == 0) {
        _audioPlayStreak(milestone: _streak);
      }
    } else {
      _audioPlayAnswerWrong();
    }

    Future.delayed(const Duration(seconds: 1), () {
      _audioPlayPageFlip();
      Navigator.of(context).pop(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Text(
            "questions.questionNumber".tr(namedArgs: {'number': widget.questionNumber.toString()}) + " " + "questions.score".tr(namedArgs: {'current': widget.currentScore.toString(), 'total': widget.totalQuestions.toString()}),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Prompt
          Text(
            "questions.brandOfModel".tr(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Six static frames, one under the other
          for (int i = 0; i < 6; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image(
                  image: _assetImageProvider('${widget.fileBase}$i.webp'),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Brand choice buttons
          for (var b in widget.options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Material(
                    color: _answered
                        ? (b == widget.correctAnswer
                            ? Colors.green
                            : (b == _selectedBrand
                                ? Colors.red
                                : Colors.grey[800]!))
                        : Colors.grey[800],
                    child: InkWell(
                      onTap: () => _onTap(b),
                      child: Center(
                        child: Text(
                          b,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Widget for Question 12 ─────────────────────────────────────────────────────
class _ModelNameToBrandQuestionContent extends StatefulWidget {
  final int questionNumber;
  final int currentScore;
  final int totalQuestions;
  final String model;
  final String correctBrand;
  final List<String> options;

  const _ModelNameToBrandQuestionContent({
    required this.questionNumber,
    required this.currentScore,
    required this.totalQuestions,
    required this.model,
    required this.correctBrand,
    required this.options,
  });

  @override
  State<_ModelNameToBrandQuestionContent> createState() =>
      _ModelNameToBrandQuestionContentState();
}

class _ModelNameToBrandQuestionContentState
    extends State<_ModelNameToBrandQuestionContent> with AudioAnswerMixin {
  bool _answered = false;
  String? _selectedBrand;

  void _onTap(String brand) {
    if (_answered) return;

    _audioPlayTap();

    final bool correct = brand == widget.correctBrand;

    setState(() {
      _answered = true;
      _selectedBrand = brand;
      if (correct) {
        _streak += 1;
      } else {
        _streak = 0;
      }
    });

    if (correct) {
      _audioPlayAnswerCorrect();
      if (_streak > 0 && _streak % 3 == 0) {
        _audioPlayStreak(milestone: _streak);
      }
    } else {
      _audioPlayAnswerWrong();
    }

    Future.delayed(const Duration(seconds: 1), () {
      _audioPlayPageFlip();
      Navigator.of(context).pop(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            "questions.questionNumber".tr(namedArgs: {'number': widget.questionNumber.toString()}) + " " + "questions.score".tr(namedArgs: {'current': widget.currentScore.toString(), 'total': widget.totalQuestions.toString()}),
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(height: 30),
          Text(
            "questions.brandMakesModel".tr(),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Text(
            widget.model,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 30),
          for (var brand in widget.options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Material(
                    color: _answered
                        ? (brand == widget.correctBrand
                            ? Colors.green
                            : (brand == _selectedBrand
                                ? Colors.red
                                : Colors.grey[800]!))
                        : Colors.grey[800],
                    child: InkWell(
                      onTap: () => _onTap(brand),
                      child: Center(
                        child: Text(
                          brand,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


/// Widget for Question 11 – show six static frames, then centered, padded multi-line buttons
class _DescriptionSlideshowQuestionContent extends StatefulWidget {
  final int questionNumber;
  final int currentScore;
  final int totalQuestions;
  final String fileBase;
  final String correctDescription;
  final List<String> options;

  const _DescriptionSlideshowQuestionContent({
    required this.questionNumber,
    required this.currentScore,
    required this.totalQuestions,
    required this.fileBase,
    required this.correctDescription,
    required this.options,
  });

  @override
  _DescriptionSlideshowQuestionContentState createState() =>
      _DescriptionSlideshowQuestionContentState();
}

class _DescriptionSlideshowQuestionContentState
    extends State<_DescriptionSlideshowQuestionContent> with AudioAnswerMixin {
  bool _answered = false;
  String? _selectedDescription;

  void _onTap(String description) {
    if (_answered) return;

    _audioPlayTap();

    final bool correct = description == widget.correctDescription;

    setState(() {
      _answered = true;
      _selectedDescription = description;
      if (correct) {
        _streak += 1;
      } else {
        _streak = 0;
      }
    });

    if (correct) {
      _audioPlayAnswerCorrect();
      if (_streak > 0 && _streak % 3 == 0) {
        _audioPlayStreak(milestone: _streak);
      }
    } else {
      _audioPlayAnswerWrong();
    }

    Future.delayed(const Duration(seconds: 1), () {
      _audioPlayPageFlip();
      Navigator.of(context).pop(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ────────────────────────────────────────────────
          Text(
            "questions.questionNumber".tr(namedArgs: {'number': widget.questionNumber.toString()}) + " " + "questions.score".tr(namedArgs: {'current': widget.currentScore.toString(), 'total': widget.totalQuestions.toString()}),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),

          // ── Prompt ────────────────────────────────────────────────
          Text(
            "questions.descriptionMatch".tr(),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.normal),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // ── Six static frames ────────────────────────────────────
          for (int i = 0; i < 6; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image(
                  image: _assetImageProvider('${widget.fileBase}$i.webp'),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 24),

          // ── Description buttons ──────────────────────────────────
          for (var desc in widget.options)
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 6.0, horizontal: 24.0),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: _answered
                      ? (desc == widget.correctDescription
                          ? Colors.green
                          : (desc == _selectedDescription
                              ? Colors.red
                              : Colors.grey[800]!))
                      : Colors.grey[800],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                onPressed: () => _onTap(desc),
                child: Text(
                  desc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget for Question 10 – horsepower with smooth 2s fade transitions
class _HorsepowerQuestionContent extends StatefulWidget {
  final int questionNumber;
  final int currentScore;
  final int totalQuestions;
  final String fileBase;
  final String correctAnswer;
  final List<String> options;

  const _HorsepowerQuestionContent({
    required this.questionNumber,
    required this.currentScore,
    required this.totalQuestions,
    required this.fileBase,
    required this.correctAnswer,
    required this.options,
  });

  @override
  _HorsepowerQuestionContentState createState() =>
      _HorsepowerQuestionContentState();
}

class _HorsepowerQuestionContentState
    extends State<_HorsepowerQuestionContent> with AudioAnswerMixin {
  int _frameIndex = 0;
  bool _answered = false;
  String? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    // play page open sound
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}
    // Cycle frames every 2 seconds
  }

  @override
  void dispose() {
    try { AudioFeedback.instance.playEvent(SoundEvent.pageClose); } catch (_) {}
    // Si CETTE classe a des contrôleurs, dispose-les ici (sinon ne mets rien).
    super.dispose();
  }

  void _onTap(String answer) {
    if (_answered) return;

    _audioPlayTap();

    final bool correct = answer == widget.correctAnswer;

    setState(() {
      _answered = true;
      _selectedAnswer = answer;
      if (correct) {
        _streak += 1;
      } else {
        _streak = 0;
      }
    });

    if (correct) {
      _audioPlayAnswerCorrect();
      if (_streak > 0 && _streak % 3 == 0) {
        _audioPlayStreak(milestone: _streak);
      }
    } else {
      _audioPlayAnswerWrong();
    }

    Future.delayed(const Duration(seconds: 1), () {
      _audioPlayPageFlip();
      Navigator.of(context).pop(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Text(
            "questions.questionNumber".tr(namedArgs: {'number': widget.questionNumber.toString()}) + " " + "questions.score".tr(namedArgs: {'current': widget.currentScore.toString(), 'total': widget.totalQuestions.toString()}),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),
          Text(
            "questions.horsePower".tr(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // AnimatedSwitcher for smooth fade between frames
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Image(
                key: ValueKey<int>(_frameIndex),
                image: _assetImageProvider('${widget.fileBase}$_frameIndex.webp'),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Horsepower option buttons
          for (var opt in widget.options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Material(
                    color: _answered
                        ? (opt == widget.correctAnswer
                            ? Colors.green
                            : (opt == _selectedAnswer
                                ? Colors.red
                                : Colors.grey[800]!))
                        : Colors.grey[800],
                    child: InkWell(
                      onTap: () => _onTap(opt),
                      child: Center(
                        child: Text(
                          opt,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget for Question 9 – acceleration (0–100 km/h) with smooth 2s fade transitions
class _AccelerationQuestionContent extends StatefulWidget {
  final int questionNumber;
  final int currentScore;
  final int totalQuestions;
  final String brand;
  final String model;
  final String fileBase;
  final String correctAcceleration;
  final List<String> options;

  const _AccelerationQuestionContent({
    required this.questionNumber,
    required this.currentScore,
    required this.totalQuestions,
    required this.brand,
    required this.model,
    required this.fileBase,
    required this.correctAcceleration,
    required this.options,
  });

  @override
  State<_AccelerationQuestionContent> createState() =>
      _AccelerationQuestionContentState();
}

class _AccelerationQuestionContentState
    extends State<_AccelerationQuestionContent> with AudioAnswerMixin {
  int _frameIndex = 0;
  bool _answered = false;
  String? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    // play page open sound
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}
    // Cycle the image every 2 seconds
  }

  @override
  void dispose() {
    try { AudioFeedback.instance.playEvent(SoundEvent.pageClose); } catch (_) {}
    // Si CETTE classe a des contrôleurs, dispose-les ici (sinon ne mets rien).
    super.dispose();
  }

  void _onTap(String answer) {
    if (_answered) return;

    _audioPlayTap();

    final bool correct = answer == widget.correctAcceleration;

    setState(() {
      _answered = true;
      _selectedAnswer = answer;
      if (correct) {
        _streak += 1;
      } else {
        _streak = 0;
      }
    });

    if (correct) {
      _audioPlayAnswerCorrect();
      if (_streak > 0 && _streak % 3 == 0) {
        _audioPlayStreak(milestone: _streak);
      }
    } else {
      _audioPlayAnswerWrong();
    }

    Future.delayed(const Duration(seconds: 1), () {
      _audioPlayPageFlip();
      Navigator.of(context).pop(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Text(
            "questions.questionNumber".tr(namedArgs: {'number': widget.questionNumber.toString()}) + " " + "questions.score".tr(namedArgs: {'current': widget.currentScore.toString(), 'total': widget.totalQuestions.toString()}),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Prompt
          Text(
            "questions.acceleration".tr(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // AnimatedSwitcher for smooth fade between frames
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Image(
                key: ValueKey<int>(_frameIndex),
                image: _assetImageProvider('${widget.fileBase}$_frameIndex.webp'),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Acceleration option buttons
          for (var opt in widget.options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Material(
                    color: _answered
                        ? (opt == widget.correctAcceleration
                            ? Colors.green
                            : (opt == _selectedAnswer
                                ? Colors.red
                                : Colors.grey[800]!))
                        : Colors.grey[800],
                    child: InkWell(
                      onTap: () => _onTap(opt),
                      child: Center(
                        child: Text(
                          opt,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget for Question 8 – max speed with smooth 2s fade transitions
class _MaxSpeedQuestionContent extends StatefulWidget {
  final int questionNumber;
  final int currentScore;
  final int totalQuestions;
  final String brand;
  final String model;
  final String fileBase;
  final String correctSpeed;
  final List<String> options;

  const _MaxSpeedQuestionContent({
    required this.questionNumber,
    required this.currentScore,
    required this.totalQuestions,
    required this.brand,
    required this.model,
    required this.fileBase,
    required this.correctSpeed,
    required this.options,
  });

  @override
  State<_MaxSpeedQuestionContent> createState() =>
      _MaxSpeedQuestionContentState();
}

class _MaxSpeedQuestionContentState
    extends State<_MaxSpeedQuestionContent> with AudioAnswerMixin {
  int _frameIndex = 0;
  bool _answered = false;
  String? _selectedSpeed;

  @override
  void initState() {
    super.initState();
    // play page open sound
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}
    // Cycle frames every 2 seconds
  }

  @override
  void dispose() {
    try { AudioFeedback.instance.playEvent(SoundEvent.pageClose); } catch (_) {}
    // Si CETTE classe a des contrôleurs, dispose-les ici (sinon ne mets rien).
    super.dispose();
  }

  void _onTap(String speed) {
    if (_answered) return;

    _audioPlayTap();

    final bool correct = speed == widget.correctSpeed;

    setState(() {
      _answered = true;
      _selectedSpeed = speed;
      if (correct) {
        _streak += 1;
      } else {
        _streak = 0;
      }
    });

    if (correct) {
      _audioPlayAnswerCorrect();
      if (_streak > 0 && _streak % 3 == 0) {
        _audioPlayStreak(milestone: _streak);
      }
    } else {
      _audioPlayAnswerWrong();
    }

    Future.delayed(const Duration(seconds: 1), () {
      _audioPlayPageFlip();
      Navigator.of(context).pop(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Text(
            "questions.questionNumber".tr(namedArgs: {'number': widget.questionNumber.toString()}) + " " + "questions.score".tr(namedArgs: {'current': widget.currentScore.toString(), 'total': widget.totalQuestions.toString()}),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Prompt
          Text(
            "questions.maxSpeed".tr(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // AnimatedSwitcher for smooth fade between frames
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Image(
                key: ValueKey<int>(_frameIndex),
                image: _assetImageProvider('${widget.fileBase}$_frameIndex.webp'),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Speed option buttons
          for (var opt in widget.options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Material(
                    color: _answered
                        ? (opt == widget.correctSpeed
                            ? Colors.green
                            : (opt == _selectedSpeed
                                ? Colors.red
                                : Colors.grey[800]!))
                        : Colors.grey[800],
                    child: InkWell(
                      onTap: () => _onTap(opt),
                      child: Center(
                        child: Text(
                          opt,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget for Question 7 – special feature with smooth 2s fade transitions
class _SpecialFeatureQuestionContent extends StatefulWidget {
  final int questionNumber;
  final int currentScore;
  final int totalQuestions;
  final String brand;
  final String model;
  final String fileBase;
  final String correctFeature;
  final List<String> options;

  const _SpecialFeatureQuestionContent({
    required this.questionNumber,
    required this.currentScore,
    required this.totalQuestions,
    required this.brand,
    required this.model,
    required this.fileBase,
    required this.correctFeature,
    required this.options,
  });

  @override
  State<_SpecialFeatureQuestionContent> createState() =>
      _SpecialFeatureQuestionContentState();
}

class _SpecialFeatureQuestionContentState
    extends State<_SpecialFeatureQuestionContent> with AudioAnswerMixin {
  int _frameIndex = 0;
  bool _answered = false;
  String? _selectedFeature;

  @override
  void initState() {
    super.initState();
    // play page open sound
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}
    // Cycle the image every 2 seconds
  }

  @override
  void dispose() {
    try { AudioFeedback.instance.playEvent(SoundEvent.pageClose); } catch (_) {}
    // Si CETTE classe a des contrôleurs, dispose-les ici (sinon ne mets rien).
    super.dispose();
  }

  void _onTap(String feature) {
    if (_answered) return;

    _audioPlayTap();

    final bool correct = feature == widget.correctFeature;

    setState(() {
      _answered = true;
      _selectedFeature = feature;
      if (correct) {
        _streak += 1;
      } else {
        _streak = 0;
      }
    });

    if (correct) {
      _audioPlayAnswerCorrect();
      if (_streak > 0 && _streak % 3 == 0) {
        _audioPlayStreak(milestone: _streak);
      }
    } else {
      _audioPlayAnswerWrong();
    }

    Future.delayed(const Duration(seconds: 1), () {
      _audioPlayPageFlip();
      Navigator.of(context).pop(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Text(
            "questions.questionNumber".tr(namedArgs: {'number': widget.questionNumber.toString()}) + " " + "questions.score".tr(namedArgs: {'current': widget.currentScore.toString(), 'total': widget.totalQuestions.toString()}),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Prompt
          Text(
            "questions.specialFeature".tr(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Animated image with smooth fade
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Image(
                key: ValueKey<int>(_frameIndex),
                image: _assetImageProvider('${widget.fileBase}$_frameIndex.webp'),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Option buttons
          for (var opt in widget.options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Material(
                    color: _answered
                        ? (opt == widget.correctFeature
                            ? Colors.green
                            : (opt == _selectedFeature
                                ? Colors.red
                                : Colors.grey[800]!))
                        : Colors.grey[800],
                    child: InkWell(
                      onTap: () => _onTap(opt),
                      child: Center(
                        child: Text(
                          opt,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget for Question 4 – description → image with smooth 2s fade transitions
class _DescriptionToCarImageQuestionContent extends StatefulWidget {
  final int questionNumber;
  final int currentScore;
  final int totalQuestions;
  final String description;
  final List<String> imageBases;
  final int correctIndex;

  const _DescriptionToCarImageQuestionContent({
    required this.questionNumber,
    required this.currentScore,
    required this.totalQuestions,
    required this.description,
    required this.imageBases,
    required this.correctIndex,
  });

  @override
  State<_DescriptionToCarImageQuestionContent> createState() =>
      _DescriptionToCarImageQuestionContentState();
}

class _DescriptionToCarImageQuestionContentState
    extends State<_DescriptionToCarImageQuestionContent> with AudioAnswerMixin {
  int _frameIndex = 0;
  bool _answered = false;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    // play page open sound
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}
    // Cycle frames every 2 seconds
  }

  @override
  void dispose() {
    try { AudioFeedback.instance.playEvent(SoundEvent.pageClose); } catch (_) {}
    // Si CETTE classe a des contrôleurs, dispose-les ici (sinon ne mets rien).
    super.dispose();
  }

  void _onTap(int index) {
    if (_answered) return;

    _audioPlayTap();

    final bool correct = index == widget.correctIndex;

    setState(() {
      _answered = true;
      _selectedIndex = index;
      if (correct) {
        _streak += 1;
      } else {
        _streak = 0;
      }
    });

    if (correct) {
      _audioPlayAnswerCorrect();
      if (_streak > 0 && _streak % 3 == 0) {
        _audioPlayStreak(milestone: _streak);
      }
    } else {
      _audioPlayAnswerWrong();
    }

    Future.delayed(const Duration(seconds: 1), () {
      _audioPlayPageFlip();
      Navigator.of(context).pop(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            "questions.questionNumber".tr(namedArgs: {'number': widget.questionNumber.toString()}) + " " + "questions.score".tr(namedArgs: {'current': widget.currentScore.toString(), 'total': widget.totalQuestions.toString()}),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Description prompt
          Text(
            widget.description,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // 2×2 grid of smoothly transitioning images
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.imageBases.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemBuilder: (ctx, i) {
              final base = widget.imageBases[i];
              final assetName = '$base$_frameIndex.webp';
              final isCorrect = (i == widget.correctIndex);
              final isSelected = (i == _selectedIndex);

              return GestureDetector(
                onTap: () => _onTap(i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // AnimatedSwitcher for smooth fade between frames
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                        child: Image(
                          key: ValueKey<String>(assetName),
                          image: _assetImageProvider(assetName),
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Feedback overlay
                      if (_answered)
                        Container(
                          color: isCorrect
                              ? Colors.greenAccent
                              : (isSelected
                                  ? Colors.red
                                  : Colors.transparent),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Widget for Question 3 – tap the image of a certain brand, with smooth 2s fade transitions
class _BrandImageChoiceQuestionContent extends StatefulWidget {
  final int questionNumber;
  final int currentScore;
  final int totalQuestions;
  final String targetBrand;
  final List<String> imageBases;
  final List<String> optionBrands;
  final String correctBrand;

  const _BrandImageChoiceQuestionContent({
    required this.questionNumber,
    required this.currentScore,
    required this.totalQuestions,
    required this.targetBrand,
    required this.imageBases,
    required this.optionBrands,
    required this.correctBrand,
  });

  @override
  State<_BrandImageChoiceQuestionContent> createState() =>
      _BrandImageChoiceQuestionContentState();
}

class _BrandImageChoiceQuestionContentState
    extends State<_BrandImageChoiceQuestionContent> with AudioAnswerMixin {
  int _frameIndex = 0;
  bool _answered = false;
  String? _selectedBrand;

  @override
  void initState() {
    super.initState();
    // play page open sound
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}
    // Cycle through frames every 2 seconds
  }

  @override
  void dispose() {
    try { AudioFeedback.instance.playEvent(SoundEvent.pageClose); } catch (_) {}
    // Si CETTE classe a des contrôleurs, dispose-les ici (sinon ne mets rien).
    super.dispose();
  }

  void _onTap(String brand) {
    if (_answered) return;

    _audioPlayTap();

    final bool correct = brand == widget.correctBrand;

    setState(() {
      _answered = true;
      _selectedBrand = brand;
      if (correct) {
        _streak += 1;
      } else {
        _streak = 0;
      }
    });

    if (correct) {
      _audioPlayAnswerCorrect();
      if (_streak > 0 && _streak % 3 == 0) {
        _audioPlayStreak(milestone: _streak);
      }
    } else {
      _audioPlayAnswerWrong();
    }

    Future.delayed(const Duration(seconds: 1), () {
      _audioPlayPageFlip();
      Navigator.of(context).pop(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Text(
          "questions.questionNumber".tr(namedArgs: {'number': widget.questionNumber.toString()}) + " " + "questions.score".tr(namedArgs: {'current': widget.currentScore.toString(), 'total': widget.totalQuestions.toString()}),
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 20),

        // Prompt
        Text(
          'questions.brandImage'.tr(namedArgs: {'brand': widget.targetBrand}),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // 2×2 grid of smoothly transitioning images
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.imageBases.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemBuilder: (ctx, index) {
            final base = widget.imageBases[index];
            final brand = widget.optionBrands[index];
            final assetName = '$base$_frameIndex.webp';

            return GestureDetector(
              onTap: () => _onTap(brand),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // AnimatedSwitcher for smooth fade between frames
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: Image(
                        key: ValueKey<String>(assetName),
                        image: _assetImageProvider(assetName),
                        fit: BoxFit.cover,
                      ),
                    ),

                    // Feedback overlay
                    if (_answered)
                      Container(
                        color: brand == widget.correctBrand
                            ? Colors.green
                            : (brand == _selectedBrand
                                ? Colors.red
                                : Colors.transparent),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}


/// Widget for Question 6 – origin country with smooth 2s fade transitions
class _OriginCountryQuestionContent extends StatefulWidget {
  final int questionNumber;
  final int currentScore;
  final int totalQuestions;
  final String brand;
  final String model;
  final String fileBase;
  final String origin;
  final List<String> options;

  const _OriginCountryQuestionContent({
    required this.questionNumber,
    required this.currentScore,
    required this.totalQuestions,
    required this.brand,
    required this.model,
    required this.fileBase,
    required this.origin,
    required this.options,
  });

  @override
  State<_OriginCountryQuestionContent> createState() =>
      _OriginCountryQuestionContentState();
}

class _OriginCountryQuestionContentState
    extends State<_OriginCountryQuestionContent> with AudioAnswerMixin {
  int _frameIndex = 0;
  bool _answered = false;
  String? _selectedOrigin;

  @override
  void initState() {
    super.initState();
    // play page open sound
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}
    // Cycle frames every 2 seconds
  }

  @override
  void dispose() {
    try { AudioFeedback.instance.playEvent(SoundEvent.pageClose); } catch (_) {}
    // Si CETTE classe a des contrôleurs, dispose-les ici (sinon ne mets rien).
    super.dispose();
  }

  void _onTap(String origin) {
    if (_answered) return;

    _audioPlayTap();

    final bool correct = origin == widget.origin;

    setState(() {
      _answered = true;
      _selectedOrigin = origin;
      if (correct) {
        _streak += 1;
      } else {
        _streak = 0;
      }
    });

    if (correct) {
      _audioPlayAnswerCorrect();
      if (_streak > 0 && _streak % 3 == 0) {
        _audioPlayStreak(milestone: _streak);
      }
    } else {
      _audioPlayAnswerWrong();
    }

    Future.delayed(const Duration(seconds: 1), () {
      _audioPlayPageFlip();
      Navigator.of(context).pop(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Text(
            "questions.questionNumber".tr(namedArgs: {'number': widget.questionNumber.toString()}) + " " + "questions.score".tr(namedArgs: {'current': widget.currentScore.toString(), 'total': widget.totalQuestions.toString()}),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Prompt
          Text(
            "questions.origin".tr(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Smoothly fading image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Image(
                key: ValueKey<int>(_frameIndex),
                image: _assetImageProvider('${widget.fileBase}$_frameIndex.webp'),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Country choice buttons
          for (var opt in widget.options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Material(
                    color: _answered
                        ? (opt == widget.origin
                            ? Colors.green
                            : (opt == _selectedOrigin
                                ? Colors.red
                                : Colors.grey[800]!))
                        : Colors.grey[800],
                    child: InkWell(
                      onTap: () => _onTap(opt),
                      child: Center(
                        child: Text(
                          opt,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget pour la Question 5 – choisir le modèle uniquement via l’image
class _ModelOnlyImageQuestionContent extends StatefulWidget {
  final int questionNumber;
  final int currentScore;
  final int totalQuestions;
  final String fileBase;
  final String correctModel;
  final List<String> options;

  const _ModelOnlyImageQuestionContent({
    required this.questionNumber,
    required this.currentScore,
    required this.totalQuestions,
    required this.fileBase,
    required this.correctModel,
    required this.options,
  });

  @override
  State<_ModelOnlyImageQuestionContent> createState() =>
      _ModelOnlyImageQuestionContentState();
}

class _ModelOnlyImageQuestionContentState
    extends State<_ModelOnlyImageQuestionContent> with AudioAnswerMixin {
  int _frameIndex = 0;
  bool _answered = false;
  String? _selectedModel;

  @override
  void initState() {
    super.initState();
    // play page open sound
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}
    // Alterner les frames toutes les 2 secondes
  }

  @override
  void dispose() {
    try { AudioFeedback.instance.playEvent(SoundEvent.pageClose); } catch (_) {}
    // Si CETTE classe a des contrôleurs, dispose-les ici (sinon ne mets rien).
    super.dispose();
  }

  void _onTap(String model) {
    if (_answered) return;

    _audioPlayTap();

    final bool correct = model == widget.correctModel;

    setState(() {
      _answered = true;
      _selectedModel = model;
      if (correct) {
        _streak += 1;
      } else {
        _streak = 0;
      }
    });

    if (correct) {
      _audioPlayAnswerCorrect();
      if (_streak > 0 && _streak % 3 == 0) {
        _audioPlayStreak(milestone: _streak);
      }
    } else {
      _audioPlayAnswerWrong();
    }

    Future.delayed(const Duration(seconds: 1), () {
      _audioPlayPageFlip();
      Navigator.of(context).pop(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // En-tête
          Text(
            "questions.questionNumber".tr(namedArgs: {'number': widget.questionNumber.toString()}) + " " + "questions.score".tr(namedArgs: {'current': widget.currentScore.toString(), 'total': widget.totalQuestions.toString()}),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),
          Text(
            "questions.modelName".tr(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Image animée en boucle via le cache
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(
              image: _assetImageProvider(
                '${widget.fileBase}$_frameIndex.webp',
              ),
              key: ValueKey<int>(_frameIndex),
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(height: 24),

          // Boutons modèles
          for (var m in widget.options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Material(
                    color: _answered
                        ? (m == widget.correctModel
                            ? Colors.green
                            : (m == _selectedModel
                                ? Colors.red
                                : Colors.grey[800]!))
                        : Colors.grey[800],
                    child: InkWell(
                      onTap: () => _onTap(m),
                      child: Center(
                        child: Text(
                          m,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


/// Widget for Question 1 – static 6-frame stack, no rotation
class _RandomCarImageQuestionContent extends StatefulWidget {
  final int questionNumber;
  final int currentScore;
  final int totalQuestions;
  final String fileBase;
  final String correctAnswer;
  final List<String> options;

  const _RandomCarImageQuestionContent({
    required this.questionNumber,
    required this.currentScore,
    required this.totalQuestions,
    required this.fileBase,
    required this.correctAnswer,
    required this.options,
  });

  @override
  State<_RandomCarImageQuestionContent> createState() =>
      _RandomCarImageQuestionContentState();
}

class _RandomCarImageQuestionContentState
    extends State<_RandomCarImageQuestionContent> with AudioAnswerMixin {
  bool _answered = false;
  String? _selectedBrand;

  void _onTap(String brand) {
    if (_answered) return;

    _audioPlayTap();

    final bool correct = brand == widget.correctAnswer;

    setState(() {
      _answered = true;
      _selectedBrand = brand;
      if (correct) {
        _streak += 1;
      } else {
        _streak = 0;
      }
    });

    if (correct) {
      _audioPlayAnswerCorrect();
      if (_streak > 0 && _streak % 3 == 0) {
        _audioPlayStreak(milestone: _streak);
      }
    } else {
      _audioPlayAnswerWrong();
    }

    Future.delayed(const Duration(seconds: 1), () {
      _audioPlayPageFlip();
      Navigator.of(context).pop(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            "questions.questionNumber".tr(namedArgs: {'number': widget.questionNumber.toString()}) + " " + "questions.score".tr(namedArgs: {'current': widget.currentScore.toString(), 'total': widget.totalQuestions.toString()}),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Prompt (changed)
          Text(
            "questions.whichCar".tr(),
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Six static frames stacked vertically
          for (int i = 0; i < 6; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image(
                  image: _assetImageProvider('${widget.fileBase}$i.webp'),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Brand choice buttons
          for (var b in widget.options)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Material(
                    color: _answered
                        ? (b == widget.correctAnswer
                            ? Colors.green
                            : (b == _selectedBrand
                                ? Colors.red
                                : Colors.grey[800]!))
                        : Colors.grey[800],
                    child: InkWell(
                      onTap: () => _onTap(b),
                      child: Center(
                        child: Text(
                          b,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}