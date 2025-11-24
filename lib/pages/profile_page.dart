// lib/pages/profile_page.dart
// ignore_for_file: unused_element, deprecated_member_use, unused_field

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/analytics_service.dart';
import '../services/language_service.dart';
import '../services/tutorial_service.dart';
import '../services/leaderboard_service.dart';
import '../widgets/country_picker_dialog.dart';

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
  String _country = 'XX'; // ISO country code
  final LeaderboardService _leaderboardService = LeaderboardService();

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
  bool _tabIntroShown = false;
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

  Map<String, List<String>> _getAchievementMap(BuildContext context) {
    return {
      'achievements.categories.trackProgression'.tr(): [
        'achievements.list.firstFlag'.tr(),
        'achievements.list.levelComplete'.tr(),
        'achievements.list.midTrackMilestone'.tr(),
        'achievements.list.trackConqueror'.tr(),
      ],
      'achievements.categories.perfectRuns'.tr(): [
        'achievements.list.cleanSlate'.tr(),
        'achievements.list.zeroLifeLoss'.tr(),
        'achievements.list.swiftRacer'.tr(),
      ],
      'achievements.categories.gearMastery'.tr(): [
        'achievements.list.gearRookie'.tr(),
        'achievements.list.gearGrinder'.tr(),
        'achievements.list.gearTycoon'.tr(),
      ],
      'achievements.categories.gateTrackUnlocks'.tr(): [
        'achievements.list.gateOpener'.tr(),
        'achievements.list.trackUnlockerI'.tr(),
        'achievements.list.trackUnlockerII'.tr(),
      ],
      'achievements.categories.comebackCorrection'.tr(): [
        'achievements.list.secondChance'.tr(),
        'achievements.list.perseverance'.tr(),
      ],
      'achievements.categories.trainingAchievements'.tr(): [
        'achievements.list.trainingInitiate'.tr(),
        'achievements.list.trainingRegular'.tr(),
        'achievements.list.trainingVeteran'.tr(),
        'achievements.list.quizStreak'.tr(),
        'achievements.list.sharpshooter'.tr(),
        'achievements.list.allRounder'.tr(),
        'achievements.list.trainingAllStar'.tr(),
      ],
    };
  }

  @override
  void initState() {
    super.initState();

    // Track screen view
    AnalyticsService.instance.logProfileViewed();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNewAchievement();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTabIntro());
    _loadProfileData();
    _loadCarData();
    _loadDailyStreak();
    _loadTrainingCompletedCount();
    _loadCorrectAnswerCount();
    _loadCategoriesMasteredCount();
    _loadChallengesAttemptedCount();
    _loadQuestionAttemptCount();
    _loadUnlockedAchievements();
    _loadCountry();
  }

  List<String> unlockedAchievementIds = [];

  Future<void> _loadUnlockedAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      unlockedAchievementIds = prefs.getStringList('unlockedAchievements') ?? [];
    });
  }

  Future<void> _loadCountry() async {
    final savedCountry = await _leaderboardService.getSavedCountry();
    if (savedCountry != null && mounted) {
      setState(() {
        _country = savedCountry;
      });
    }
  }

  String _getCountryFlag(String countryCode) {
    if (countryCode == 'XX' || countryCode.length != 2) {
      return '🏁';
    }
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  void showAchievementSnackBar(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('profile.achievementUnlocked'.tr(namedArgs: {'title': title})),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }

  Future<void> _maybeShowTabIntro() async {
    if (_tabIntroShown) return;
    final tutorialService = TutorialService.instance;
    final stage = await tutorialService.getTutorialStage();
    if (stage != TutorialStage.tabsReady) return;
    if (await tutorialService.hasShownTabIntro('profile')) return;
    await tutorialService.markTabIntroShown('profile');
    _tabIntroShown = true;
    if (!mounted) return;
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
    for (final entry in _getAchievementMap(context).entries) {
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
            storedUsername.startsWith('unnamed'));

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
            ? 'unnamed_carenthusiast'
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
        ? Chip(label: Text(_googleEmail ?? 'profile.googleUser'.tr(), style: const TextStyle(color: Colors.white70)), avatar: const Icon(Icons.check_circle, size: 16, color: Colors.green), backgroundColor: const Color(0xFF1E1E1E))
        : (_isGuest ? Chip(label: Text('profile.guest'.tr(), style: const TextStyle(color: Colors.white70)), backgroundColor: const Color(0xFF1E1E1E)) : const SizedBox.shrink());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2A2A2A),
            const Color(0xFF1E1E1E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: _showAccountDialog,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.transparent,
                    child: avatarImage,
                  ),
                ),
                Positioned(
                  top: -6,
                  left: -6,
                  child: Material(
                    color: const Color(0xFF1A1A1A),
                    shape: const CircleBorder(),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.language, size: 18, color: Colors.white70),
                      tooltip: 'language.title'.tr(),
                      onPressed: _showLanguageSelector,
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: Material(
                    color: const Color(0xFF1A1A1A),
                    shape: const CircleBorder(),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.edit, size: 18, color: Colors.white70),
                      tooltip: 'profile.editProfileTooltip'.tr(),
                      onPressed: _showEditProfileDialog,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            GestureDetector(
              onTap: _showAccountDialog,
              child: Column(
                children: [
                  Text(displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('profile.memberSince'.tr(namedArgs: {'date': memSince}), style: const TextStyle(fontSize: 14, color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            statusChip,
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _showStreakPopup,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'profile.streakDays'.tr(namedArgs: {'count': dailyStreak.toString()}),
                      style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.touch_app, size: 14, color: Colors.white38),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        final allNames = _getAchievementMap(context).entries.expand((e) => e.value).toList();
        return AlertDialog(
          title: Text('profile.allAchievements'.tr()),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              children: allNames.map((name) => _buildMiniAchievement(name)).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.close'.tr()))
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
      SnackBar(content: Text('profile.appleIdNotice'.tr())),
    );
    return;
  }
  // --- END adapted flow

  // --- START: language selector dialog
  void _showLanguageSelector() {
    final currentLang = LanguageService.getCurrentLanguageCode(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text('language.selectLanguage'.tr(), style: const TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: LanguageService.availableLanguages.length,
              itemBuilder: (context, index) {
                final langCode = LanguageService.availableLanguages.keys.elementAt(index);
                final langName = LanguageService.availableLanguages[langCode]!;
                final flag = LanguageService.getLanguageFlag(langCode);
                final isSelected = langCode == currentLang;

                return ListTile(
                  leading: Text(flag, style: const TextStyle(fontSize: 24)),
                  title: Text(langName, style: const TextStyle(color: Colors.white)),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await LanguageService.changeLanguage(context, langCode);
                      if (!mounted) return;
                      final languageName = LanguageService.getLanguageName(langCode);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('language.languageChanged'.tr(namedArgs: {'language': languageName}))),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('language.languageChangeFailed'.tr())),
                      );
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('common.close'.tr()),
            ),
          ],
        );
      },
    );
  }
  // --- END language selector dialog

  // --- START: account dialog (simplified, no Google disconnect button)
  void _showAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('profile.account'.tr()),
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
                _googleSignedIn ? 'profile.signedInWithGoogle'.tr() : (_isGuest ? 'profile.guestAccount'.tr() : 'profile.localProfile'.tr()),
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
          actions: [
            // Removed Google disconnect button entirely to have a clear ground for Apple ID integration.
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('common.close'.tr())),
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
      await prefs.setString('username', username.isEmpty ? 'unnamed_carenthusiast' : username);
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
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('common.ok'.tr()))],
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
    final unlocked = _getAchievementMap(context).entries
        .expand((e) => e.value)
        .where((name) => isUnlocked(name))
        .toList();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('profile.unlockedAchievements'.tr()),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            children: unlocked.map((name) => _buildMiniAchievement(name)).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('common.close'.tr()))],
      ),
    );
  }

  void _showLockedAchievementsPopup(BuildContext context) {
    final locked = _getAchievementMap(context).entries
        .expand((e) => e.value)
        .where((name) => !isUnlocked(name))
        .toList();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('profile.lockedAchievements'.tr()),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            children: locked.map((name) => _buildMiniAchievement(name)).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('common.close'.tr()))],
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
      username = prefs.getString('username') ?? 'unnamed_carenthusiast';
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
    String country = _country;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          // Local copies inside dialog
          bool localUseGoogleName = _useGoogleName;

          return AlertDialog(
            title: Text('profile.editProfile'.tr()),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  // Username field
                  TextField(
                    controller: TextEditingController(text: u),
                    style: const TextStyle(color: Colors.white70),
                    decoration: InputDecoration(
                      labelText: tr('profile.labelUsername'),
                      labelStyle: const TextStyle(color: Colors.white70),
                    ),
                    onChanged: (v) => u = v,
                  ),
                  const SizedBox(height: 12),

                  // Favorite Brand dropdown
                  DropdownButtonFormField<String>(
                    value: fb,
                    style: const TextStyle(color: Colors.white70),
                    decoration: InputDecoration(
                      labelText: tr('profile.labelFavoriteBrand'),
                      labelStyle: const TextStyle(color: Colors.white70),
                    ),
                    dropdownColor: const Color(0xFF1E1E1E),
                    items: _brandOptions.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(color: Colors.white70)))).toList(),
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
                    style: const TextStyle(color: Colors.white70),
                    decoration: InputDecoration(
                      labelText: tr('profile.labelFavoriteModel'),
                      labelStyle: const TextStyle(color: Colors.white70),
                    ),
                    dropdownColor: const Color(0xFF1E1E1E),
                    items: _brandToModels[fb]!.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(color: Colors.white70)))).toList(),
                    onChanged: (v) => setSt(() => fm = v!),
                  ),
                  const SizedBox(height: 12),

                  // Country selection
                  InkWell(
                    onTap: () async {
                      final selectedCountry = await showDialog<String>(
                        context: ctx,
                        builder: (dialogCtx) => CountryPickerDialog(initialCountry: country),
                      );
                      if (selectedCountry != null) {
                        setSt(() {
                          country = selectedCountry;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                _getCountryFlag(country),
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                country == 'XX' ? 'Select Country' : 'Country',
                                style: const TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // NOTE: Google-related UI removed here to provide a clean ground for Apple ID integration.
                  // We still keep the localUseGoogleName toggle variable so user's preference persists if present,
                  // but we don't show Connect/Disconnect Google buttons in this dialog.
                  const SizedBox(height: 4),
                  Text('${'profile.accountType'.tr()}: ${_googleSignedIn ? 'profile.googleSigned'.tr() : (_isGuest ? 'profile.guest'.tr() : 'profile.localProfile'.tr())}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
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
                  await _leaderboardService.saveCountryLocally(country);

                  if (!mounted) return;
                  setState(() {
                    // If user wants to use Google name and is signed-in, prefer the Google display name
                    _useGoogleName = localUseGoogleName;
                    username = (_googleSignedIn && _useGoogleName && _googleDisplayName != null)
                        ? _googleDisplayName!
                        : u;
                    favoriteBrand = fb;
                    favoriteModel = fm;
                    _country = country;
                  });
                  Navigator.pop(ctx);
                },
                child: Text('common.save'.tr()),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Member since formatting
    String memSince = createdAt;
    try {
      final dt = DateTime.parse(createdAt);
      final mns = [
        tr('profile.monthJanuary'), tr('profile.monthFebruary'), tr('profile.monthMarch'),
        tr('profile.monthApril'), tr('profile.monthMay'), tr('profile.monthJune'),
        tr('profile.monthJuly'), tr('profile.monthAugust'), tr('profile.monthSeptember'),
        tr('profile.monthOctober'), tr('profile.monthNovember'), tr('profile.monthDecember')
      ];
      memSince = '${mns[dt.month - 1]} ${dt.year}';
    } catch (_) {}

    final accuracy = questionAttemptCount > 0
        ? ((correctAnswerCount / questionAttemptCount) * 100).round()
        : 0;

    final allAchievements = _getAchievementMap(context).entries.expand((e) => e.value).toList();
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
            content: Text('profile.achievementUnlocked'.tr(namedArgs: {'title': _justUnlockedAchievement ?? ''})),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // Profile Header Card
            _buildAvatarHeader(memSince),

            const SizedBox(height: 20),

            // Track Progress Card
            _buildProgressCard(),

            const SizedBox(height: 20),

            // Knowledge Mastered Section
            _buildKnowledgeMasteredSection(),

            const SizedBox(height: 20),

            // Stats Section
            _buildStatsSection(accuracy),

            const SizedBox(height: 20),

            // Achievements Section
            _buildAchievementsSection(unlocked, locked, topRow),

            const SizedBox(height: 20),

            // "Ensure All Images Are Loaded" — moved inside scroll
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('profile.imagesPreloaded'.tr()),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                backgroundColor: const Color(0xFF2A2A2A),
                foregroundColor: Colors.white,
              ),
              child: Text('profile.ensureImagesLoaded'.tr()),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'profile.trackLevelProgress'.tr(namedArgs: {
              'track': _currentTrack.toString(),
              'level': (_sessionsCompleted + 1).toString(),
              'current': _currentLevelGears.toString(),
              'required': _requiredGearsForCurrentLevel.toString()
            }),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _showGearProgressPopup,
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: _progressValue,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                      strokeWidth: 12,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(_progressValue * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$_currentLevelGears/$_requiredGearsForCurrentLevel',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const Positioned(
                    bottom: 5,
                    child: Icon(Icons.touch_app, size: 16, color: Colors.white38),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.settings, color: Colors.amber, size: 20),
              const SizedBox(width: 6),
              Text(
                'profileProgress.totalGears'.tr(namedArgs: {'count': _gearCount.toString()}),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGearProgressPopup() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.settings, color: Colors.amber, size: 28),
              const SizedBox(width: 12),
              Text(
                'profileProgress.totalGears'.tr(namedArgs: {'count': _gearCount.toString()}),
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTrackCard(1, 'profileProgress.trackNames.beginner'.tr(), 0, 750, const Color(0xFF2196F3)),
                  const SizedBox(height: 12),
                  _buildTrackCard(2, 'profileProgress.trackNames.intermediate'.tr(), 750, 3250, const Color(0xFFFF9800)),
                  const SizedBox(height: 12),
                  _buildTrackCard(3, 'profileProgress.trackNames.advanced'.tr(), 3250, 999999, const Color(0xFF9C27B0)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('common.close'.tr(), style: const TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrackCard(int trackNumber, String trackName, int minGears, int maxGears, Color color) {
    final isCurrentTrack = trackNumber == _currentTrack;
    final isUnlocked = _gearCount >= minGears;
    final isCompleted = _gearCount >= maxGears && maxGears < 999999;

    int levelsInTrack = trackNumber == 1 ? 10 : trackNumber == 2 ? 20 : 30;
    int currentLevel = 0;
    int gearsInTrack = max(0, min(_gearCount, maxGears) - minGears);

    if (isUnlocked) {
      int remainingGears = gearsInTrack;
      for (int lvl = 1; lvl <= levelsInTrack; lvl++) {
        int req = (trackNumber == 3 && lvl >= 20) ? 220 : (30 + (lvl - 1) * 10);
        if (remainingGears >= req) {
          remainingGears -= req;
          currentLevel = lvl;
        } else {
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isCurrentTrack
            ? LinearGradient(
                colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isCurrentTrack ? null : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentTrack ? color : Colors.grey.withOpacity(0.2),
          width: isCurrentTrack ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : (isUnlocked ? Icons.lock_open : Icons.lock),
                    color: isCompleted ? Colors.green : (isUnlocked ? color : Colors.grey),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'profileProgress.trackCard.trackLabel'.tr(namedArgs: {'number': trackNumber.toString(), 'name': trackName}),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isUnlocked ? Colors.white : Colors.grey,
                    ),
                  ),
                ],
              ),
              if (isCurrentTrack)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'profileProgress.trackCard.current'.tr(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            maxGears < 999999
              ? 'profileProgress.trackCard.gearsRange'.tr(namedArgs: {'min': minGears.toString(), 'max': maxGears.toString()})
              : 'profileProgress.trackCard.gearsPlusRange'.tr(namedArgs: {'min': minGears.toString()}),
            style: TextStyle(fontSize: 12, color: isUnlocked ? Colors.white70 : Colors.grey),
          ),
          if (isUnlocked && !isCompleted) ...[
            const SizedBox(height: 12),
            Text(
              'profileProgress.trackCard.levelProgress'.tr(namedArgs: {'current': currentLevel.toString(), 'total': levelsInTrack.toString()}),
              style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: currentLevel / levelsInTrack,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
            const SizedBox(height: 4),
            Text(
              'profileProgress.trackCard.gearsCollected'.tr(namedArgs: {'count': gearsInTrack.toString()}),
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
          if (isCompleted) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                const SizedBox(width: 6),
                Text(
                  'profileProgress.trackCard.trackCompleted'.tr(),
                  style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showStreakPopup() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
              const SizedBox(width: 12),
              Text(
                'profileProgress.streak.title'.tr(),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B00), Color(0xFFFF9500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$dailyStreak',
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          dailyStreak == 1 ? 'profileProgress.streak.dayStreak'.tr() : 'profileProgress.streak.daysStreak'.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildStreakStatRow(Icons.trending_up, 'profileProgress.streak.currentStreak'.tr(), 'profileProgress.streak.streakDays'.tr(namedArgs: {'count': dailyStreak.toString()})),
                  const Divider(color: Colors.white24),
                  _buildStreakStatRow(Icons.emoji_events, 'profileProgress.streak.longestStreak'.tr(), 'profileProgress.streak.streakDays'.tr(namedArgs: {'count': dailyStreak.toString()})),
                  const Divider(color: Colors.white24),
                  _buildStreakStatRow(Icons.calendar_today, 'profileProgress.streak.totalActiveDays'.tr(), dailyStreak.toString()),
                  const SizedBox(height: 20),
                  if (dailyStreak >= 7)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.celebration, color: Colors.amber, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              dailyStreak >= 30
                                  ? 'profileProgress.streak.encouragement.onFire'.tr()
                                  : 'profileProgress.streak.encouragement.greatJob'.tr(),
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              dailyStreak == 0
                                  ? 'profileProgress.streak.encouragement.startToday'.tr()
                                  : 'profileProgress.streak.encouragement.keepGoing'.tr(namedArgs: {'remaining': (7 - dailyStreak).toString()}),
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('common.close'.tr(), style: const TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStreakStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(int accuracy) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'profile.yourStats'.tr(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                children: [
                  _buildModernStatCard('profile.trainingCompleted'.tr(), trainingCompletedCount.toString(), Icons.fitness_center, const Color(0xFF2196F3)),
                  const SizedBox(width: 12),
                  _buildModernStatCard('profile.correctAnswers'.tr(), correctAnswerCount.toString(), Icons.check_circle, const Color(0xFF4CAF50)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildModernStatCard('profile.categoriesMasteredLabel'.tr(), '$categoriesMastered/8', Icons.category, const Color(0xFFFF9800)),
                  const SizedBox(width: 12),
                  _buildModernStatCard('profile.challengesAttemptedLabel'.tr(), challengesAttemptedCount.toString(), Icons.flag, const Color(0xFFE91E63)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildModernStatCard('profile.accuracyRate'.tr(), '$accuracy%', Icons.bar_chart, const Color(0xFF9C27B0)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKnowledgeMasteredSection() {
    final categories = {
      'Brand': {'icon': Icons.local_offer},
      'Model': {'icon': Icons.directions_car},
      'Origin': {'icon': Icons.flag},
      'Engine Type': {'icon': Icons.settings},
      'Max Speed': {'icon': Icons.speed},
      'Acceleration': {'icon': Icons.flash_on},
      'Power': {'icon': Icons.bolt},
      'Special Feature': {'icon': Icons.star},
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'profileProgress.knowledge.title'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                '$categoriesMastered/8',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...categories.entries.map((entry) {
            final icon = entry.value['icon'] as IconData;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildKnowledgeRow(entry.key, icon),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildKnowledgeRow(String title, IconData icon) {
    // Map English category names to translation keys
    final translationKeyMap = {
      'Brand': 'profileProgress.knowledge.categories.brand',
      'Model': 'profileProgress.knowledge.categories.model',
      'Origin': 'profileProgress.knowledge.categories.origin',
      'Engine Type': 'profileProgress.knowledge.categories.engineType',
      'Max Speed': 'profileProgress.knowledge.categories.maxSpeed',
      'Acceleration': 'profileProgress.knowledge.categories.acceleration',
      'Power': 'profileProgress.knowledge.categories.power',
      'Special Feature': 'profileProgress.knowledge.categories.specialFeature',
    };

    final translatedTitle = translationKeyMap[title]?.tr() ?? title;

    return FutureBuilder<int>(
      future: _getCategoryScore(title),
      builder: (context, snapshot) {
        final score = snapshot.data ?? 0;
        final progress = score / 20.0;
        final isMastered = score == 20;

        return Column(
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: isMastered ? Colors.amber : Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    translatedTitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMastered ? Colors.white : Colors.white70,
                      fontWeight: isMastered ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (isMastered)
                  const Icon(Icons.emoji_events, size: 20, color: Colors.amber)
                else
                  Text(
                    'profileProgress.knowledge.scoreFormat'.tr(namedArgs: {'score': score.toString()}),
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isMastered ? Colors.green : (score > 0 ? Colors.orange : Colors.grey[700]!),
                ),
                minHeight: 6,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<int> _getCategoryScore(String categoryName) async {
    final prefs = await SharedPreferences.getInstance();
    final keyMap = {
      'Brand': 'best_Brand',
      'Model': 'best_Model',
      'Origin': 'best_Origin',
      'Engine Type': 'best_EngineType',
      'Max Speed': 'best_MaxSpeed',
      'Acceleration': 'best_Acceleration',
      'Power': 'best_Power',
      'Special Feature': 'best_SpecialFeature',
    };

    final key = keyMap[categoryName];
    if (key == null) return 0;

    final value = prefs.getString(key);
    if (value == null) return 0;

    final match = RegExp(r'(\d+)/20').firstMatch(value);
    if (match != null) {
      return int.parse(match.group(1) ?? '0');
    }

    return 0;
  }

  Widget _buildAchievementsSection(List<String> unlocked, List<String> locked, List<String> topRow) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'profile.achievements'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                '${unlocked.length}/${unlocked.length + locked.length}',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (unlocked.isNotEmpty) ...[
            Text(
              'profileProgress.achievements.unlocked'.tr(),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.amber[400]),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
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
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.emoji_events, size: 40, color: Colors.yellow[700]!),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                name.split("–")[0].trim(),
                                style: const TextStyle(fontSize: 11, color: Colors.white),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (isLast)
                          const Positioned(top: 4, right: 4, child: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
          if (locked.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'profileProgress.achievements.locked'.tr(),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
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
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.emoji_events, size: 40, color: Colors.grey),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                name.split("–")[0].trim(),
                                style: const TextStyle(fontSize: 11, color: Colors.white54),
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
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

// Simple inline helper
extension Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
