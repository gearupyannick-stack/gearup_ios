// lib/pages/model_challenge_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:easy_localization/easy_localization.dart';
import '../../services/audio_feedback.dart';

class ModelChallengePage extends StatefulWidget {
  @override
  _ModelChallengePageState createState() => _ModelChallengePageState();
}

class _ModelChallengePageState extends State<ModelChallengePage> {
  // ── Data ───────────────────────────────────────────────────────────────────
  final List<Map<String, String>> _carData = [];
  List<Map<String, String>> _options = [];

  String? _currentBrand;
  String? _currentModel;
  String  _correctAnswer = '';
  bool    _isImageToModel = true;

  // ── Quiz progress ────────────────────────────────────────────────────────────
  int    _questionCount  = 0;
  int    _correctAnswers = 0;
  int    _elapsedSeconds = 0;
  Timer? _quizTimer;

  // ── Frame animation ──────────────────────────────────────────────────────────
  static const int _maxFrames = 6;
  int    _frameIndex = 0;
  int    _imageToModelFrameIndex = 0;
  Timer? _frameTimer;

  // ── Answer‐highlighting state ────────────────────────────────────────────────
  bool    _answered       = false;
  String? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    _loadCsv();

    // overall quiz timer
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _quizTimer?.cancel();
    _frameTimer?.cancel();
    super.dispose();
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
    _nextQuestion();
  }

  void _nextQuestion() {
    _frameTimer?.cancel();

    if (_questionCount >= 20) {
      return _finishQuiz();
    }
    _questionCount++;
    _isImageToModel   = _questionCount.isOdd;
    _answered         = false;
    _selectedAnswer   = null;

    final rnd = Random();
    final row = _carData[rnd.nextInt(_carData.length)];
    _currentBrand = row['brand'];
    _currentModel = row['model'];

    if (_isImageToModel) {
      _correctAnswer = _currentModel!;
      _imageToModelFrameIndex = 0;
    } else {
      _correctAnswer = '$_currentBrand $_currentModel';
      _frameIndex = 0;
    }

    // build 4 distinct options
    final opts = <Map<String, String>>[
      {'brand': _currentBrand!, 'model': _currentModel!}
    ];
    final used = <String>{'$_currentBrand|$_currentModel'};
    while (opts.length < 4) {
      final r = _carData[rnd.nextInt(_carData.length)];
      final key = '${r['brand']}|${r['model']}';
      if (!used.contains(key)) {
        used.add(key);
        opts.add({'brand': r['brand']!, 'model': r['model']!});
      }
    }
    _options = opts..shuffle();

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
    _quizTimer?.cancel();
    _frameTimer?.cancel();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quiz Completed!'),
        content: Text(
          'You got $_correctAnswers/20 in '
          '${_elapsedSeconds ~/ 60}m ${(_elapsedSeconds % 60).toString().padLeft(2, '0')}s',
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
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Sanitizes a brand+model into your file-base, e.g. "Porsche911".
  String _formatImageName(String brand, String model) {
    final input = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return input
        .split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join();
  }

  /// Displays the i-th static frame for the current model (from assets/model).
  Widget _buildStaticModelImage(int i) {
    final base = _formatImageName(_currentBrand!, _currentModel!);
    final fileName = '$base$i.webp';
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
        key: ValueKey<int>(i),
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
        // Helpful debug fallback when an asset is missing on device (esp. iOS case sensitivity)
        return Container(
          height: 160,
          width: double.infinity,
          color: Colors.grey[900],
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_car, color: Colors.white54, size: 28),
                const SizedBox(height: 6),
                Text(
                  fileName,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  /// Displays the animated/current frame for a given option (from assets/model).
  Widget _buildOptionImage(Map<String, String> opt) {
    final base = _formatImageName(opt['brand']!, opt['model']!);
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
                  fileName,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  void _onTap(String selection) {
    
    try { AudioFeedback.instance.playEvent(SoundEvent.tap); } catch (_) {}
if (_answered) return;
    setState(() {
      _answered = true;
      _selectedAnswer = selection;
      if (selection == _correctAnswer) {
        _correctAnswers++;
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
        title: const Text('Model Challenge'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text('Time: $headerTime | Q: $_questionCount/20',
                  style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
      body: _currentBrand == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Score: $_correctAnswers/20',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // ── IMAGE → MODEL MODE ───────────────────────────────
                  if (_isImageToModel) ...[
                    const Text(
                      'Guess the model from this photo:',
                      style: TextStyle(fontSize: 20),
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
                            'assets/model/${_formatImageName(_currentBrand!, _currentModel!)}$_imageToModelFrameIndex.webp',
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
                    for (var opt in _options)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Material(
                              color: _answered
                                  ? (opt['model'] == _correctAnswer
                                      ? Colors.green
                                      : (opt['model'] == _selectedAnswer
                                          ? Colors.red
                                          : Colors.grey[800]!))
                                  : Colors.grey[800],
                              child: InkWell(
                                onTap: () { try { AudioFeedback.instance.playEvent(SoundEvent.tap); } catch (_) {};
                              _onTap(opt['model']!); },
                                child: Center(
                                  child: Text(
                                    opt['model']!,
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
                  ] else ...[
                    // ── MODEL → IMAGE MODE ───────────────────────────────
                    const SizedBox(height: 16),
                    Text(
                      'Which image matches "${_currentBrand!} ${_currentModel!}"?',
                      style: const TextStyle(fontSize: 20),
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
                      itemCount: _options.length,
                      itemBuilder: (ctx, idx) {
                        final opt = _options[idx];
                        final isCorrect =
                            '${opt['brand']} ${opt['model']}' == _correctAnswer;
                        final isSelected =
                            '${opt['brand']} ${opt['model']}' == _selectedAnswer;
                        return GestureDetector(
                          onTap: () { try { AudioFeedback.instance.playEvent(SoundEvent.tap); } catch (_) {};
                              _onTap('${opt['brand']} ${opt['model']}'); },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: ColorFiltered(
                                key: ValueKey<int>(_frameIndex),
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
                                        Colors.transparent,
                                        BlendMode.srcATop),
                                child: _buildOptionImage(opt),
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
    );
  }
}