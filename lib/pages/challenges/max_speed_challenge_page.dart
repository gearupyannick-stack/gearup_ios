// lib/pages/challenges/max_speed_challenge_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../services/audio_feedback.dart'; // added by audio patch

class MaxSpeedChallengePage extends StatefulWidget {
  @override
  _MaxSpeedChallengePageState createState() => _MaxSpeedChallengePageState();
}

class _MaxSpeedChallengePageState extends State<MaxSpeedChallengePage> {
  // Raw CSV data: brand, model, topSpeed
  final List<Map<String, String>> _carData = [];
  // Multiple-choice options
  List<String> _options = [];

  // Current question state
  String? _currentBrand;
  String? _currentModel;
  String _correctSpeed = '';

  // Quiz progress
  int _questionCount = 0;
  int _correctAnswers = 0;
  int _elapsedSeconds = 0;
  Timer? _quizTimer;

  // Frame animation index and timer
  int _frameIndex = 0;
  Timer? _frameTimer;

  // Answer highlighting
  bool _answered = false;
  String? _selectedSpeed;

  @override
  void initState() {
    super.initState();
    
    // audio: page open
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}
_loadCsv();

    // Start overall quiz timer
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
    // Start frame animation timer (2s per frame)
    _frameTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      setState(() {
        _frameIndex = (_frameIndex + 1) % 6;
      });
    });
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
    final lines = const LineSplitter().convert(raw);
    for (var line in lines) {
      final parts = line.split(',');
      if (parts.length >= 5) {
        _carData.add({
          'brand': parts[0].trim(),
          'model': parts[1].trim(),
          'topSpeed': parts[4].trim(),
        });
      }
    }
    _nextQuestion();
  }

  void _nextQuestion() {
    if (_questionCount >= 20) return _finishQuiz();
    _questionCount++;
    _answered = false;
    _selectedSpeed = null;

    final rnd = Random();
    final row = _carData[rnd.nextInt(_carData.length)];
    _currentBrand = row['brand'];
    _currentModel = row['model'];
    _correctSpeed = row['topSpeed']!;

    // Pick 4 distinct speeds
    final opts = <String>{_correctSpeed};
    while (opts.length < 4) {
      opts.add(_carData[rnd.nextInt(_carData.length)]['topSpeed']!);
    }
    setState(() {
      _options = opts.toList()..shuffle();
    });
  }

  void _onTap(String speed) {
    
    try { AudioFeedback.instance.playEvent(SoundEvent.tap); } catch (_) {}
if (_answered) return;
    setState(() {
      _answered = true;
      _selectedSpeed = speed;
      if (speed == _correctSpeed) _correctAnswers++;
    });
    
    // audio: answer feedback
    try {
      if (_selectedSpeed == _correctSpeed) { AudioFeedback.instance.playEvent(SoundEvent.answerCorrect); } else { AudioFeedback.instance.playEvent(SoundEvent.answerWrong); }
      try { if (true) { /* streak logic handled centrally if needed */ } } catch (_) {}
    } catch (_) {}
Future.delayed(const Duration(seconds: 1), _nextQuestion);
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

  String _fileBase(String brand, String model) {
    final combined = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return combined
        .split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
            : '')
        .join();
  }

  /// Displays the current frame image directly from assets/model (no service).
  Widget _buildFrameImage() {
    // build filename exactly like your assets: e.g. "Porsche9110.webp"
    final base = _fileBase(_currentBrand!, _currentModel!);
    final fileName = '$base$_frameIndex.webp';
    final assetPath = 'assets/model/$fileName';

    return Image.asset(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Max Speed Challenge'),
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
                    'What is the top speed of\n${_currentBrand!} ${_currentModel!}?',
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
                  for (var speed in _options)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: SizedBox(
                        height: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Material(
                            color: _answered
                                ? (speed == _correctSpeed
                                    ? Colors.green
                                    : (speed == _selectedSpeed
                                        ? Colors.red
                                        : Colors.grey[800]!))
                                : Colors.grey[800],
                            child: InkWell(
                              onTap: _answered ? null : () => _onTap(speed),
                              child: Center(
                                child: Text(
                                  speed,
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