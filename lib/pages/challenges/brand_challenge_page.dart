// lib/pages/brand_challenge_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:easy_localization/easy_localization.dart';
import '../../services/audio_feedback.dart';
import '../../widgets/enhanced_answer_button.dart';
import '../../widgets/question_progress_bar.dart';
import '../../widgets/animated_score_display.dart';
import '../../widgets/challenge_completion_dialog.dart';
class BrandChallengePage extends StatefulWidget {
  @override
  _BrandChallengePageState createState() => _BrandChallengePageState();
}

class _BrandChallengePageState extends State<BrandChallengePage> {
  // ── Data ────────────────────────────────────────────────────────────────────
  final List<Map<String, String>> carData = [];
  final Map<String, List<String>> brandToModels = {};
  List<String> brandNames = [];
  List<Map<String, String>> modelOptions = [];

  // ── Quiz state ──────────────────────────────────────────────────────────────
  int questionCount = 0;
  int correctAnswers = 0;
  int elapsedSeconds = 0;
  Timer? _questionTimer;

  bool isBrandQuestion = true;
  String? randomBrand;
  String? randomModel;
  List<String> brandOptions = [];

  // ── For image cycling ───────────────────────────────────────────────────────
  Timer? _frameTimer;
  List<int> _currentImageIndices = [];
  int _brandQuestionImageIndex = 0;

  // ── Answer‐highlighting ─────────────────────────────────────────────────────
  bool _answered = false;
  String? _selectedBrand;
  String? _selectedModel;

  // ── Answer history for progress bar ─────────────────────────────────────────
  List<bool> _answerHistory = [];

  // ── Streak tracking for animated score display ──────────────────────────────
  int _currentStreak = 0;
  bool _showScoreChange = false;
  bool _wasLastAnswerCorrect = false;

  static const int _maxFrames = 6;

