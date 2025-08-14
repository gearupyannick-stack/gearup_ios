// lib/pages/challenges/special_feature_challenge_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../services/image_service_cache.dart'; // ← Utilisation du cache local

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

  // Answer highlighting
  bool _answered = false;
  String? _selectedFeature;

  @override
  void initState() {
    super.initState();
    _loadCsv();

    // overall quiz timer (seconds)
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });

    // animation timer (2s per frame)
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
    super.dispose();
  }

  Future<void> _loadCsv() async {
    final raw = await rootBundle.loadString('assets/cars.csv');
    final lines = const LineSplitter().convert(raw);
    for (var line in lines) {
      final parts = line.split(',');
      // ensure we have at least 11 columns: notableFeature at index 10
      if (parts.length > 10) {
        _carData.add({
          'brand': parts[0].trim(),
          'model': parts[1].trim(),
          'feature': parts[10].trim(),
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

    // build four distinct feature options
    final opts = <String>{_correctFeature};
    while (opts.length < 4) {
      opts.add(_carData[rnd.nextInt(_carData.length)]['feature']!);
    }
    setState(() {
      _options = opts.toList()..shuffle();
    });
  }

  void _onTap(String feature) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _selectedFeature = feature;
      if (feature == _correctFeature) {
        _correctAnswers++;
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
        title: const Text('Special Feature Challenge'),
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
                  const SizedBox(height: 24),

                  // ---- Updated option buttons ----
                  for (var feature in _options)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Material(
                          color: _answered
                              ? (feature == _correctFeature
                                  ? Colors.green
                                  : (feature == _selectedFeature
                                      ? Colors.red
                                      : Colors.grey[800]!))
                              : Colors.grey[800],
                          child: InkWell(
                            onTap: _answered ? null : () => _onTap(feature),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 16.0),
                              child: Text(
                                feature,
                                textAlign: TextAlign.center,
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
                ],
              ),
            ),
    );
  }
}