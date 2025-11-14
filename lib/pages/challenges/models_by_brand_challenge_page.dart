// lib/pages/challenges/models_by_brand_challenge_page.dart

import 'dart:async';
import 'dart:convert';               // for LineSplitter
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:easy_localization/easy_localization.dart';
import '../../services/audio_feedback.dart';
import '../../widgets/enhanced_answer_button.dart';
import '../../widgets/question_progress_bar.dart';
import '../../widgets/animated_score_display.dart';

class ModelsByBrandChallengePage extends StatefulWidget {
  @override
  _ModelsByBrandChallengePageState createState() =>
      _ModelsByBrandChallengePageState();
}

class _ModelsByBrandChallengePageState
    extends State<ModelsByBrandChallengePage> {
  final List<Map<String, String>> _carData = [];
  late List<String> _brands;
  String? _selectedBrand;

  @override
  void initState() {
    super.initState();
    _brands = [];
    _loadCsv();
  }

  Future<void> _loadCsv() async {
    final raw = await rootBundle.loadString('assets/cars.csv');
    final lines = const LineSplitter().convert(raw);
    for (var line in lines) {
      final parts = line.split(',');
      if (parts.length >= 2) {
        _carData.add({'brand': parts[0].trim(), 'model': parts[1].trim()});
      }
    }
    // Build per-brand model sets (deduped), then keep only brands with ≥ 4 models
    final Map<String, Set<String>> byBrand = {};
    for (final row in _carData) {
      final b = row['brand']!;
      final m = row['model']!;
      byBrand.putIfAbsent(b, () => <String>{}).add(m);
    }

    _brands = byBrand.entries
        .where((e) => e.value.length >= 4) // ← only brands with 4+ models
        .map((e) => e.key)
        .toList()
      ..sort();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_brands.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Models by Brand')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Brand selection grid
    if (_selectedBrand == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Models by Brand')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            itemCount: _brands.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (_, i) {
              final brand = _brands[i];
              final models = _carData
                  .where((row) => row['brand'] == brand)
                  .map((row) => row['model']!)
                  .toList();
              return _BrandTile(
                brand: brand,
                models: models,
                onTap: () => setState(() => _selectedBrand = brand),
              );
            },
          ),
        ),
      );
    }

    // Quiz screen
    final models = _carData
        .where((row) => row['brand'] == _selectedBrand)
        .map((row) => row['model']!)
        .toList();

    return BrandModelQuizPage(
      brand: _selectedBrand!,
      models: models,
      onDone: () => setState(() => _selectedBrand = null),
    );
  }
}

class _BrandTile extends StatefulWidget {
  final String brand;
  final List<String> models;
  final VoidCallback onTap;

  const _BrandTile({
    required this.brand,
    required this.models,
    required this.onTap,
  });

  @override
  __BrandTileState createState() => __BrandTileState();
}

class __BrandTileState extends State<_BrandTile> {
  late final String _fileBase;

  @override
  void initState() {
    super.initState();
    // Pick a random model once for the tile
    final rnd = Random();
    final model = widget.models[rnd.nextInt(widget.models.length)];
    _fileBase = _formatImageName(widget.brand, model);
  }

