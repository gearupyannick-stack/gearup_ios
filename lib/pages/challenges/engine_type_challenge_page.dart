// lib/pages/challenges/engine_type_challenge_page.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../services/image_service_cache.dart'; // ← Utilisation du cache local

class EngineTypeChallengePage extends StatefulWidget {
  @override
  _EngineTypeChallengePageState createState() =>
      _EngineTypeChallengePageState();
}

class _EngineTypeChallengePageState extends State<EngineTypeChallengePage> {
  // ── Data ────────────────────────────────────────────────────────────────────
  final List<Map<String, String>> _carData = [];
  List<String> _options = [];

  String? _currentBrand;
  String? _currentModel;
  String _correctEngineType = '';

  // ── Quiz progress ────────────────────────────────────────────────────────────
  int _questionCount = 0;
  int _correctAnswers = 0;
  int _elapsedSeconds = 0;
  Timer? _quizTimer;

  // ── Frame animation ─────────────────────────────────────────────────────────
  int _frameIndex = 0;
  Timer? _frameTimer;

  // ── Answer‐highlighting state ───────────────────────────────────────────────
  bool _answered = false;
  String? _selectedEngineType;

  @override
  void initState() {
    super.initState();
    _loadCsv();

    // overall quiz timer
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });

    // image frame timer (2 seconds per frame)
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
      // ensure brand, model, engineType columns exist
      if (parts.length > 3) {
        _carData.add({
          'brand': parts[0].trim(),
          'model': parts[1].trim(),
          'engineType': parts[3].trim(),
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

    // reset highlighting
    _answered = false;
    _selectedEngineType = null;

    final rnd = Random();
    final row = _carData[rnd.nextInt(_carData.length)];
    _currentBrand = row['brand'];
    _currentModel = row['model'];
    _correctEngineType = row['engineType']!;

    // build distinct engine type options
    final opts = <String>{_correctEngineType};
    while (opts.length < 4) {
      opts.add(_carData[rnd.nextInt(_carData.length)]['engineType']!);
    }
    setState(() {
      _options = opts.toList()..shuffle();
    });
  }

  void _onTap(String selection) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _selectedEngineType = selection;
      if (selection == _correctEngineType) {
        _correctAnswers++;
      }
    });
    // wait 1s showing highlights, then advance
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
          '${_elapsedSeconds ~/ 60}m '
          '${(_elapsedSeconds % 60).toString().padLeft(2, '0')}s',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(
                context,
                '$_correctAnswers/20 in ${_elapsedSeconds ~/ 60}\''
                '${(_elapsedSeconds % 60).toString().padLeft(2, '0')}\'\'',
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Sanitizes brand+model to your file-base, e.g. "Porsche911".
  String _fileBase(String brand, String model) {
    final combined = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return combined
        .split(
            RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
        .map((w) =>
            w.isNotEmpty
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
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutes =
        (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds =
        (_elapsedSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Engine Type Challenge'),
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
                    'What is the engine type of\n'
                    '$_currentBrand $_currentModel?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // rotating model image from cache
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: _buildFrameImage(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // choices as full-width rounded buttons
                  for (var opt in _options)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: SizedBox(
                        height: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Material(
                            color: _answered
                                ? (opt == _correctEngineType
                                    ? Colors.green
                                    : (opt == _selectedEngineType
                                        ? Colors.red
                                        : Colors.grey[800]!))
                                : Colors.grey[800],
                            child: InkWell(
                              onTap:
                                  _answered ? null : () => _onTap(opt),
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
