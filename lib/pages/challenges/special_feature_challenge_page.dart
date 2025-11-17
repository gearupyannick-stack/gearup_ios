// lib/pages/challenges/special_feature_challenge_page.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:easy_localization/easy_localization.dart';
import 'package:csv/csv.dart';
import '../../services/audio_feedback.dart'; // added by audio patch
import '../../services/language_service.dart';
import '../../widgets/enhanced_answer_button.dart';
import '../../widgets/question_progress_bar.dart';
import '../../widgets/animated_score_display.dart';

class SpecialFeatureChallengePage extends StatefulWidget {
  @override
  _SpecialFeatureChallengePageState createState() =>
      _SpecialFeatureChallengePageState();
}

class _SpecialFeatureChallengePageState
    extends State<SpecialFeatureChallengePage> {
  // ── CSV data: brand, model, notableFeature
  final List<Map<String, String>> _carData = [];
  List<String> _options = [];

  // Current question
  String? _currentBrand;
  String? _currentModel;
  String _correctFeature = '';

  // Quiz progress
  int _questionCount = 0;
  int _correctAnswers = 0;
  int _elapsedSeconds = 0;
  Timer? _quizTimer;

  // Frame animation index & timer
  int _frameIndex = 0;
  Timer? _frameTimer;
  static const int _maxFrames = 6;

  // Answer highlighting
  bool _answered = false;
  String? _selectedFeature;

  // Answer history for progress bar
  List<bool> _answerHistory = [];

  // Streak tracking for animated score display
  int _currentStreak = 0;
  bool _showScoreChange = false;
  bool _wasLastAnswerCorrect = false;

  @override
  void initState() {
    super.initState();
    
    // audio: page open
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}
_loadCsv();

    // overall quiz timer (seconds)
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });

    _startFrameTimer();
  }

  void _startFrameTimer() {
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_answered) {
        setState(() {
          _frameIndex = (_frameIndex + 1) % _maxFrames;
        });
      }
    });
  }

  void _goToNextFrame() {
    if (_answered) return;
    setState(() {
      _frameIndex = (_frameIndex + 1) % _maxFrames;
    });
    _startFrameTimer();
  }

  void _goToPreviousFrame() {
    if (_answered) return;
    setState(() {
      _frameIndex = (_frameIndex - 1 + _maxFrames) % _maxFrames;
    });
    _startFrameTimer();
  }

  @override
  void dispose() {
    _quizTimer?.cancel();
    _frameTimer?.cancel();
        // audio: page close
    try { AudioFeedback.instance.playEvent(SoundEvent.pageClose); } catch (_) {}

super.dispose();
  }

  Future<void> _loadCsv() async {
    final raw = await rootBundle.loadString('assets/cars.csv');
    final List<List<dynamic>> rows = const CsvToListConverter(eol: '\n').convert(raw);
    final featureIndex = LanguageService.getSpecialFeatureIndex(context);

    for (var values in rows) {
      if (values.length > featureIndex) {
        _carData.add({
          'brand': values[0].toString().trim(),
          'model': values[1].toString().trim(),
          'feature': values[featureIndex].toString().trim(),
        });
      }
    }
    _nextQuestion();
  }

  void _nextQuestion() {
    if (_questionCount >= 20) {
      _finishQuiz();
      return;
    }
    _questionCount++;
    _answered = false;
    _selectedFeature = null;

    final rnd = Random();
    final row = _carData[rnd.nextInt(_carData.length)];
    _currentBrand = row['brand'];
    _currentModel = row['model'];
    _correctFeature = row['feature']!;

    // Build 4 distinct feature options with uniqueness check
    final used = <String>{_correctFeature};
    final opts = [_correctFeature];
    while (opts.length < 4) {
      final candidate = _carData[rnd.nextInt(_carData.length)]['feature']!;
      if (!used.contains(candidate)) {
        used.add(candidate);
        opts.add(candidate);
      }
    }
    setState(() {
      _options = opts..shuffle();
    });
  }

  void _onTap(String feature) {
    if (_answered) return;
    final isCorrect = feature == _correctFeature;

    // Play appropriate answer feedback sound
    try {
      AudioFeedback.instance.playEvent(
        isCorrect ? SoundEvent.answerCorrect : SoundEvent.answerWrong
      );
    } catch (_) {}

    setState(() {
      _answered = true;
      _selectedFeature = feature;
      if (isCorrect) {
        _correctAnswers++;
        _currentStreak++;
      } else {
        _currentStreak = 0;
      }
      _answerHistory.add(isCorrect);
      _wasLastAnswerCorrect = isCorrect;
      _showScoreChange = true;
    });

    // Reset the animation flag after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _showScoreChange = false;
        });
      }
    });

    Future.delayed(const Duration(seconds: 1), _nextQuestion);
  }

  void _finishQuiz() {
    _quizTimer?.cancel();
    _frameTimer?.cancel();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('challenges.quizCompleted')),
        content: Text(
          tr('challenges.resultMessage', namedArgs: {
            'score': '$_correctAnswers',
            'total': '20',
            'time': '${_elapsedSeconds ~/ 60}m ${(_elapsedSeconds % 60).toString().padLeft(2, '0')}s'
          }),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(
                context,
                '$_correctAnswers/20 in ${_elapsedSeconds ~/ 60}\'${(_elapsedSeconds % 60).toString().padLeft(2, '0')}\'\'',
              );
            },
            child: Text(tr('common.ok')),
          ),
        ],
      ),
    );
  }

  /// Convert brand+model into file-base, e.g. "Porsche911"
  String _fileBase(String brand, String model) {
    final combined = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return combined
        .split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join();
  }

  /// Displays the current frame image directly from assets/model (no service).
  Widget _buildFrameImage() {
    // build filename exactly like your assets: e.g. "Porsche9110.webp"
    final base = _fileBase(_currentBrand!, _currentModel!);
    final fileName = '$base$_frameIndex.webp';
    final assetPath = 'assets/model/$fileName';

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        1.3, 0, 0, 0, 0,
        0, 1.3, 0, 0, 0,
        0, 0, 1.3, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: Image.asset(
        assetPath,
        key: ValueKey<int>(_frameIndex),
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // fallback UI when an asset is missing (helps debugging on iOS)
          return Container(
            height: 220,
            width: double.infinity,
            color: Colors.grey[900],
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_car, color: Colors.white54, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'Missing: $fileName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('challenges.specialFeatureChallenge')),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Time: $minutes:$seconds | Q: $_questionCount/20',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: _currentBrand == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                QuestionProgressBar(
                  currentQuestion: _questionCount,
                  totalQuestions: 20,
                  answeredCorrectly: _answerHistory,
                ),
                Expanded(
                  child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedScoreDisplay(
                    currentScore: _correctAnswers,
                    totalQuestions: 20,
                    currentStreak: _currentStreak,
                    showScoreChange: _showScoreChange,
                    wasCorrect: _wasLastAnswerCorrect,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'What notable feature does\n'
                    '${_currentBrand!} ${_currentModel!} have?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: _buildFrameImage(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 20),
                        onPressed: _answered ? null : _goToPreviousFrame,
                        color: Colors.white70,
                      ),
                      Text(
                        '${_frameIndex + 1}/$_maxFrames',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 20),
                        onPressed: _answered ? null : _goToNextFrame,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _maxFrames,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _frameIndex == index
                              ? Colors.red
                              : Colors.grey.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---- Updated option buttons ----
                  for (var feature in _options)
                    EnhancedAnswerButton(
                      text: feature,
                      backgroundColor: _answered
                          ? (feature == _correctFeature
                              ? Colors.green
                              : (feature == _selectedFeature
                                  ? Colors.red
                                  : Colors.grey[800]!))
                          : Colors.grey[800]!,
                      onTap: () => _onTap(feature),
                      isDisabled: _answered,
                    ),
                ],
              ),
            ),
                ),
              ],
            ),
    );
  }
}