// lib/pages/challenges/power_challenge_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../services/audio_feedback.dart'; // added by audio patch

import '../../services/image_service_cache.dart'; // ← Utilisation du cache local

class PowerChallengePage extends StatefulWidget {
  @override
  _PowerChallengePageState createState() => _PowerChallengePageState();
}

class _PowerChallengePageState extends State<PowerChallengePage> {
  // ── CSV data: brand, model, horsepower
  final List<Map<String, String>> _carData = [];
  List<String> _options = [];

  // Current question
  String? _currentBrand;
  String? _currentModel;
  String _correctPower = '';

  // Quiz progress
  int _questionCount = 0;
  int _correctAnswers = 0;
  int _elapsedSeconds = 0;
  Timer? _quizTimer;

  // Frame animation index & timer
  int _frameIndex = 0;
  Timer? _frameTimer;

  // Answer highlighting
  bool _answered = false;
  String? _selectedPower;

  @override
  void initState() {
    super.initState();
    
    // audio: page open
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}
_loadCsv();

    // overall timer
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });

    // frame timer (every 2s)
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
      if (parts.length > 6) {
        _carData.add({
          'brand': parts[0].trim(),
          'model': parts[1].trim(),
          'power': parts[6].trim(),
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
    _selectedPower = null;

    final rnd = Random();
    final row = _carData[rnd.nextInt(_carData.length)];
    _currentBrand = row['brand'];
    _currentModel = row['model'];
    _correctPower = row['power']!;

    // build four distinct options
    final opts = <String>{_correctPower};
    while (opts.length < 4) {
      opts.add(_carData[rnd.nextInt(_carData.length)]['power']!);
    }
    setState(() {
      _options = opts.toList()..shuffle();
    });
  }

  void _onTap(String selection) {
    
    try { AudioFeedback.instance.playEvent(SoundEvent.tap); } catch (_) {}
if (_answered) return;
    setState(() {
      _answered = true;
      _selectedPower = selection;
      if (selection == _correctPower) {
        _correctAnswers++;
      }
    });
    
    // audio: answer feedback
    try {
      if (_selectedPower == _correctPower) { AudioFeedback.instance.playEvent(SoundEvent.answerCorrect); } else { AudioFeedback.instance.playEvent(SoundEvent.answerWrong); }
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

  /// Formats brand+model into the file-base used in Storage.
  String _fileBase(String brand, String model) {
    final combined = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return combined
        .split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join();
  }

  /// Displays the current frame image from cache.
  Widget _buildFrameImage() {
    final base = _fileBase(_currentBrand!, _currentModel!);
    final fileName = '$base$_frameIndex.webp';
    return Image(
      key: ValueKey<int>(_frameIndex),
      image: ImageCacheService.instance.imageProvider(fileName),
      height: 220,
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
        title: const Text('Power Challenge'),
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
                    'What is the horsepower of\n'
                    '${_currentBrand!} ${_currentModel!}?',
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
                  const SizedBox(height: 24),
                  for (var opt in _options)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: SizedBox(
                        height: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Material(
                            color: _answered
                                ? (opt == _correctPower
                                    ? Colors.green
                                    : (opt == _selectedPower
                                        ? Colors.red
                                        : Colors.grey[800]!))
                                : Colors.grey[800],
                            child: InkWell(
                              onTap: _answered ? null : () => _onTap(opt),
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
            ),
    );
  }
}