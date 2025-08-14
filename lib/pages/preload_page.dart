import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../main.dart';
import '../storage/lives_storage.dart';
import '../services/image_service_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreloadPage extends StatefulWidget {
  final int initialLives;
  final LivesStorage livesStorage;

  const PreloadPage({
    Key? key,
    required this.initialLives,
    required this.livesStorage,
  }) : super(key: key);

  @override
  _PreloadPageState createState() => _PreloadPageState();
}

class _PreloadPageState extends State<PreloadPage> {
  List<String> _allFiles = [];
  final Set<String> _cachedFiles = {};
  int _loadedCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _prepareFileList().then((_) => _startCaching());
  }

  Future<void> _prepareFileList() async {
    final rawCsv = await rootBundle.loadString('assets/cars.csv');
    final lines = const LineSplitter().convert(rawCsv);
    final files = <String>[];

    for (var line in lines) {
      final parts = line.split(',');
      if (parts.length >= 2) {
        final brand = parts[0].trim();
        final model = parts[1].trim();
        final raw = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
        final fileBase = raw
            .split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
            .map((w) =>
                w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
            .join();

        for (int i = 0; i <= 5; i++) {
          files.add('$fileBase$i.webp');
        }
      }
    }
    setState(() => _allFiles = files);
  }

  Future<void> _startCaching() async {
    final missingFiles = <String>[];
    for (var file in _allFiles) {
      final isCached = await ImageCacheService.instance.isImageCached(file);
      if (!isCached) {
        missingFiles.add(file);
      }
    }

    if (missingFiles.isEmpty) {
      // All images are already cached, navigate to home page immediately
      _navigateToHomePage();
      return;
    }

    for (var file in missingFiles) {
      try {
        await ImageCacheService.instance
            .imageProvider(file)
            .resolve(const ImageConfiguration());
        setState(() {
          if (_cachedFiles.add(file)) _loadedCount++;
        });
      } catch (_) {
        // ignore failures
      }
      await Future.delayed(const Duration(milliseconds: 30));
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    // Set the persistent variable to indicate that images are loaded
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('areImagesLoaded', true);

    _navigateToHomePage();
  }

  void _navigateToHomePage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainPage(
            initialLives: widget.initialLives,
            livesStorage: widget.livesStorage,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = _allFiles.length;
    final loaded = _loadedCount;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Warming Up Your Garage...'),
        backgroundColor: const Color(0xFF3D0000),
      ),
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GridView.builder(
                itemCount: total,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemBuilder: (context, idx) {
                  final file = _allFiles[idx];
                  if (_cachedFiles.contains(file)) {
                    return Image(
                      image: ImageCacheService.instance.imageProvider(file),
                      fit: BoxFit.cover,
                    );
                  } else {
                    return Container(color: Colors.grey[800]);
                  }
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: loaded / total,
                  backgroundColor: Colors.grey[700],
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoading
                      ? 'Loading in progress...'
                      : 'Cached $loaded of $total cars',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
