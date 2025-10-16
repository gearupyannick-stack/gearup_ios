// lib/pages/challenges/acceleration_challenge_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../services/image_service_cache.dart'; // ← Utilisation du cache local
import '../../services/audio_feedback.dart'; // centralized audio router

class AccelerationChallengePage extends StatefulWidget {
  @override
  _AccelerationChallengePageState createState() =>
      _AccelerationChallengePageState();
}

class _AccelerationChallengePageState extends State<AccelerationChallengePage> {
  // ── Data loaded from CSV: brand, model, acceleration
  final List<Map<String, String>> _carData = [];
  List<String> _options = [];

  // Current quiz item
  String? _currentBrand;
  String? _currentModel;
  String _correctAcceleration = '';

  // Quiz progress
  int _questionCount = 0;
  int _correctAnswers = 0;
  int _elapsedSeconds = 0;
  Timer? _quizTimer;

  // Frame animation for rotating car images
  int _frameIndex = 0;
  Timer? _frameTimer;

  // Answer highlighting
  bool _answered = false;
  String? _selectedAcceleration;

  // simple streak tracker for streak audio
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    // Notify audio layer that page opened
    try {
      AudioFeedback.instance.playEvent(SoundEvent.pageOpen);
    } catch (_) {}

    _loadCsv();

    // Start overall quiz timer
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });

    // Start frame animation timer (advance every 2 seconds)
    _frameTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      setState(() {
        _frameIndex = (_frameIndex + 1) % 6;
      });
    });
  }

  @override
  void dispose() {
    // Notify audio layer that page closed
    try {
      AudioFeedback.instance.playEvent(SoundEvent.pageClose);
    } catch (_) {}

    _quizTimer?.cancel();
    _frameTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCsv() async {
    final raw = await rootBundle.loadString('assets/cars.csv');
    final lines = const LineSplitter().convert(raw);
    for (var line in lines) {
      final parts = line.split(',');
      // ensure we have at least 6 columns: brand,model,...,acceleration
      if (parts.length > 5) {
        _carData.add({
          'brand': parts[0].trim(),
          'model': parts[1].trim(),
          'acceleration': parts[5].trim(),
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
    _selectedAcceleration = null;

    final rnd = Random();
    final row = _carData[rnd.nextInt(_carData.length)];
    _currentBrand = row['brand'];
    _currentModel = row['model'];
    _correctAcceleration = row['acceleration']!;

    // Build four distinct acceleration options
    final opts = <String>{_correctAcceleration};
    while (opts.length < 4) {
      opts.add(_carData[rnd.nextInt(_carData.length)]['acceleration']!);
    }
    setState(() {
      _options = opts.toList()..shuffle();
    });

    // signal a "page flip" / new question event to audio layer
    try {
      AudioFeedback.instance.playEvent(SoundEvent.pageFlip);
    } catch (_) {}
  }

  void _onTap(String accel) {
    if (_answered) return;

    // play tap immediately (non-blocking)
    try {
      AudioFeedback.instance.playEvent(SoundEvent.tap);
    } catch (_) {}

    setState(() {
      _answered = true;
      _selectedAcceleration = accel;
      if (accel == _correctAcceleration) {
        _correctAnswers++;
        _streak += 1;
      } else {
        _streak = 0;
      }
    });

    // Feedback sounds for correct / incorrect
    if (accel == _correctAcceleration) {
      try {
        AudioFeedback.instance.playEvent(SoundEvent.answerCorrect);
        // streak milestone audio
        if (_streak == 3 || _streak == 5 || _streak == 10) {
          AudioFeedback.instance.playEvent(SoundEvent.streak);
        }
      } catch (_) {}
    } else {
      try {
        AudioFeedback.instance.playEvent(SoundEvent.answerWrong);
      } catch (_) {}
    }

    // move to next question after a short delay (preserves existing UX)
    Future.delayed(const Duration(seconds: 1), _nextQuestion);
  }

  void _finishQuiz() {
    _quizTimer?.cancel();
    _frameTimer?.cancel();

    // determine a simple star rating from correctAnswers (tunable)
    final int stars = (_correctAnswers >= 16)
        ? 3
        : (_correctAnswers >= 10)
            ? 2
            : 1;

    // Play challenge-complete fanfare for computed stars
    try {
      AudioFeedback.instance.playEvent(SoundEvent.challengeComplete,
          meta: {'stars': stars});
    } catch (_) {}

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

  /// Convert brand+model into file-base, e.g. "Porsche911"
  String _fileBase(String brand, String model) {
    final combined = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return combined
        .split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
            : '')
        .join();
  }

  /// Displays the current frame image from cache instead of FutureBuilder.
  Widget _buildFrameImage() {
    final base = _fileBase(_currentBrand!, _currentModel!);
    final fileName = '$base$_frameIndex.webp';
    return Image(
      key: ValueKey<int>(_frameIndex),
      image: ImageCacheService.instance.imageProvider(fileName),
      height: 200,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceleration Challenge'),
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'What is the acceleration (0–100 km/h) of\n'
                    '${_currentBrand!} ${_currentModel!}?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: _buildFrameImage(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (var accel in _options)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: SizedBox(
                        height: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Material(
                            color: _answered
                                ? (accel == _correctAcceleration
                                    ? Colors.green
                                    : (accel == _selectedAcceleration
                                        ? Colors.red
                                        : Colors.grey[800]!))
                                : Colors.grey[800],
                            child: InkWell(
                              onTap: _answered ? null : () => _onTap(accel),
                              child: Center(
                                child: Text(
                                  accel,
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
            ),
    );
  }
}