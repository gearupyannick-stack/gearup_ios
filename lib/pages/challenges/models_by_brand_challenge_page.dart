// lib/pages/challenges/models_by_brand_challenge_page.dart

import 'dart:async';
import 'dart:convert';               // for LineSplitter
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../services/image_service_cache.dart'; // ← Utilisation du cache local

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
    _brands = _carData.map((e) => e['brand']!).toSet().toList();
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
            Image(
              image: ImageCacheService.instance
                  .imageProvider('${_fileBase}4.webp'),
              fit: BoxFit.cover,
            ),
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
  static const int _frameCount = 6; // frames 0..5

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
  late Timer _quizTimer;
  late Timer _frameTimer;

  @override
  void initState() {
    super.initState();
    _allModels = List.from(widget.models);

    // overall quiz timer
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });

    // frame cycling every 2 seconds
    _frameTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      setState(() => _frameIndex = (_frameIndex + 1) % _frameCount);
    });

    _nextQuestion();
  }

  @override
  void dispose() {
    _quizTimer.cancel();
    _frameTimer.cancel();
    super.dispose();
  }

  void _nextQuestion() {
    if (_questionCount >= _maxQuestions) {
      return _finishQuiz();
    }
    _questionCount++;
    _isImageToModel = _questionCount.isOdd;
    _answered = false;
    _selectedModel = null;

    final rnd = Random();
    _correctAnswer = _allModels[rnd.nextInt(_allModels.length)];

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
    setState(() {});
  }

  void _finishQuiz() {
    _quizTimer.cancel();
    _frameTimer.cancel();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quiz Completed!'),
        content: Text(
          'You got $_correctAnswers/$_maxQuestions in '
          '${_elapsedSeconds ~/ 60}m '
          '${(_elapsedSeconds % 60).toString().padLeft(2, '0')}s',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDone();
            },
            child: const Text('OK'),
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

  Widget _buildStaticModelImage(int i) {
    final fileBase = _formatImageName(widget.brand, _correctAnswer);
    return Image(
      image: ImageCacheService.instance.imageProvider('$fileBase$i.webp'),
      height: 160,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  void _onOptionTap(String selection) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _selectedModel = selection;
      if (selection == _correctAnswer) _correctAnswers++;
    });
    Future.delayed(const Duration(seconds: 1), _nextQuestion);
  }

  @override
  Widget build(BuildContext context) {
    final headerTime =
        '${_elapsedSeconds ~/ 60}:${(_elapsedSeconds % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Models by Brand'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Score: $_correctAnswers/$_maxQuestions',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (_isImageToModel) ...[
              const Text(
                'Which model of this brand is shown?',
                style: TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              for (int i = 0; i < _frameCount; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildStaticModelImage(i),
                  ),
                ),
              const SizedBox(height: 24),
              for (var m in _options)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Material(
                        color: _answered
                            ? (m == _correctAnswer
                                ? Colors.green
                                : (m == _selectedModel
                                    ? Colors.red
                                    : Colors.grey[800]!))
                            : Colors.grey[800],
                        child: InkWell(
                          onTap: () => _onOptionTap(m),
                          child: Center(
                            child: Text(
                              m,
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
                    onTap: () => _onOptionTap(model),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Material(
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
                            child: Image(
                              image: ImageCacheService.instance
                                  .imageProvider('$fileBase$_frameIndex.webp'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}