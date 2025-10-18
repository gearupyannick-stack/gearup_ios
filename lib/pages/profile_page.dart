// lib/pages/profile_page.dart
// ignore_for_file: unused_element, deprecated_member_use, unused_field

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback? onReplayTutorial;
  const ProfilePage({Key? key, this.onReplayTutorial}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Profile info
  String username = '';
  String favoriteBrand = '';
  String favoriteModel = '';
  int profilePicIndex = 0;
  String createdAt = '';
  bool _isDataLoaded = false;
  String? _justUnlockedAchievement;

  // Stats counters
  int dailyStreak = 0;
  int trainingCompletedCount = 0;
  int correctAnswerCount = 0;
  int categoriesMastered = 0;
  int challengesAttemptedCount = 0;
  int questionAttemptCount = 0;

  // Progress (gears) data
  int _gearCount = 0;
  int _currentTrack = 1;
  int _sessionsCompleted = 0;
  int _requiredGearsForCurrentLevel = 0;
  int _currentLevelGears = 0;
  double _progressValue = 0.0;

  // Google-related flags (kept for display/backwards compatibility)
  bool _googleSignedIn = false;
  String? _googleDisplayName;
  String? _googleEmail;
  String? _googlePhotoUrl;
  bool _useGoogleName = true; // if true, show Google name instead of local username

  // guest detection
  bool _isGuest = false;

  // For the edit dialog
  List<String> _brandOptions = [];
  Map<String, List<String>> _brandToModels = {};
  bool _isCarDataLoaded = false;

  String _getAchievementIdFromName(String name) {
    return name.split("–")[0].trim().toLowerCase().replaceAll(' ', '_');
  }

  bool isUnlocked(String name) {
    final id = _getAchievementIdFromName(name);
    return unlockedAchievementIds.contains(id);
  }

  final Map<String, List<String>> achievementMap = {
    '🔸 Track Progression': [
      'First Flag – Tap your very first flag on any Track.',
      'Level Complete – Finish Level 1 on Track 1.',
      'Mid-Track Milestone – Finish Level 5 on Track 1.',
      'Track Conqueror – Complete all levels on Track 1 (10/10), Track 2 (20/20) or Track 3 (30/30).',
    ],
    '🔸 Perfect Runs': [
      'Clean Slate – Answer every question in a single level correctly (all green flags).',
      'Zero-Life Loss – Complete a level without ever losing a life.',
      'Swift Racer – Finish any one level in under 60 seconds (time your elapsedSeconds).',
    ],
    '🔸 Gear Mastery': [
      'Gear Rookie – Earn 100 gears on the Home track.',
      'Gear Grinder – Accumulate 1,000 gears total.',
      'Gear Tycoon – Hit 5,000 gears total.',
    ],
    '🔸 Gate & Track Unlocks': [
      'Gate Opener – Unlock your first “LevelLimit” gate.',
      'Track Unlocker I – Unlock Track 2.',
      'Track Unlocker II – Unlock Track 3.',
    ],
    '🔸 Comeback & Correction': [
      'Second Chance – Use the “Retry” correction run to turn a red/orange flag green.',
      'Perseverance – Correct 5 failed flags via correction runs.',
    ],
    '🎓 Training Achievements': [
      'Training Initiate – Complete your 1st training session.',
      'Training Regular – Hit 10 sessions.',
      'Training Veteran – Hit 50 sessions.',
      'Quiz Streak – Score ≥ 10/20 in 5 sessions in a row.',
      'Sharpshooter – Maintain ≥ 90% accuracy over 200 total question attempts.',
      'All-Rounder – On one day, score ≥ 10/20 in all 8 modules.',
      'Training All-Star – Earn 20/20 in all 8 modules (at least once each).',
    ],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNewAchievement();
    });
    _loadProfileData();
    _loadCarData();
    _loadDailyStreak();
    _loadTrainingCompletedCount();
    _loadCorrectAnswerCount();
    _loadCategoriesMasteredCount();
    _loadChallengesAttemptedCount();
    _loadQuestionAttemptCount();
    _loadUnlockedAchievements();
  }

  List<String> unlockedAchievementIds = [];

  Future<void> _loadUnlockedAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      unlockedAchievementIds = prefs.getStringList('unlockedAchievements') ?? [];
    });
  }

  void showAchievementSnackBar(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🏆 Achievement Unlocked: $title"),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }

  Future<void> unlockAchievement(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = prefs.getStringList('unlockedAchievements') ?? [];
    if (!unlocked.contains(id)) {
      unlocked.add(id);
      await prefs.setStringList('unlockedAchievements', unlocked);
      final title = _getDisplayNameFromId(id);
      showAchievementSnackBar(title);
    }
  }

  String _getDisplayNameFromId(String id) {
    for (final entry in achievementMap.entries) {
      for (final name in entry.value) {
        if (_getAchievementIdFromName(name) == id) {
          return name.split("–")[0].trim();
        }
      }
    }
    return id;
  }

  Future<void> _checkNewAchievement() async {
    final prefs = await SharedPreferences.getInstance();
    final all = prefs.getStringList('unlockedAchievements') ?? [];
    final old = prefs.getStringList('shownAchievements') ?? [];
    for (final id in all) {
      if (!old.contains(id)) {
        old.add(id);
        await prefs.setStringList('shownAchievements', old);
        break;
      }
    }
  }

  bool isAchievementUnlocked(String id) {
    return unlockedAchievementIds.contains(id);
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();

    // Read Google-related prefs (your Google sign-in flow should set these keys)
    final googleSigned = prefs.getBool('google_signed_in') ?? false;
    final googleName = prefs.getString('google_displayName');
    final googleEmail = prefs.getString('google_email');
    final googlePhoto = prefs.getString('google_photoUrl');
    final useGoogleNamePref = prefs.getBool('use_google_name') ?? true;

    // Read stored username and other profile fields
    final storedUsername = prefs.getString('username');
    final storedFavoriteBrand = prefs.getString('favoriteBrand') ?? 'N/A';
    final storedFavoriteModel = prefs.getString('favoriteModel') ?? 'N/A';
    final storedCreatedAt = prefs.getString('createdAt');
    final storedPicIndex = prefs.getInt('profilePictureIndex');

    // Decide guest status (fallback heuristic)
    final guestPref = prefs.getBool('is_guest');
    final isGuestDetermined = guestPref ??
        (storedUsername == null ||
            storedUsername.isEmpty ||
            storedUsername == 'N/A' ||
            storedUsername.startsWith('unamed'));

    // Compute profilePicIndex and createdAt (persist if missing)
    int resolvedPicIndex;
    if (storedPicIndex == null) {
      resolvedPicIndex = Random().nextInt(6);
      await prefs.setInt('profilePictureIndex', resolvedPicIndex);
    } else {
      resolvedPicIndex = storedPicIndex;
    }

    final resolvedCreatedAt =
        storedCreatedAt ?? DateTime.now().toLocal().toIso8601String().split('T').first;
    if (storedCreatedAt == null) {
      await prefs.setString('createdAt', resolvedCreatedAt);
    }

    // Decide username: prefer persisted username, but allow Google name when signed in & opted-in
    String resolvedUsername =
        (storedUsername == null || storedUsername.isEmpty || storedUsername == 'N/A')
            ? 'unamed_carenthusiast'
            : storedUsername;

    if (googleSigned && useGoogleNamePref && (googleName != null && googleName.isNotEmpty)) {
      resolvedUsername = googleName;
    }

    // Finally apply to state
    setState(() {
      _googleSignedIn = googleSigned;
      _googleDisplayName = googleName;
      _googleEmail = googleEmail;
      _googlePhotoUrl = googlePhoto;
      _useGoogleName = useGoogleNamePref;

      _isGuest = isGuestDetermined;

      username = resolvedUsername;
      favoriteBrand = storedFavoriteBrand;
      favoriteModel = storedFavoriteModel;
      profilePicIndex = resolvedPicIndex;
      createdAt = resolvedCreatedAt;
      _isDataLoaded = true;
    });

    // Persist username if missing in prefs (keep behavior you had)
    if (prefs.getString('username') == null ||
        prefs.getString('username')!.isEmpty ||
        prefs.getString('username') == 'N/A') {
      await prefs.setString('username', username);
    }

    // If car data already loaded, try to fill random brand/model if missing
    await _ensureRandomProfileIfMissing();

    // Load progress that depends on prefs
    _loadProgressData();
  }

  Widget _buildAvatarHeader(String memSince) {
    // Compute fileBase only when we have a valid favorite brand+model
    String? fileBase;
    if (favoriteBrand.isNotEmpty &&
        favoriteBrand != 'N/A' &&
        favoriteModel.isNotEmpty &&
        favoriteModel != 'N/A') {
      fileBase = _formatImageName(favoriteBrand, favoriteModel);
    }

    final String assetForProfile = fileBase != null
        ? 'assets/model/${fileBase}${profilePicIndex}.webp'
        : 'assets/profile/avatar.png';

    final Widget avatarImage = ClipOval(
      child: _googleSignedIn && _googlePhotoUrl != null && _useGoogleName
          ? Image.network(
              _googlePhotoUrl!,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => Image.asset(
                'assets/profile/avatar.png',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            )
          : Image.asset(
              assetForProfile,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => Image.asset(
                'assets/profile/avatar.png',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
    );

    final displayName = (_googleSignedIn && _useGoogleName && (_googleDisplayName?.isNotEmpty ?? false))
        ? _googleDisplayName!
        : username;

    final statusChip = _googleSignedIn
        ? Chip(label: Text(_googleEmail ?? 'Google'), avatar: const Icon(Icons.check_circle, size: 16))
        : (_isGuest ? const Chip(label: Text('Guest')) : const SizedBox.shrink());

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showAccountDialog,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.transparent,
                  child: avatarImage,
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: Material(
                    color: Colors.black.withOpacity(0.05),
                    shape: const CircleBorder(),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Edit profile',
                      onPressed: _showEditProfileDialog,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          GestureDetector(
            onTap: _showAccountDialog,
            child: Column(
              children: [
                Text(displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Member since: $memSince', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          statusChip,
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orange),
              const SizedBox(width: 6),
              Text('Streak: $dailyStreak Days', style: const TextStyle(fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadDailyStreak() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      dailyStreak = prefs.getInt('dayStreak') ?? 0;
    });
  }

  Future<void> _loadTrainingCompletedCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      trainingCompletedCount = prefs.getInt('trainingCompletedCount') ?? 0;
    });
  }

  Future<void> _loadCorrectAnswerCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      correctAnswerCount = prefs.getInt('correctAnswerCount') ?? 0;
    });
  }

  Future<void> _loadCategoriesMasteredCount() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = [
      'best_Brand',
      'best_Model',
      'best_Origin',
      'best_EngineType',
      'best_MaxSpeed',
      'best_Acceleration',
      'best_Power',
      'best_SpecialFeature'
    ];
    int count = 0;
    for (var key in keys) {
      final val = prefs.getString(key);
      if (val != null && val.contains('Best score : 20/20')) {
        count++;
      }
    }
    setState(() {
      categoriesMastered = count;
    });
  }

  Future<void> _loadChallengesAttemptedCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      challengesAttemptedCount = prefs.getInt('challengesAttemptedCount') ?? 0;
    });
  }

  Future<void> _loadQuestionAttemptCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      questionAttemptCount = prefs.getInt('questionAttemptCount') ?? 0;
    });
  }

  Widget _buildMiniAchievement(String fullText) {
    final title = fullText.split("–")[0].trim();
    final id = _getAchievementIdFromName(fullText);
    final isUnlocked = unlockedAchievementIds.contains(id);
    return GestureDetector(
      onTap: () => _showAchievementPopup(context, fullText),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 40, color: isUnlocked ? Colors.amber : Colors.grey),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _showAllAchievementsPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final allNames = achievementMap.entries.expand((e) => e.value).toList();
        return AlertDialog(
          title: const Text('All Achievements'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              children: allNames.map((name) => _buildMiniAchievement(name)).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))
          ],
        );
      },
    );
  }

  String _fileBase(String brand, String model) {
    final combined = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return combined.splitMapJoin(
      RegExp(r'\w+'),
      onMatch: (m) => m[0]!.toUpperCase() + m.group(0)!.substring(1).toLowerCase(),
      onNonMatch: (n) => '',
    );
  }

  Future<void> _loadProgressData() async {
    final prefs = await SharedPreferences.getInstance();
    int gearCount = prefs.getInt('gearCount') ?? 0;
    int currentTrack;
    int baseGears;
    if (gearCount < 750) {
      currentTrack = 1;
      baseGears = 0;
    } else if (gearCount < 3250) {
      currentTrack = 2;
      baseGears = 750;
    } else {
      currentTrack = 3;
      baseGears = 3250;
    }
    int maxLevels = currentTrack == 1 ? 10 : currentTrack == 2 ? 20 : 30;
    int extraGears = gearCount - baseGears;
    int sessions = 0;
    int levelGears = extraGears;
    for (int lvl = 1; lvl <= maxLevels; lvl++) {
      int req = (currentTrack == 3 && lvl >= 20) ? 220 : (30 + (lvl - 1) * 10);
      if (levelGears >= req) {
        levelGears -= req;
        sessions = lvl;
      } else {
        break;
      }
    }
    int reqForCurrent = (currentTrack == 3 && sessions + 1 >= 20) ? 220 : (30 + sessions * 10);
    double prog = reqForCurrent > 0 ? levelGears / reqForCurrent : 0.0;
    setState(() {
      _gearCount = gearCount;
      _currentTrack = currentTrack;
      _sessionsCompleted = sessions;
      _requiredGearsForCurrentLevel = reqForCurrent;
      _currentLevelGears = levelGears;
      _progressValue = prog.clamp(0.0, 1.0);
    });
  }

  Future<void> _loadCarData() async {
    try {
      final raw = await rootBundle.loadString('assets/cars.csv');
      final lines = raw.split('\n');
      final brands = <String>{};
      final map = <String, Set<String>>{};
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = line.split(',');
        if (parts.length < 2) continue;
        if (i == 0 && parts[0].toLowerCase().contains('brand')) continue;
        final b = parts[0].trim(), m = parts[1].trim();
        brands.add(b);
        map.putIfAbsent(b, () => {}).add(m);
      }
      setState(() {
        _brandOptions = brands.toList()..sort();
        _brandToModels = {for (var b in _brandOptions) b: (map[b] ?? {}).toList()..sort()};
        _isCarDataLoaded = true;
      });

      // Now that car data is available, ensure random brand/model if missing
      await _ensureRandomProfileIfMissing();
    } catch (_) {
      setState(() => _isCarDataLoaded = false);
    }
  }

  // --- START: adapted Google sign-in flow (no UI buttons will call this on iOS)
  Future<void> _startGoogleSignInFlow({BuildContext? dialogContext}) async {
    // For this iOS-targeted branch we don't run any Google SDK calls.
    // Keep a clear, safe behavior: notify the user that Google sign-in isn't active here.
    if (dialogContext != null) {
      try {
        Navigator.of(dialogContext).pop();
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google sign-in is not enabled in this build. Apple ID will replace it later.')),
    );
    return;
  }
  // --- END adapted flow

  // --- START: account dialog (simplified, no Google disconnect button)
  void _showAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_googlePhotoUrl != null && _googlePhotoUrl!.isNotEmpty)
                CircleAvatar(radius: 36, backgroundImage: NetworkImage(_googlePhotoUrl!))
              else
                const CircleAvatar(radius: 36, child: Icon(Icons.person)),
              const SizedBox(height: 12),
              Text(_googleDisplayName ?? username, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_googleEmail ?? '', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                _googleSignedIn ? 'Signed in with Google' : (_isGuest ? 'Guest account' : 'Local profile'),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            // Removed Google disconnect button entirely to have a clear ground for Apple ID integration.
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
          ],
        );
      },
    );
  }
  // --- END account dialog

  /// Ensures we have a random favoriteBrand/favoriteModel when none is set.
  /// Also ensures username default is saved if it was missing.
  Future<void> _ensureRandomProfileIfMissing() async {
    if (!_isCarDataLoaded) return;
    final prefs = await SharedPreferences.getInstance();

    // Username persistence (already defaulted). Save if necessary.
    if (prefs.getString('username') == null ||
        prefs.getString('username')!.isEmpty ||
        prefs.getString('username') == 'N/A') {
      await prefs.setString('username', username.isEmpty ? 'unamed_carenthusiast' : username);
    }

    // If favorites are missing, pick a random brand and model once and persist
    final needsRandom =
        (favoriteBrand.isEmpty || favoriteBrand == 'N/A') ||
        (favoriteModel.isEmpty || favoriteModel == 'N/A');

    if (needsRandom && _brandOptions.isNotEmpty) {
      // Use a seeded RNG per install for reproducibility across app restarts for a given user
      final savedSeed = prefs.getInt('installSeed') ??
          DateTime.now().millisecondsSinceEpoch..let((s) => prefs.setInt('installSeed', s));
      final rng = Random(savedSeed);

      final randBrand = _brandOptions[rng.nextInt(_brandOptions.length)];
      final models = _brandToModels[randBrand] ?? const <String>[];
      if (models.isNotEmpty) {
        final randModel = models[rng.nextInt(models.length)];
        await prefs.setString('favoriteBrand', randBrand);
        await prefs.setString('favoriteModel', randModel);
        setState(() {
          favoriteBrand = randBrand;
          favoriteModel = randModel;
        });
      }
    }
  }

  void _showAchievementPopup(BuildContext context, String fullText) {
    final parts = fullText.split("–");
    final title = parts[0].trim();
    final description = parts.length > 1 ? parts[1].trim() : "No description available";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("OK"))],
      ),
    );
  }

  String _capitalizeEachWord(String input) {
    return input
        .split(RegExp(r'\s+'))
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '')
        .join();
  }

  String _formatImageName(String brand, String model) {
    String input = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return input
        .split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '')
        .join();
  }

  void _showUnlockedAchievementsPopup(BuildContext context) {
    final unlocked = achievementMap.entries
        .expand((e) => e.value)
        .where((name) => isUnlocked(name))
        .toList();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Unlocked Achievements"),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            children: unlocked.map((name) => _buildMiniAchievement(name)).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  void _showLockedAchievementsPopup(BuildContext context) {
    final locked = achievementMap.entries
        .expand((e) => e.value)
        .where((name) => !isUnlocked(name))
        .toList();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Locked Achievements"),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            children: locked.map((name) => _buildMiniAchievement(name)).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  // Clean, safe disconnect helper that only clears local prefs/state; no SDK calls.
  Future<void> _disconnectGoogleAccount(BuildContext dialogContext) async {
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Clear persisted flags/tokens in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('google_signed_in', false);
    await prefs.remove('google_displayName');
    await prefs.remove('google_email');
    await prefs.remove('google_photoUrl');
    await prefs.setBool('use_google_name', false);
    await prefs.setBool('is_guest', true);

    if (!mounted) {
      Navigator.of(dialogContext).pop();
      return;
    }

    setState(() {
      _googleSignedIn = false;
      _googleDisplayName = null;
      _googleEmail = null;
      _googlePhotoUrl = null;
      _useGoogleName = false;
      _isGuest = true;
      username = prefs.getString('username') ?? 'unamed_carenthusiast';
    });

    // Close progress + dialog
    Navigator.of(dialogContext).pop();
    try {
      Navigator.of(dialogContext).pop();
    } catch (_) {}
  }

  void _showEditProfileDialog() {
    String u = username;
    if (!_isCarDataLoaded) return;
    String fb = favoriteBrand != 'N/A' && favoriteBrand.isNotEmpty ? favoriteBrand : _brandOptions.first;
    String fm = favoriteModel != 'N/A' && favoriteModel.isNotEmpty ? favoriteModel : _brandToModels[fb]!.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          // Local copies inside dialog
          bool localUseGoogleName = _useGoogleName;

          return AlertDialog(
            title: const Text('Edit Profile'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  // Username field
                  TextField(
                    controller: TextEditingController(text: u),
                    decoration: const InputDecoration(labelText: 'Username'),
                    onChanged: (v) => u = v,
                  ),
                  const SizedBox(height: 12),

                  // Favorite Brand dropdown
                  DropdownButtonFormField<String>(
                    value: fb,
                    decoration: const InputDecoration(labelText: 'Favorite Brand'),
                    items: _brandOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) {
                      setSt(() {
                        fb = v!;
                        fm = _brandToModels[fb]!.first;
                      });
                    },
                  ),
                  const SizedBox(height: 8),

                  // Favorite Model dropdown
                  DropdownButtonFormField<String>(
                    value: fm,
                    decoration: const InputDecoration(labelText: 'Favorite Model'),
                    items: _brandToModels[fb]!.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) => setSt(() => fm = v!),
                  ),
                  const SizedBox(height: 12),

                  // NOTE: Google-related UI removed here to provide a clean ground for Apple ID integration.
                  // We still keep the localUseGoogleName toggle variable so user's preference persists if present,
                  // but we don't show Connect/Disconnect Google buttons in this dialog.
                  const SizedBox(height: 4),
                  Text('Account type: ${_googleSignedIn ? 'Google (signed)' : (_isGuest ? 'Guest' : 'Local')}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  // Persist choices
                  await prefs.setString('username', u);
                  await prefs.setString('favoriteBrand', fb);
                  await prefs.setString('favoriteModel', fm);
                  await prefs.setBool('use_google_name', localUseGoogleName);

                  if (!mounted) return;
                  setState(() {
                    // If user wants to use Google name and is signed-in, prefer the Google display name
                    _useGoogleName = localUseGoogleName;
                    username = (_googleSignedIn && _useGoogleName && _googleDisplayName != null)
                        ? _googleDisplayName!
                        : u;
                    favoriteBrand = fb;
                    favoriteModel = fm;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Member since formatting
    String memSince = createdAt;
    try {
      final dt = DateTime.parse(createdAt);
      final mns = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      memSince = '${mns[dt.month - 1]} ${dt.year}';
    } catch (_) {}

    final accuracy = questionAttemptCount > 0
        ? ((correctAnswerCount / questionAttemptCount) * 100).round()
        : 0;

    final allAchievements = achievementMap.entries.expand((e) => e.value).toList();
    final unlocked = allAchievements.where((name) => isUnlocked(name)).toList();
    final locked = allAchievements.where((name) => !isUnlocked(name)).toList();
    final topRow = List<String>.from(unlocked.take(3));
    while (topRow.length < 3) topRow.add('');
    final bottomRow = List<String>.from(locked.take(3));
    while (bottomRow.length < 3) bottomRow.add('');

    if (_justUnlockedAchievement != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🏆 Achievement Unlocked: $_justUnlockedAchievement"),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
          ),
        );
      });
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // <-- replaced avatar block with the helper
                  _buildAvatarHeader(memSince),

                  const SizedBox(height: 20),

                  Text(
                    'Track $_currentTrack, Level ${_sessionsCompleted + 1}, '
                    '${_currentLevelGears}/$_requiredGearsForCurrentLevel gear',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _progressValue,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 24),
                  const Text('Your Stats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatCard('Training Completed', trainingCompletedCount.toString(), Icons.fitness_center),
                        _buildStatCard('Correct Answers', correctAnswerCount.toString(), Icons.check_circle),
                        _buildStatCard('Categories Mastered', '$categoriesMastered/8', Icons.category),
                        _buildStatCard('Challenges Attempted', challengesAttemptedCount.toString(), Icons.flag),
                        _buildStatCard('Accuracy Rate', '$accuracy%', Icons.bar_chart),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Achievements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  if (unlocked.isNotEmpty)
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1,
                      children: List.generate(3, (i) {
                        final name = topRow[i];
                        if (name.isEmpty) return const SizedBox();
                        final isLast = i == 2;
                        return GestureDetector(
                          onTap: () {
                            if (isLast) {
                              _showUnlockedAchievementsPopup(context);
                            } else {
                              _showAchievementPopup(context, name);
                            }
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.emoji_events, size: 60, color: Colors.amber),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Text(
                                      name.split("–")[0].trim(),
                                      style: const TextStyle(fontSize: 12),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (isLast)
                                const Positioned(top: 4, right: 4, child: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey)),
                            ],
                          ),
                        );
                      }),
                    ),

                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1,
                    children: List.generate(3, (i) {
                      final name = (i < locked.length) ? locked[i] : '';
                      if (name.isEmpty) return const SizedBox();
                      final isLast = i == 2;
                      return GestureDetector(
                        onTap: () {
                          if (isLast) {
                            _showLockedAchievementsPopup(context);
                          } else {
                            _showAchievementPopup(context, name);
                          }
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.emoji_events, size: 60, color: Colors.grey),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    name.split("–")[0].trim(),
                                    style: const TextStyle(fontSize: 12),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (isLast)
                              const Positioned(top: 4, right: 4, child: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey)),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),

          // "Ensure All Images Are Loaded" — changed to a no-op informational action
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All images are bundled locally in the app — no preload required.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
              child: const Text('Ensure All Images Are Loaded'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: Colors.blue),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

// Simple inline helper
extension Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}