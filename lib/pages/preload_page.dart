// lib/pages/preload_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../main.dart';
import '../storage/lives_storage.dart';
import '../services/image_service_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreloadPage extends StatefulWidget {
  // Optional so it works from ProfilePage and from app start.
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
  // ---- Data & UI model ----
  final List<String> _allFiles = [];
  final List<String> _thumbPool = [];         // cached files ready to show
  late final List<String?> _gridImages;       // visible grid (filenames or null)
  static const int _gridSlots = 30;

  // ---- Progress ----
  int _total = 0;
  int _already = 0;
  int _downloaded = 0;
  int _failed = 0;
  bool _running = true;                       // stay on page until done

  // ---- Timers / monitors ----
  Timer? _ticker;                             // throttled repaint during work
  Timer? _shuffler;                           // rotates thumbnails every 5s
  Timer? _watchdog;                           // detects stalls

  // Stall detection
  int _lastObservedDone = 0;
  DateTime _lastProgressAt = DateTime.now();
  bool _connectivityDialogOpen = false;

  final _rand = Random();

  // Tunables
  static const _kWorkers = 10;
  static const _kUiThrottleMs = 200;
  static const _kShuffleSeconds = 5;
  static const _kStallSeconds = 12;          // if no progress for >= this, verify connectivity
  static const _kPerFileTimeout = Duration(seconds: 10); // avoid hanging fetches

  @override
  void initState() {
    super.initState();
    _gridImages = List<String?>.filled(_gridSlots, null, growable: false);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepareList();        // build filenames + seed UI with cached
      if (!mounted) return;
      _startShuffler();            // animate the grid
      _startWatchdog();            // monitor for stalls
      await _ensureConnectivity(); // require network before starting
      if (!mounted) return;
      await _startCaching();       // fetch missing
      if (!mounted) return;
      await _finish();             // exit or pop summary
    });
  }

  // ---------------- Connectivity helpers ----------------

  Future<bool> _hasConnectivity() async {
    // Try Firebase Storage host first
    try {
      final res = await InternetAddress.lookup('firebasestorage.googleapis.com')
          .timeout(const Duration(seconds: 3));
      if (res.isNotEmpty && res.first.rawAddress.isNotEmpty) return true;
    } catch (_) {}
    // Fallback to a general host
    try {
      final res = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (res.isNotEmpty && res.first.rawAddress.isNotEmpty) return true;
    } catch (_) {}
    return false;
  }

  Future<void> _ensureConnectivity() async {
    // Show a blocking dialog until connectivity is available.
    while (mounted) {
      final ok = await _hasConnectivity();
      if (ok) return;

      if (!_connectivityDialogOpen) {
        _connectivityDialogOpen = true;
        // ignore: use_build_context_synchronously
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('No Internet Connection'),
            content: const Text(
              'Loading images requires internet access.\n'
              'Please connect to Wi-Fi or cellular data, then tap Retry.',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final ok = await _hasConnectivity();
                  if (ok && mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
        _connectivityDialogOpen = false;
      }

      // Loop again if still offline.
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  // ---------------- File list + initial thumbnails ----------------

  Future<void> _prepareList() async {
    final rawCsv = await rootBundle.loadString('assets/cars.csv');
    final lines = const LineSplitter().convert(rawCsv);

    final set = <String>{};
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length < 2) continue;

      // Skip header row if present
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

    // Seed pool with already cached images so the grid starts populated
    for (final f in _allFiles) {
      final cached = await ImageCacheService.instance.isImageCached(f);
      if (cached) {
        _already++;
        _thumbPool.add(f);
      }
    }

    // Fill initial grid from pool (may be partially filled)
    _fillGridFromPool();

    setState(() {});
  }

  // ---------------- Download + caching ----------------

  Future<void> _startCaching() async {
    // Build queue of missing files
    final queue = <String>[];
    for (final f in _allFiles) {
      final cached = await ImageCacheService.instance.isImageCached(f);
      if (!cached) queue.add(f);
    }

    if (queue.isEmpty) return;

    // Throttle UI updates
    _ticker = Timer.periodic(const Duration(milliseconds: _kUiThrottleMs), (_) {
      if (!mounted) return;
      final done = _already + _downloaded + _failed;
      if (done != _lastObservedDone) {
        _lastObservedDone = done;
        _lastProgressAt = DateTime.now();
      }
      setState(() {});
    });

    // Parallel workers
    final futures = <Future<void>>[];
    for (int i = 0; i < _kWorkers; i++) {
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

      // Check connectivity before starting a download.
      await _ensureConnectivity();
      if (!_running) return;

      try {
        // Safeguard against indefinite hangs: time out each fetch.
        await precacheImage(
          ImageCacheService.instance.imageProvider(file),
          context,
        ).timeout(_kPerFileTimeout);

        _downloaded++;
        _thumbPool.add(file);
        _placeNewImageIntoGrid(file);
      } on TimeoutException {
        // Network likely stalled. Requeue and wait for connectivity.
        queue.add(file);
        await _ensureConnectivity();
        // loop to retry
      } catch (e) {
        // If it's a networkish error, requeue after ensuring connectivity.
        final msg = e.toString();
        final networkish = e is SocketException ||
            msg.contains('Handshake') ||
            msg.contains('Failed host lookup') ||
            msg.contains('Connection closed') ||
            msg.contains('timed out') ||
            msg.contains('Network is unreachable');
        if (networkish) {
          queue.add(file);
          await _ensureConnectivity();
          continue;
        }
        // Otherwise count as failed.
        _failed++;
      }
    }
  }

  // ---------------- Watchdog: detect stalls mid-process ----------------

  void _startWatchdog() {
    _watchdog?.cancel();
    _lastObservedDone = _already + _downloaded + _failed;
    _lastProgressAt = DateTime.now();

    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_running || !mounted) return;

      final done = _already + _downloaded + _failed;
      // Progress advanced since last tick
      if (done != _lastObservedDone) {
        _lastObservedDone = done;
        _lastProgressAt = DateTime.now();
        return;
      }

      // No progress: if exceeded stall threshold, verify connectivity and block with dialog if offline.
      final stalledFor = DateTime.now().difference(_lastProgressAt).inSeconds;
      if (stalledFor >= _kStallSeconds && !_connectivityDialogOpen) {
        final online = await _hasConnectivity();
        if (!online) {
          await _ensureConnectivity(); // shows popup and waits until back online
          _lastProgressAt = DateTime.now(); // reset stall timer after recovery
        }
      }
    });
  }

  // ---------------- UI helpers ----------------

  void _placeNewImageIntoGrid(String file) {
    // Fill first empty slot if any
    final emptyIndex = _gridImages.indexWhere((e) => e == null);
    if (emptyIndex != -1) {
      _gridImages[emptyIndex] = file;
      return;
    }
    // Otherwise replace a random slot to animate variety
    final idx = _rand.nextInt(_gridImages.length);
    _gridImages[idx] = file;
  }

  void _fillGridFromPool() {
    if (_thumbPool.isEmpty) return;
    int poolIdx = 0;
    for (int i = 0; i < _gridImages.length; i++) {
      if (_gridImages[i] == null) {
        _gridImages[i] = _thumbPool[poolIdx % _thumbPool.length];
        poolIdx++;
      }
    }
  }

  void _startShuffler() {
    _shuffler?.cancel();
    _shuffler = Timer.periodic(const Duration(seconds: _kShuffleSeconds), (_) {
      if (!_running || _thumbPool.isEmpty || !mounted) return;
      final replacements = min(6, _gridImages.length);
      for (int k = 0; k < replacements; k++) {
        final slot = _rand.nextInt(_gridImages.length);
        final pic = _thumbPool[_rand.nextInt(_thumbPool.length)];
        _gridImages[slot] = pic;
      }
      setState(() {});
    });
  }

  // ---------------- Finish / teardown ----------------
  Future<void> _finish() async {
    _running = false;

    // ✅ Mark preload as done so next launch skips it
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('areImagesLoaded', true);

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => MainPage(
          initialLives: widget.initialLives ?? 5,
          livesStorage: widget.livesStorage ?? LivesStorage(),
        ),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _running = false;
    _ticker?.cancel();
    _shuffler?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    final done = _already + _downloaded + _failed;
    final total = _total == 0 ? 1 : _total;
    final progress = done / total;

    return WillPopScope(
      onWillPop: () async => !_running, // do not quit until complete
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Caching Images'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Loading images, do not quit',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),

              // Animated thumbnail grid
              Expanded(
                child: GridView.builder(
                  itemCount: _gridImages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemBuilder: (context, idx) {
                    final file = _gridImages[idx];
                    if (file == null) {
                      return Container(color: Colors.grey[800]);
                    }
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      child: Container(
                        key: ValueKey(file),
                        color: Colors.black,
                        child: Image(
                          image: ImageCacheService.instance.imageProvider(file),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _stat('Total ', _total),
                  _stat('Done ', done),
                ],
              ),
              const SizedBox(height: 12),
              _stat('Downloaded', _downloaded),
              _stat('Already cached', _already),
              _stat('Failed', _failed),

              const SizedBox(height: 12),
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
      children: [Text(label), Text(value.toString())],
    );
  }
}