  @override
  void initState() {
    super.initState();
    _loadCsv();

    // Overall quiz timer (counts seconds)
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _frameTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCsv() async {
    final rawCsv = await rootBundle.loadString('assets/cars.csv');
    final lines = const LineSplitter().convert(rawCsv);
    for (var line in lines) {
      final parts = line.split(',');
      if (parts.length >= 2) {
        final brand = parts[0].trim();
        final model = parts[1].trim();
        carData.add({'brand': brand, 'model': model});
        brandToModels.putIfAbsent(brand, () => []).add(model);
      }
    }
    brandNames = brandToModels.keys.toList();
    _nextQuestion();
  }

  void _nextQuestion() {
    _frameTimer?.cancel();

    if (questionCount >= 20) {
      return _finishQuiz();
    }
    questionCount++;
    isBrandQuestion = questionCount.isOdd;
    _answered = false;
    _selectedBrand = null;
    _selectedModel = null;

    final rnd = Random();
    randomBrand = brandNames[rnd.nextInt(brandNames.length)];
    final models = brandToModels[randomBrand]!;
    randomModel = models[rnd.nextInt(models.length)];

    if (isBrandQuestion) {
      // Pick 4 distinct brands for text buttons
      final opts = <String>{randomBrand!};
      while (opts.length < 4) {
        opts.add(brandNames[rnd.nextInt(brandNames.length)]);
      }
      brandOptions = opts.toList()..shuffle();
      _brandQuestionImageIndex = 0;
    } else {
      // Pick 4 distinct model entries for image grid
      final opts = <Map<String, String>>[
        {'brand': randomBrand!, 'model': randomModel!}
      ];
      while (opts.length < 4) {
        final row = carData[rnd.nextInt(carData.length)];
        if (row['brand'] != randomBrand &&
            !opts.any((m) => m['model'] == row['model'])) {
          opts.add({'brand': row['brand']!, 'model': row['model']!});
        }
      }
      modelOptions = opts..shuffle();
      _currentImageIndices = List<int>.filled(modelOptions.length, 0);
    }

    _startFrameTimer();
    setState(() {});
  }

  void _startFrameTimer() {
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_answered) {
        setState(() {
          if (isBrandQuestion) {
            _brandQuestionImageIndex = (_brandQuestionImageIndex + 1) % _maxFrames;
          } else {
            for (var i = 0; i < _currentImageIndices.length; i++) {
              _currentImageIndices[i] = (_currentImageIndices[i] + 1) % _maxFrames;
            }
          }
        });
      }
    });
  }

  void _goToNextFrame() {
    if (_answered) return;
    setState(() {
      if (isBrandQuestion) {
        _brandQuestionImageIndex = (_brandQuestionImageIndex + 1) % _maxFrames;
      } else {
        for (var i = 0; i < _currentImageIndices.length; i++) {
          _currentImageIndices[i] = (_currentImageIndices[i] + 1) % _maxFrames;
        }
      }
    });
    _startFrameTimer();
  }

  void _goToPreviousFrame() {
    if (_answered) return;
    setState(() {
      if (isBrandQuestion) {
        _brandQuestionImageIndex = (_brandQuestionImageIndex - 1 + _maxFrames) % _maxFrames;
      } else {
        for (var i = 0; i < _currentImageIndices.length; i++) {
          _currentImageIndices[i] = (_currentImageIndices[i] - 1 + _maxFrames) % _maxFrames;
        }
      }
    });
    _startFrameTimer();
  }

  void _finishQuiz() {
    _questionTimer?.cancel();
    _frameTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ChallengeCompletionDialog(
        correctAnswers: correctAnswers,
        totalQuestions: 20,
        totalSeconds: elapsedSeconds,
        onClose: () {
          Navigator.pop(ctx);
          Navigator.pop(
            context,
            '$correctAnswers/20 in '
            '${elapsedSeconds ~/ 60}\''
            '${(elapsedSeconds % 60).toString().padLeft(2, '0')}\'',
          );
        },
      ),
    );
  }

  /// Sanitizes "BrandModel" into the file-base used en cache/Firebase.
  String _fileBase(String brand, String model) {
    final raw = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return raw
        .split(
          RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'),
        )
        .map(
          (w) =>
              w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '',
        )
        .join();
  }


  @override
  Widget build(BuildContext context) {
    final headerTime =
        '${elapsedSeconds ~/ 60}:${(elapsedSeconds % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text('challenges.brandChallenge'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Time: $headerTime | Q: $questionCount/20',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: randomBrand == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                QuestionProgressBar(
                  currentQuestion: questionCount,
                  totalQuestions: 20,
                  answeredCorrectly: _answerHistory,
                ),
                Expanded(
                  child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  AnimatedScoreDisplay(
                    currentScore: correctAnswers,
                    totalQuestions: 20,
                    currentStreak: _currentStreak,
                    showScoreChange: _showScoreChange,
                    wasCorrect: _wasLastAnswerCorrect,
                  ),
                  const SizedBox(height: 16),

                  // ── TEXT-BUTTON MODE ─────────────────────────────────────────
                  if (isBrandQuestion) ...[
                    Text(
                      'challenges.guessTheBrand'.tr(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            1.3, 0, 0, 0, 0,
                            0, 1.3, 0, 0, 0,
                            0, 0, 1.3, 0, 0,
                            0, 0, 0, 1, 0,
                          ]),
                          child: Image.asset(
                            key: ValueKey<int>(_brandQuestionImageIndex),
                            'assets/model/${_fileBase(randomBrand!, randomModel!)}$_brandQuestionImageIndex.webp',
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                width: double.infinity,
                                color: Colors.grey[900],
                                child: const Center(
                                  child: Icon(Icons.directions_car,
                                      color: Colors.white54, size: 36),
                                ),
                              );
                            },
                          ),
                        ),
                        ),
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
                          '${_brandQuestionImageIndex + 1}/$_maxFrames',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
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
                            color: _brandQuestionImageIndex == index
                                ? Colors.red
                                : Colors.grey.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    for (var b in brandOptions)
                      EnhancedAnswerButton(
                        text: b,
                        backgroundColor: _answered
                            ? (b == randomBrand
                                ? Colors.green
                                : (b == _selectedBrand
                                    ? Colors.red
                                    : Colors.grey[800]!))
                            : Colors.grey[800]!,
                        onTap: () => _onBrandTap(b),
                        isDisabled: _answered,
                      ),
                  ] else ...[
                    // ── IMAGE-GRID MODE ────────────────────────────────────────
                    const SizedBox(height: 16),
                    Text(
                      'questions.brandImage'.tr(namedArgs: {'brand': randomBrand ?? ''}),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: modelOptions.length,
                      itemBuilder: (ctx, idx) {
                        final m = modelOptions[idx];
                        final fb = _fileBase(m['brand']!, m['model']!);
                        final isCorrect = m['model'] == randomModel;
                        final isSelected = m['model'] == _selectedModel;
                        final imgIdx = _currentImageIndices[idx];
                        final assetPath = 'assets/model/$fb$imgIdx.webp';

                        return AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _answered
                                    ? (isCorrect
                                        ? Colors.green
                                        : (isSelected
                                            ? Colors.red
                                            : Colors.white.withOpacity(0.2)))
                                    : Colors.white.withOpacity(0.3),
                                width: _answered && (isCorrect || isSelected) ? 4 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _answered
                                      ? (isCorrect
                                          ? Colors.green.withOpacity(0.5)
                                          : (isSelected
                                              ? Colors.red.withOpacity(0.5)
                                              : Colors.black.withOpacity(0.3)))
                                      : Colors.black.withOpacity(0.5),
                                  blurRadius: _answered && (isCorrect || isSelected) ? 16 : 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Material(
                                elevation: 0,
                                borderRadius: BorderRadius.circular(14),
                                color: Colors.grey[900],
                                child: InkWell(
                                  onTap: () => _onModelTap(m['model']!),
                                  splashColor: Colors.white.withOpacity(0.2),
                                  highlightColor: Colors.white.withOpacity(0.1),
                                  child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                transitionBuilder: (child, animation) => FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                                child: ColorFiltered(
                                  key: ValueKey<int>(imgIdx),
                                  colorFilter: _answered
                                      ? (isCorrect
                                          ? ColorFilter.mode(
                                              Colors.green.withAlpha(128), BlendMode.srcATop)
                                          : (isSelected
                                              ? ColorFilter.mode(
                                                  Colors.red.withAlpha(128), BlendMode.srcATop)
                                              : ColorFilter.mode(
                                                  Colors.transparent, BlendMode.srcATop)))
                                      : const ColorFilter.mode(Colors.transparent, BlendMode.srcATop),
                                  child: ColorFiltered(
                                    colorFilter: const ColorFilter.matrix(<double>[
                                      1.3, 0, 0, 0, 0,
                                      0, 1.3, 0, 0, 0,
                                      0, 0, 1.3, 0, 0,
                                      0, 0, 0, 1, 0,
                                    ]),
                                    child: Image.asset(
                                      assetPath,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[900],
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.directions_car,
                                                    color: Colors.white54, size: 28),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '$fb$imgIdx.webp',
                                                  style:
                                                      const TextStyle(color: Colors.white54, fontSize: 11),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                      },
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
                          '${(_currentImageIndices.isNotEmpty ? _currentImageIndices[0] : 0) + 1}/$_maxFrames',
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
                            color: (_currentImageIndices.isNotEmpty && _currentImageIndices[0] == index)
                                ? Colors.red
                                : Colors.grey.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
                ),
              ],
            ),
    );
  }

  void _onBrandTap(String brand) {
    if (_answered) return;
    final isCorrect = brand == randomBrand;

    // Play appropriate answer feedback sound
    try {
      AudioFeedback.instance.playEvent(
        isCorrect ? SoundEvent.answerCorrect : SoundEvent.answerWrong
      );
    } catch (_) {}

    setState(() {
      _selectedBrand = brand;
      _answered = true;
      if (isCorrect) {
        correctAnswers++;
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

  void _onModelTap(String model) {
    if (_answered) return;
    final isCorrect = model == randomModel;

    // Play appropriate answer feedback sound
    try {
      AudioFeedback.instance.playEvent(
        isCorrect ? SoundEvent.answerCorrect : SoundEvent.answerWrong
      );
    } catch (_) {}

    setState(() {
      _selectedModel = model;
      _answered = true;
      if (isCorrect) {
        correctAnswers++;
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
}
