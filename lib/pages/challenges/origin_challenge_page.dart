// lib/pages/origin_challenge_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../services/audio_feedback.dart'; // added by audio patch

import '../../services/image_service_cache.dart'; // ← Utilisation du cache local

class OriginChallengePage extends StatefulWidget {
  @override
  _OriginChallengePageState createState() => _OriginChallengePageState();
}

class _OriginChallengePageState extends State<OriginChallengePage> {
  // ── Data ───────────────────────────────────────────────────────────────────
  final List<Map<String, String>> _carData = [];
  List<String> _options = [];

  String? _currentBrand;
  String? _currentModel;
  String  _correctOrigin = '';

  // ── Quiz progress ────────────────────────────────────────────────────────────
  int    _questionCount  = 0;
  int    _correctAnswers = 0;
  int    _elapsedSeconds = 0;
  Timer? _quizTimer;

  // ── Frame animation ─────────────────────────────────────────────────────────
  int    _frameIndex = 0;
  Timer? _frameTimer;

  // ── Answer‐highlighting ─────────────────────────────────────────────────────
  String? _selectedOrigin;
  bool    _answered      = false;

  @override
  void initState() {
    super.initState();
    
    // audio: page open
    try { AudioFeedback.instance.playEvent(SoundEvent.pageOpen); } catch (_) {}
_loadCsv();

    // overall quiz timer
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });

    // frame‐by‐frame timer (2s per frame)
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
      if (parts.length >= 10) {
        _carData.add({
          'brand'  : parts[0].trim(),
          'model'  : parts[1].trim(),
          'origin' : parts[9].trim(),
        });
      }
    }
    _nextQuestion();
  }

  void _nextQuestion() {
    if (_questionCount >= 20) {
      return _finishQuiz();
    }
    _questionCount++;
    _selectedOrigin = null;
    _answered       = false;

    final rnd = Random();
    final row = _carData[rnd.nextInt(_carData.length)];
    _currentBrand  = row['brand'];
    _currentModel  = row['model'];
    _correctOrigin = row['origin']!;

    final opts = <String>{ _correctOrigin };
    while (opts.length < 4) {
      opts.add(_carData[rnd.nextInt(_carData.length)]['origin']!);
    }

    setState(() {
      _options = opts.toList()..shuffle();
    });
  }

  void _onTap(String selection) {
    
    try { AudioFeedback.instance.playEvent(SoundEvent.tap); } catch (_) {}
if (_answered) return;
    setState(() {
      _selectedOrigin = selection;
      _answered       = true;
      if (selection == _correctOrigin) {
        _correctAnswers++;
      }
    });
    
    // audio: answer feedback
    try {
      if (_selectedOrigin == _correctOrigin) { AudioFeedback.instance.playEvent(SoundEvent.answerCorrect); } else { AudioFeedback.instance.playEvent(SoundEvent.answerWrong); }
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

  /// Sanitizes "BrandModel" into your file-base, e.g. "Porsche911".
  String _fileBase(String brand, String model) {
    final combined = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return combined
        .split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join();
  }

  /// Displays the current frame image from cache instead of FutureBuilder.
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
        title: const Text('Origin Challenge'),
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
                    'Which country does ${_currentBrand!} originate from?',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // rotating car image fetched from cache
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: _buildFrameImage(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // answer buttons
                  for (var origin in _options)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: SizedBox(
                        height: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Material(
                            color: _answered
                                ? (origin == _correctOrigin
                                    ? Colors.green
                                    : (origin == _selectedOrigin
                                        ? Colors.red
                                        : Colors.grey[800]!))
                                : Colors.grey[800],
                            child: InkWell(
                              onTap: _answered ? null : () => _onTap(origin),
                              child: Center(
                                child: Text(
                                  origin,
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
            ),
    );
  }
}