  String _formatImageName(String brand, String model) {
    final input = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return input
        .split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Load a representative model image directly from assets/model/
            Image.asset(
              'assets/model/${_fileBase}4.webp',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback shows a dark tile with the brand name (useful when file missing)
                return Container(
                  color: Colors.grey[900],
                  child: Center(
                    child: Text(
                      widget.brand,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(blurRadius: 4, offset: Offset(1, 1), color: Colors.black),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),

            // Brand label overlay
            Center(
              child: Text(
                widget.brand,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(blurRadius: 4, offset: Offset(1, 1), color: Colors.black),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BrandModelQuizPage extends StatefulWidget {
  final String brand;
  final List<String> models;
  final VoidCallback onDone;

  const BrandModelQuizPage({
    required this.brand,
    required this.models,
    required this.onDone,
  });

  @override
  _BrandModelQuizPageState createState() => _BrandModelQuizPageState();
}

class _BrandModelQuizPageState extends State<BrandModelQuizPage> {
  static const int _maxQuestions = 20;
  static const int _maxFrames = 6;

  late List<String> _allModels;
  late List<String> _options;
  bool _isImageToModel = true;
  bool _answered = false;
  String _correctAnswer = '';
  String? _selectedModel;
  int _questionCount = 0;
  int _correctAnswers = 0;
  int _elapsedSeconds = 0;
  int _frameIndex = 0;
  int _imageToModelFrameIndex = 0;
  late Timer _quizTimer;
  Timer? _frameTimer;
  List<bool> _answerHistory = [];

  // Streak tracking for animated score display
  int _currentStreak = 0;
  bool _showScoreChange = false;
  bool _wasLastAnswerCorrect = false;

  @override
  void initState() {
    super.initState();
    _allModels = List.from(widget.models);

    // overall quiz timer
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });

    _nextQuestion();
  }

  @override
  void dispose() {
    _quizTimer.cancel();
    _frameTimer?.cancel();
    super.dispose();
  }

  void _nextQuestion() {
    _frameTimer?.cancel();

    if (_questionCount >= _maxQuestions) {
      return _finishQuiz();
    }
    _questionCount++;
    _isImageToModel = _questionCount.isOdd;
    _answered = false;
    _selectedModel = null;

    final rnd = Random();
    _correctAnswer = _allModels[rnd.nextInt(_allModels.length)];

    if (_isImageToModel) {
      _imageToModelFrameIndex = 0;
    } else {
      _frameIndex = 0;
    }

    // Build 4 distinct options
    final used = <String>{_correctAnswer};
    _options = [_correctAnswer];
    while (_options.length < 4) {
      final m = _allModels[rnd.nextInt(_allModels.length)];
      if (!used.contains(m)) {
        used.add(m);
        _options.add(m);
      }
    }
    _options.shuffle();

    _startFrameTimer();
    setState(() {});
  }

  void _startFrameTimer() {
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_answered) {
        setState(() {
          if (_isImageToModel) {
            _imageToModelFrameIndex = (_imageToModelFrameIndex + 1) % _maxFrames;
          } else {
            _frameIndex = (_frameIndex + 1) % _maxFrames;
          }
        });
      }
    });
  }

  void _goToNextFrame() {
    if (_answered) return;
    setState(() {
      if (_isImageToModel) {
        _imageToModelFrameIndex = (_imageToModelFrameIndex + 1) % _maxFrames;
      } else {
        _frameIndex = (_frameIndex + 1) % _maxFrames;
      }
    });
    _startFrameTimer();
  }

  void _goToPreviousFrame() {
    if (_answered) return;
    setState(() {
      if (_isImageToModel) {
        _imageToModelFrameIndex = (_imageToModelFrameIndex - 1 + _maxFrames) % _maxFrames;
      } else {
        _frameIndex = (_frameIndex - 1 + _maxFrames) % _maxFrames;
      }
    });
    _startFrameTimer();
  }

  void _finishQuiz() {
    _quizTimer.cancel();
    _frameTimer?.cancel();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('challenges.quizCompleted')),
        content: Text(
          tr('challenges.resultMessage', namedArgs: {
            'score': '$_correctAnswers',
            'total': '$_maxQuestions',
            'time': '${_elapsedSeconds ~/ 60}m ${(_elapsedSeconds % 60).toString().padLeft(2, '0')}s'
          }),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(
                context,
                '$_correctAnswers/$_maxQuestions in ${_elapsedSeconds ~/ 60}\'${(_elapsedSeconds % 60).toString().padLeft(2, '0')}\'\'',
              );
            },
            child: Text(tr('common.ok')),
          ),
        ],
      ),
    );
  }

  String _formatImageName(String brand, String model) {
    final input = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return input
        .split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join();
  }


  void _onOptionTap(String selection) {

    try { AudioFeedback.instance.playEvent(SoundEvent.tap); } catch (_) {}
if (_answered) return;
    final isCorrect = selection == _correctAnswer;
    setState(() {
      _answered = true;
      _selectedModel = selection;
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

  @override
  Widget build(BuildContext context) {
    final headerTime =
        '${_elapsedSeconds ~/ 60}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('challenges.modelsByBrandChallenge')),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                'Time: $headerTime | Q: $_questionCount/$_maxQuestions',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          QuestionProgressBar(
            currentQuestion: _questionCount,
            totalQuestions: _maxQuestions,
            answeredCorrectly: _answerHistory,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
          children: [
            AnimatedScoreDisplay(
              currentScore: _correctAnswers,
              totalQuestions: _maxQuestions,
              currentStreak: _currentStreak,
              showScoreChange: _showScoreChange,
              wasCorrect: _wasLastAnswerCorrect,
            ),
            const SizedBox(height: 16),

            if (_isImageToModel) ...[
              Text(
                tr("challenges.whichModelOfBrand"),
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                      key: ValueKey<int>(_imageToModelFrameIndex),
                      'assets/model/${_formatImageName(widget.brand, _correctAnswer)}$_imageToModelFrameIndex.webp',
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
                    '${_imageToModelFrameIndex + 1}/$_maxFrames',
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
                      color: _imageToModelFrameIndex == index
                          ? Colors.red
                          : Colors.grey.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              for (var m in _options)
                EnhancedAnswerButton(
                  text: m,
                  backgroundColor: _answered
                      ? (m == _correctAnswer
                          ? Colors.green
                          : (m == _selectedModel
                              ? Colors.red
                              : Colors.grey[800]!))
                      : Colors.grey[800]!,
                  onTap: () => _onOptionTap(m),
                  isDisabled: _answered,
                ),
            ] else ...[
              const SizedBox(height: 16),
              // ask for a specific model now
              Text(
                'Tap the image of a $_correctAnswer:',
                style: const TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _options.length,
                itemBuilder: (ctx, idx) {
                  final model = _options[idx];
                  final fileBase = _formatImageName(widget.brand, model);
                  final isCorrect = model == _correctAnswer;
                  final isSelected = model == _selectedModel;

                  return GestureDetector(
                    onTap: () { try { AudioFeedback.instance.playEvent(SoundEvent.tap); } catch (_) {};
                              _onOptionTap(model); },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[900],
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: ColorFiltered(
                            key: ValueKey<String>('$fileBase$_frameIndex'),
                            colorFilter: _answered
                                ? (isCorrect
                                    ? ColorFilter.mode(
                                        Colors.green.withAlpha(128),
                                        BlendMode.srcATop)
                                    : (isSelected
                                        ? ColorFilter.mode(
                                            Colors.red.withAlpha(128),
                                            BlendMode.srcATop)
                                        : ColorFilter.mode(
                                            Colors.transparent,
                                            BlendMode.srcATop)))
                                : const ColorFilter.mode(
                                    Colors.transparent, BlendMode.srcATop),
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.matrix(<double>[
                                1.3, 0, 0, 0, 0,
                                0, 1.3, 0, 0, 0,
                                0, 0, 1.3, 0, 0,
                                0, 0, 0, 1, 0,
                              ]),
                              child: Image.asset(
                                'assets/model/$fileBase$_frameIndex.webp',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[900],
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.directions_car, color: Colors.white54, size: 28),
                                        const SizedBox(height: 6),
                                        Text(
                                          '$fileBase$_frameIndex.webp',
                                          style: const TextStyle(color: Colors.white54, fontSize: 11),
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
            ],
          ],
        ),
              ),
                ),
        ],
      ),
    );
  }
}
