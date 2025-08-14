// ignore_for_file: unused_element, deprecated_member_use

import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/image_service_cache.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

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
  // ignore: unused_field
  int _gearCount = 0;
  int _currentTrack = 1;
  int _sessionsCompleted = 0;
  int _requiredGearsForCurrentLevel = 0;
  int _currentLevelGears = 0;
  double _progressValue = 0.0;

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
      'Mid‑Track Milestone – Finish Level 5 on Track 1.',
      'Track Conqueror – Complete all levels on Track 1 (10/10), Track 2 (20/20) or Track 3 (30/30).',
    ],
    '🔸 Perfect Runs': [
      'Clean Slate – Answer every question in a single level correctly (all green flags).',
      'Zero‑Life Loss – Complete a level without ever losing a life.',
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
      'All‑Rounder – On one day, score ≥ 10/20 in all 8 modules.',
      'Training All‑Star – Earn 20/20 in all 8 modules (at least once each).',
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
        duration: Duration(seconds: 2),
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
      // ✅ Show global snackbar (defined in main.dart)
      final title = _getDisplayNameFromId(id);
      showAchievementSnackBar(title); // 👈 make sure you import main.dart if needed
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
        // Mark as shown so it doesn't appear again
        old.add(id);
        await prefs.setStringList('shownAchievements', old);
        break; // only show one at a time
      }
    }
  }

  bool isAchievementUnlocked(String id) {
    return unlockedAchievementIds.contains(id);
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? 'N/A';
      favoriteBrand = prefs.getString('favoriteBrand') ?? 'N/A';
      favoriteModel = prefs.getString('favoriteModel') ?? 'N/A';
      profilePicIndex = prefs.getInt('profilePictureIndex') ??
          Random().nextInt(6)
            ..let((i) => prefs.setInt('profilePictureIndex', i));
      createdAt = prefs.getString('createdAt') ??
          DateTime.now().toLocal().toIso8601String().split('T').first
            ..let((d) => prefs.setString('createdAt', d));
      _isDataLoaded = true;
    });
    _loadProgressData();
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
          SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
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
          title: Text('All Achievements'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              children: allNames
                  .map((name) => _buildMiniAchievement(name))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Close"),
            )
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
    int maxLevels = currentTrack == 1
        ? 10
        : currentTrack == 2
            ? 20
            : 30;
    int extraGears = gearCount - baseGears;
    int sessions = 0;
    int levelGears = extraGears;
    for (int lvl = 1; lvl <= maxLevels; lvl++) {
      int req = (currentTrack == 3 && lvl >= 20)
          ? 220
          : (30 + (lvl - 1) * 10);
      if (levelGears >= req) {
        levelGears -= req;
        sessions = lvl;
      } else {
        break;
      }
    }
    int reqForCurrent = (currentTrack == 3 && sessions + 1 >= 20)
        ? 220
        : (30 + sessions * 10);
    double prog = reqForCurrent > 0
        ? levelGears / reqForCurrent
        : 0.0;
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
      for (var line in lines) {
        final parts = line.split(',');
        if (parts.length >= 2) {
          final b = parts[0], m = parts[1];
          brands.add(b);
          map.putIfAbsent(b, () => {}).add(m);
        }
      }
      setState(() {
        _brandOptions = brands.toList()..sort();
        _brandToModels = {
          for (var b in _brandOptions) b: map[b]!.toList()..sort()
        };
        _isCarDataLoaded = true;
      });
    } catch (_) {
      setState(() => _isCarDataLoaded = false);
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  String _capitalizeEachWord(String input) {
    return input
        .split(RegExp(r'\s+'))
        .map((word) =>
            word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '')
        .join();
  }

  String _formatImageName(String brand, String model) {
    String input = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return input
        .split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
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
        title: Text("Unlocked Achievements"),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            children: unlocked.map((name) => _buildMiniAchievement(name)).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Close")),
        ],
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
        title: Text("Locked Achievements"),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            children: locked.map((name) => _buildMiniAchievement(name)).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Close")),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    String u = username;
    if (!_isCarDataLoaded) return;
    String fb = favoriteBrand != 'N/A' && favoriteBrand.isNotEmpty
        ? favoriteBrand
        : _brandOptions.first;
    String fm = favoriteModel != 'N/A' && favoriteModel.isNotEmpty
        ? favoriteModel
        : _brandToModels[fb]!.first;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: TextEditingController(text: u),
                  decoration: InputDecoration(labelText: 'Username'),
                  onChanged: (v) => u = v,
                ),
                DropdownButtonFormField<String>(
                  value: fb,
                  decoration: InputDecoration(labelText: 'Favorite Brand'),
                  items: _brandOptions
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) {
                    setSt(() {
                      fb = v!;
                      fm = _brandToModels[fb]!.first;
                    });
                  },
                ),
                DropdownButtonFormField<String>(
                  value: fm,
                  decoration: InputDecoration(labelText: 'Favorite Model'),
                  items: _brandToModels[fb]!
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setSt(() => fm = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('username', u);
                await prefs.setString('favoriteBrand', fb);
                await prefs.setString('favoriteModel', fm);
                setState(() {
                  username = u;
                  favoriteBrand = fb;
                  favoriteModel = fm;
                });
                Navigator.pop(ctx);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkAndLoadImages() async {
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
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
            .join();

        for (int i = 0; i <= 5; i++) {
          files.add('$fileBase$i.webp');
        }
      }
    }

    final missingFiles = <String>[];
    for (var file in files) {
      final isCached = await ImageCacheService.instance.isImageCached(file);
      if (!isCached) {
        missingFiles.add(file);
      }
    }

    if (missingFiles.isEmpty) {
      // All images are already cached
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("All images are already cached."),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Load missing images
      for (var file in missingFiles) {
        try {
          await ImageCacheService.instance
              .imageProvider(file)
              .resolve(const ImageConfiguration());
        } catch (_) {
          // ignore failures
        }
      }

      // Show a message indicating that images have been loaded
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("All images have been successfully loaded."),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataLoaded) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
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

    // Achievement rows (3 per row)
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
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
          ),
        );
      });
    }

    // Compute the sanitized file-base for your car image
    final fileBase = _formatImageName(favoriteBrand, favoriteModel);

    // Build a CircleAvatar that pulls from Firebase (with spinner & fallback)
    Widget avatarWidget = CircleAvatar(
      radius: 50,
      backgroundColor: Colors.transparent,
      child: ClipOval(
        child: Image(
          image: ImageCacheService.instance.imageProvider(
            '${fileBase}${profilePicIndex}.webp',
          ),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (ctx, error, st) => Image.asset(
            'assets/profile/avatar.png',
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 32),
                  Center(
                    child: Column(
                      children: [
                        avatarWidget,
                        SizedBox(height: 10),
                        Text(
                          username,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Member since: $memSince',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_fire_department, color: Colors.orange),
                            SizedBox(width: 5),
                            Text(
                              'Streak: $dailyStreak Days',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Track $_currentTrack, Level ${_sessionsCompleted + 1}, '
                    '${_currentLevelGears}/$_requiredGearsForCurrentLevel gear',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _progressValue,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Your Stats',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatCard('Training Completed',
                            trainingCompletedCount.toString(), Icons.fitness_center),
                        _buildStatCard('Correct Answers',
                            correctAnswerCount.toString(), Icons.check_circle),
                        _buildStatCard('Categories Mastered',
                            '$categoriesMastered/8', Icons.category),
                        _buildStatCard('Challenges Attempted',
                            challengesAttemptedCount.toString(), Icons.flag),
                        _buildStatCard('Accuracy Rate',
                            '$accuracy%', Icons.bar_chart),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Achievements',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  // Top Row: Unlocked Achievements
                  if (unlocked.isNotEmpty)
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      childAspectRatio: 1,
                      children: List.generate(3, (i) {
                        final name = topRow[i];
                        if (name.isEmpty) return SizedBox(); // blank tile
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
                                  Icon(Icons.emoji_events, size: 60, color: Colors.amber),
                                  SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Text(
                                      name.split("–")[0].trim(),
                                      style: TextStyle(fontSize: 12),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (isLast)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                                ),
                            ],
                          ),
                        );
                      }),
                    ),
                  // Bottom Row: Locked Achievements
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    childAspectRatio: 1,
                    children: List.generate(3, (i) {
                      final name = bottomRow[i];
                      if (name.isEmpty) return SizedBox();
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
                                Icon(Icons.emoji_events,
                                    size: 60, color: Colors.grey),
                                SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    name.split("–")[0].trim(),
                                    style: TextStyle(fontSize: 12),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (isLast)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Icon(Icons.arrow_forward_ios,
                                    size: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          // Add the button to ensure all images are loaded at the very bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _checkAndLoadImages,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 40), // Full width button
              ),
              child: Text('Ensure All Images Are Loaded'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: Colors.blue),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

// Simple inline helper
extension Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
