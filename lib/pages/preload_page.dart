// lib/pages/preload_page.dart
// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../storage/lives_storage.dart';
import '../services/image_service_cache.dart';

class PreloadPage extends StatefulWidget {
  /// Make args optional to be compatible with both push(const PreloadPage())
  /// and push(PreloadPage(initialLives: ..., livesStorage: ...)).
  final int? initialLives;
  final LivesStorage? livesStorage;

  const PreloadPage({
    Key? key,
    this.initialLives,
    this.livesStorage,
  }) : super(key: key);

  @override
  State<PreloadPage> createState() => _PreloadPageState();
}

class _PreloadPageState extends State<PreloadPage> {
  final List<String> _allFiles = [];
  final Set<String> _cachedFiles = {};

  int _total = 0;
  int _already = 0;
  int _downloaded = 0;
  int _failed = 0;
  bool _running = true;

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepareList();
      if (!mounted) return;
      await _startCaching();
      if (!mounted) return;
      await _finish();
    });
  }

  Future<void> _prepareList() async {
    final rawCsv = await rootBundle.loadString('assets/cars.csv');
    final lines = const LineSplitter().convert(rawCsv);

    final set = <String>{};
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length < 2) continue;

      // Skip header
      if (i == 0 && parts[0].toLowerCase().contains('brand')) continue;

      final brand = parts[0].trim();
      final model = parts[1].trim();
      final raw = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
      final fileBase = raw
          .split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
          .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
          .join();

      for (int j = 0; j <= 5; j++) {
        set.add('$fileBase$j.webp');
      }
    }

    _allFiles.addAll(set);
    _total = _allFiles.length;
    setState(() {});
  }

  Future<void> _startCaching() async {
    // Count already-cached and build queue
    final queue = <String>[];
    for (final f in _allFiles) {
      final isCached = await ImageCacheService.instance.isImageCached(f);
      if (isCached) {
        _already++;
        _cachedFiles.add(f);
      } else {
        queue.add(f);
      }
    }
    setState(() {});

    if (queue.isEmpty) return;

    // throttle UI refresh
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });

    // limited parallelism
    const workers = 10;
    final futures = <Future<void>>[];
    for (int i = 0; i < workers; i++) {
      futures.add(_worker(queue));
    }
    await Future.wait(futures);

    _ticker?.cancel();
    if (mounted) setState(() {});
  }

  Future<void> _worker(List<String> queue) async {
    while (_running) {
      if (queue.isEmpty) return;
      final file = queue.removeLast();
      try {
        await precacheImage(
          ImageCacheService.instance.imageProvider(file),
          context,
        );
        _downloaded++;
        _cachedFiles.add(file);
      } catch (_) {
        _failed++;
      }
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('areImagesLoaded', true);

    // If caller provided lives params, route to MainPage like your original.
    // Otherwise, return a summary to the caller (ProfilePage button).
    if (widget.initialLives != null && widget.livesStorage != null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainPage(
            initialLives: widget.initialLives!,
            livesStorage: widget.livesStorage!,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.of(context).pop(<String, int>{
        'downloaded': _downloaded,
        'cached': _already,
        'failed': _failed,
      });
    }
  }

  @override
  void dispose() {
    _running = false;
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _already + _downloaded + _failed;
    final total = _total == 0 ? 1 : _total;
    final progress = done / total;

    return WillPopScope(
      onWillPop: () async => !_running,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Preparing assets'),
          automaticallyImplyLeading: !_running,
          actions: [
            if (_running)
              TextButton(
                onPressed: () => setState(() => _running = false),
                child: const Text('Stop', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF121212),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total: $_total', style: const TextStyle(color: Colors.white70)),
                  Text('Done: $done', style: const TextStyle(color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 12),
              _stat('Already cached', _already),
              _stat('Downloaded', _downloaded),
              _stat('Failed', _failed),
              const Spacer(),
              if (!_running)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Close'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(value.toString(), style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
