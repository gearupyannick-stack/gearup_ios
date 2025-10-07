import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/welcome_page.dart';
import 'pages/home_page.dart';
import 'pages/training_page.dart';
import 'pages/library_page.dart';
import 'pages/profile_page.dart';
import 'storage/lives_storage.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pages/race_page.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool hasProfile = prefs.getBool('hasProfile') ?? false;

  LivesStorage livesStorage = LivesStorage();
  int savedLives = await livesStorage.readLives();

  runApp(CarLearningApp(
    hasProfile: hasProfile,
    initialLives: savedLives,
    livesStorage: livesStorage,
  ));
}

class CarLearningApp extends StatelessWidget {
  final bool hasProfile;
  final int initialLives;
  final LivesStorage livesStorage;

  CarLearningApp({
    required this.hasProfile,
    required this.initialLives,
    required this.livesStorage,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GearUp',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Color(0xFF121212),
        primaryColor: Color(0xFF3D0000),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF3D0000),
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF3D0000),
            foregroundColor: Colors.white,
            textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            minimumSize: Size(double.infinity, 50),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: Colors.redAccent,
          unselectedItemColor: Colors.white70,
        ),
        cardColor: Color(0xFF1E1E1E),
        textTheme: TextTheme(
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.white70),
        ),
      ),
      home: hasProfile
          ? MainPage(
              initialLives: initialLives,
              livesStorage: livesStorage,
            )
          : WelcomePage(),
    );
  }
}

class MainPage extends StatefulWidget {
  final int initialLives;
  final LivesStorage livesStorage;

  const MainPage({
    required this.initialLives,
    required this.livesStorage,
  });

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // ── CONFIG ─────────────────────────────────────────
  static const int _maxLives = 5;
  static const int _refillInterval = 600; // seconds per life

  // ── STATE ──────────────────────────────────────────
  int _currentIndex = 0;
  int gearCount = 0;
  late int lives;
  Timer? _lifeTimer;
  bool _hasShownRatePopup = false;
  final ValueNotifier<int> _lifeTimerRemaining = ValueNotifier<int>(0);

  // ── KEYS & PAGES ───────────────────────────────────
  final GlobalKey _gearKey        = GlobalKey();
  final GlobalKey _streakKey      = GlobalKey();
  final GlobalKey _livesKey       = GlobalKey();
  final GlobalKey _firstFlagKey   = GlobalKey();
  final GlobalKey _tabHomeKey     = GlobalKey();
  final GlobalKey _tabTrainingKey = GlobalKey();
  final GlobalKey _tabRaceKey     = GlobalKey(); 
  final GlobalKey _tabLibraryKey  = GlobalKey();
  final GlobalKey _tabProfileKey  = GlobalKey();
  final List<Widget> _pages = [];

  // ── STREAK & DAILY ─────────────────────────────────
  int dayStreak = 0;
  String streakTitle = "Newbie";
  bool challengesCompletedToday = false;

  String get _heartImagePath => 'assets/home/heart$lives.png';

  @override
  void initState() {
    super.initState();
    // 1) seed lives from storage
    lives = widget.initialLives;
    // 2) catch up (compute new lives + nextDueTime)
    _catchUpLives();
    // 3) build pages
    _pages.addAll([
      HomePage(
        currentLives: lives,
        getLives: () => lives,
        livesStorage: widget.livesStorage,
        onChallengeFail: _onChallengeFail,
        onGearUpdate: (c) => setState(() => gearCount = c),
        recordChallengeCompletion: recordChallengeCompletion,
        firstFlagKey: _firstFlagKey,
      ),
      TrainingPage(
        onLifeWon: () async {
          int newLives = await widget.livesStorage.readLives();
          setState(() => lives = newLives);
        },
        recordChallengeCompletion: recordChallengeCompletion,
      ),
      const RacePage(), 
      const LibraryPage(),
      const ProfilePage(),
    ]);
    // 4) other inits
    _loadDayStreak();
    _initializeChallengeStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  /// Uses the stored clock to refill lives & compute remaining time.
  Future<void> _catchUpLives() async {
    final prefs = await SharedPreferences.getInstance();
    final now   = DateTime.now();

    // Read next due time (when the *next* life*should* be earned)
    final nextDueStr = prefs.getString('nextLifeDueTime');
    if (lives < _maxLives && nextDueStr != null) {
      DateTime nextDue = DateTime.parse(nextDueStr);
      if (now.isAfter(nextDue)) {
        // How many intervals have passed since nextDue?
        final secondsPast = now.difference(nextDue).inSeconds;
        final livesGained = 1 + (secondsPast ~/ _refillInterval);
        lives = (lives + livesGained).clamp(0, _maxLives);
        await widget.livesStorage.writeLives(lives);

        // Compute the NEW nextDueTime
        DateTime newNextDue = nextDue
            .add(Duration(seconds: livesGained * _refillInterval));
        if (lives >= _maxLives) {
          // No more timer when full
          prefs.remove('nextLifeDueTime');
          _lifeTimerRemaining.value = 0;
          setState(() {});
          return;
        } else {
          await prefs.setString(
            'nextLifeDueTime',
            newNextDue.toIso8601String(),
          );
          _lifeTimerRemaining.value = newNextDue.difference(now).inSeconds;
        }
      } else {
        // nextDue is still in the future
        _lifeTimerRemaining.value = nextDue.difference(now).inSeconds;
      }
    } else {
      // Either full lives or no saved due time
      if (lives < _maxLives) {
        // schedule first due from now
        DateTime newNextDue = now.add(Duration(seconds: _refillInterval));
        await prefs.setString(
          'nextLifeDueTime',
          newNextDue.toIso8601String(),
        );
        _lifeTimerRemaining.value = _refillInterval;
      } else {
        _lifeTimerRemaining.value = 0;
        prefs.remove('nextLifeDueTime');
      }
    }

    // If we need a ticking timer, start it now
    if (lives < _maxLives && _lifeTimer == null) {
      _startLifeTimer();
    }
    setState(() {});
  }

  /// Ticks down once per second, and when it hits 0, awards a life exactly on schedule.
  void _startLifeTimer() {
    _lifeTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_lifeTimerRemaining.value > 0) {
        _lifeTimerRemaining.value--;
      } else if (lives < _maxLives) {
        // award life
        setState(() => lives++);
        await widget.livesStorage.writeLives(lives);

        final prefs = await SharedPreferences.getInstance();
        if (lives < _maxLives) {
          // schedule next
          DateTime nextDue = DateTime.now()
              .add(Duration(seconds: _refillInterval));
          await prefs.setString(
            'nextLifeDueTime',
            nextDue.toIso8601String(),
          );
          _lifeTimerRemaining.value = _refillInterval;
        } else {
          // reached max
          prefs.remove('nextLifeDueTime');
          _lifeTimer?.cancel();
          _lifeTimer = null;
          _lifeTimerRemaining.value = 0;
        }
      }
    });
  }

  /// On challenge failure: decrement, persist, start timer if needed,
  /// then show the 5-star popup if it’s the first time at zero.
  /// Called whenever the user fails a challenge.
  Future<void> _onChallengeFail() async {
    // 1) Decrement & persist
    setState(() {
      if (lives > 0) lives--;
    });
    await widget.livesStorage.writeLives(lives);

    // 2) If we’ve dropped below max, schedule the next life *relative to now*
    if (lives < _maxLives) {
      final prefs = await SharedPreferences.getInstance();
      // Compute exactly when the next life is due
      final nextDue = DateTime.now().add(Duration(seconds: _refillInterval));
      // Persist that timestamp
      await prefs.setString(
        'nextLifeDueTime',
        nextDue.toIso8601String(),
      );
      // Reset our on-screen countdown
      _lifeTimerRemaining.value = nextDue.difference(DateTime.now()).inSeconds;

      // (Re)start the in‐memory ticker if it isn’t already running
      if (_lifeTimer == null) {
        _startLifeTimer();
      }
    }

    // 3) On first hit of zero lives, show the 5-star popup
    if (lives == 0 && !_hasShownRatePopup) {
      _hasShownRatePopup = true;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('You have lost all of your lives!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'If you like this app, rate it 5 stars to get all your lives back!',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () async {
                    // refill immediately
                    setState(() => lives = _maxLives);
                    await widget.livesStorage.writeLives(lives);
                    // remove pending due time so we don't auto-add extra lives
                    final prefs = await SharedPreferences.getInstance();
                    prefs.remove('nextLifeDueTime');

                    Navigator.of(ctx).pop();
                    final uri = Uri.parse(
                      'https://play.google.com/store/apps/details?id=com.gearup.app'
                    );
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: const Text(
                    'Give us 5 stars review',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          actionsPadding: const EdgeInsets.only(bottom: 8, right: 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('No thanks'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _maybeShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('hasSeenTutorial') ?? false) return;

    _showTutorial();
    await prefs.setBool('hasSeenTutorial', true);
  }

  void _showTutorial() {
    // screen dimensions for centering text
    final size = MediaQuery.of(context).size;
    final middleTop = size.height * 0.5 - 50;
    final sidePadding = size.width * 0.1;
    final skipYOffset = (50 / size.height) * 2.0; // Alignment y goes from -1 to 1

    final targets = <TargetFocus>[
      TargetFocus(
        identify: "Gear",
        keyTarget: _gearKey,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: middleTop,
              left: sidePadding,
              right: sidePadding,
            ),
            child: Container(
              alignment: Alignment.center,
              child: Text(
                "Here you earn gears as you complete levels!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Streak",
        keyTarget: _streakKey,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: middleTop,
              left: sidePadding,
              right: sidePadding,
            ),
            child: Container(
              alignment: Alignment.center,
              child: Text(
                "This is your daily streak—complete 5 challenges to keep it going!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Lives",
        keyTarget: _livesKey,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: middleTop,
              left: sidePadding,
              right: sidePadding,
            ),
            child: Container(
              alignment: Alignment.center,
              child: Text(
                "Tap here to see how many lives you have left, and when you’ll get the next one.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "FirstFlag",
        keyTarget: _firstFlagKey,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: middleTop,
              left: sidePadding,
              right: sidePadding,
            ),
            child: Container(
              alignment: Alignment.center,
              child: Text(
                "Tap this first flag to start your race!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "HomeTab",
        keyTarget: _tabHomeKey,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: middleTop,
              left: sidePadding,
              right: sidePadding,
            ),
            child: Container(
              alignment: Alignment.center,
              child: Text(
                "Go here to race on the Track and collect flags!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "TrainingTab",
        keyTarget: _tabTrainingKey,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: middleTop,
              left: sidePadding,
              right: sidePadding,
            ),
            child: Container(
              alignment: Alignment.center,
              child: Text(
                "Visit Training to practice and earn extra lives.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "LibraryTab",
        keyTarget: _tabLibraryKey,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: middleTop,
              left: sidePadding,
              right: sidePadding,
            ),
            child: Container(
              alignment: Alignment.center,
              child: Text(
                "Browse all cars and learn their specs here.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "ProfileTab",
        keyTarget: _tabProfileKey,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: middleTop,
              left: sidePadding,
              right: sidePadding,
            ),
            child: Container(
              alignment: Alignment.center,
              child: Text(
                "Check your achievements and stats in your profile.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    ];

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black87,
      textSkip: "SKIP",
      textStyleSkip: TextStyle(color: Colors.white),
      // Move SKIP to center + skipYOffset down
      alignSkip: Alignment(0, skipYOffset),
      showSkipInLastTarget: false,
      paddingFocus: 10,
      onFinish: () => print("Tutorial finished"),
      onClickTarget: (t) => print("Clicked on ${t.identify}"),
      onSkip: () {
        print("Tutorial skipped");
        return true;
      },
    )..show(
      context: context,
      rootOverlay: true,
    );
  }

  String _getStreakTitle(int streak) {
    if (streak >= 100) return "GearUp Legend";
    if (streak >= 60) return "Turbo Master";
    if (streak >= 30) return "Car Master";
    if (streak >= 14) return "Rising Racer";
    if (streak >= 7) return "Committed Driver";
    if (streak >= 3) return "Starter";
    return "Newbie";
  }

  // Loads the stored day streak from SharedPreferences.
  void _loadDayStreak() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      dayStreak = prefs.getInt('dayStreak') ?? 0;
      streakTitle = _getStreakTitle(dayStreak);
    });
  }

  void showAchievementSnackBar(String title) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text("🏆 Achievement Unlocked: $title"),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }

  /// Call this *every* time you change today's count.
  Future<void> _saveDailyCount(String dateKey, int count) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonMap = prefs.getString('dailyCounts') ?? '{}';
    final Map<String, dynamic> counts = json.decode(jsonMap);
    counts[dateKey] = count;
    await prefs.setString('dailyCounts', json.encode(counts));
  }

  // Initialize challengesCompletedToday based on today’s date and challenge count.
  void _initializeChallengeStatus() async {
    final prefs = await SharedPreferences.getInstance();
    String? challengesDate = prefs.getString('challengesDate');
    int count = prefs.getInt('dailyChallengeCount') ?? 0;
    DateTime today = DateTime.now();
    if (challengesDate == null ||
        DateTime.parse(challengesDate).day != today.day ||
        count < 5) {
      setState(() {
        challengesCompletedToday = false;
      });
    } else {
      setState(() {
        challengesCompletedToday = true;
      });
    }
  }

  void _triggerStreakReward(int streak) {
    if ([7, 14, 30, 60, 100].contains(streak)) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text("🎁 $streak-Day Streak! Bonus awarded!"),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.deepOrangeAccent,
        ),
      );
    }
  }

  void _playStreakAnimation() {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text("🔥 Streak Up! Keep it going!"),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orangeAccent,
      ),
    );
  }

  /// Called once, when the user finishes 5 challenges on a new day.
  Future<void> _updateDayStreakAfterChallengeCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIso = today.toIso8601String();
    String? lastLoginStr = prefs.getString('lastLogin');
    int currentStreak = prefs.getInt('dayStreak') ?? 0;

    if (lastLoginStr == null) {
      currentStreak = 1;
    } else {
      DateTime lastLogin = DateTime.parse(lastLoginStr);
      int diffDays = today.difference(lastLogin).inDays;
      if (diffDays == 1) {
        currentStreak++;
      } else if (diffDays > 1) {
        currentStreak = 1;
      } else {
        return;
      }
    }

    await prefs.setInt('dayStreak', currentStreak);
    await prefs.setString('lastLogin', todayIso);

    setState(() {
      dayStreak = currentStreak;
      streakTitle = _getStreakTitle(currentStreak);
    });

    _triggerStreakReward(currentStreak);
    _playStreakAnimation();
  }

  // When a challenge is completed, update the daily count, streak, and record playHistory.
  Future<void> recordChallengeCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIso = today.toIso8601String();
    final todayStr = todayIso.split('T').first;

    String? lastDate = prefs.getString('challengesDate');
    if (lastDate != todayIso) {
      await prefs.setString('challengesDate', todayIso);
      await prefs.setInt('dailyChallengeCount', 0);
      await prefs.setBool('streakUpdated', false);
    }

    int count = prefs.getInt('dailyChallengeCount') ?? 0;
    count++;
    await prefs.setInt('dailyChallengeCount', count);
    await _saveDailyCount(todayStr, count);

    bool streakUpdated = prefs.getBool('streakUpdated') ?? false;
    if (!streakUpdated && count >= 5) {
      await _updateDayStreakAfterChallengeCompletion();
      await prefs.setBool('streakUpdated', true);
      setState(() {
        challengesCompletedToday = true;
      });

      final completionDays = prefs.getStringList('playHistory') ?? [];
      if (!completionDays.contains(todayStr)) {
        completionDays.add(todayStr);
        await prefs.setStringList('playHistory', completionDays);
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _showLivesPopup() async {
    // Recharge le nombre de vies au moment du popup
    lives = await widget.livesStorage.readLives();

    return showDialog(
      context: context,
      builder: (context) {
        if (lives >= _maxLives) {
          return AlertDialog(
            title: Text('Your Lives'),
            content: Text('Lives are full'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('OK')),
            ],
          );
        } else {
          return AlertDialog(
            title: Text('Your Lives'),
            content: ValueListenableBuilder<int>(
              valueListenable: _lifeTimerRemaining,
              builder: (context, remaining, child) {
                // minutes et secondes restantes
                final minutes = remaining ~/ 60;
                final seconds = remaining % 60;
                // PROGRESSION : de 0 (juste déclenché) à 1 (vie disponible)
                final progress = 1 - (remaining / _refillInterval);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("You have $lives / $_maxLives lives remaining."),
                    SizedBox(height: 8),
                    Text("Next life in $minutes min $seconds sec"),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _currentIndex = 1; // Aller à l’onglet Training
                        });
                      },
                      child: Text("Train for life"),
                    ),
                    SizedBox(height: 8),
                  ],
                );
              },
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('OK')),
            ],
          );
        }
      },
    );
  }

  void _showCalendarPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson   = prefs.getString('dailyCounts') ?? '{}';
    final Map<String, dynamic> dailyCounts = json.decode(rawJson);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Play Calendar"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayCalendarWidget(
              dailyCounts: dailyCounts.cast<String,int>(),
            ),
            const SizedBox(height: 12),
            Text("Complete 5 flag challenges to do your streak",
                  style: TextStyle(fontSize:11, color:Colors.grey)),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: (dailyCounts[DateTime.now().toIso8601String().split('T').first] ?? 0).clamp(0,5)/5),
          ],
        ),
        actions: [ TextButton(onPressed: () => Navigator.pop(context), child: Text("Close")) ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Gear count
            Row(
              key: _gearKey,
              children: [
                Image.asset('assets/icons/gear.png', height: 24),
                SizedBox(width: 4),
                Text('$gearCount', style: TextStyle(fontSize: 18)),
              ],
            ),
            // Daily streak
            Row(
              key: _streakKey,
              children: [
                Icon(Icons.local_fire_department,
                    color: challengesCompletedToday ? Colors.orange : Colors.grey),
                SizedBox(width: 4),
                GestureDetector(
                  onTap: _showCalendarPopup,
                  child: Container(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      '$dayStreak 🔥 $streakTitle',
                      style: TextStyle(
                          fontSize: 16, decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            ),
            // Lives indicator
            GestureDetector(
              key: _livesKey,
              onTap: _showLivesPopup,
              child: Row(
                children: [
                  Image.asset(_heartImagePath, height: 24),
                  SizedBox(width: 8),
                  Text('$lives', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),

      body: _pages[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: [
          BottomNavigationBarItem(
            icon: Container(key: _tabHomeKey, child: Icon(Icons.home)),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Container(key: _tabTrainingKey, child: Icon(Icons.fitness_center)),
            label: 'Training',
          ),
              BottomNavigationBarItem(
            icon: Container(key: _tabRaceKey, child: Icon(Icons.flag)),
            label: 'Race',
          ),
          BottomNavigationBarItem(
            icon: Container(key: _tabLibraryKey, child: Icon(Icons.library_books)),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Container(key: _tabProfileKey, child: Icon(Icons.person)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _lifeTimer?.cancel();
    _lifeTimerRemaining.dispose();
    super.dispose();
  }
}

class PlayCalendarWidget extends StatefulWidget {
  /// A map from ISO date strings ("YYYY-MM-DD") to the number of challenges
  /// completed that day (0–5+).
  final Map<String, int> dailyCounts;

  const PlayCalendarWidget({
    Key? key,
    required this.dailyCounts,
  }) : super(key: key);

  @override
  _PlayCalendarWidgetState createState() => _PlayCalendarWidgetState();
}

class _PlayCalendarWidgetState extends State<PlayCalendarWidget> {
  late int currentYear;
  late int currentMonth;

  static const List<String> weekDays = [
    'Mon','Tue','Wed','Thu','Fri','Sat','Sun'
  ];
  static const List<String> monthNames = [
    "January","February","March","April","May","June",
    "July","August","September","October","November","December"
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    currentYear  = now.year;
    currentMonth = now.month;
  }

  void _previousMonth() {
    setState(() {
      if (currentMonth == 1) {
        currentMonth = 12;
        currentYear--;
      } else {
        currentMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (currentMonth == 12) {
        currentMonth = 1;
        currentYear++;
      } else {
        currentMonth++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final today    = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final firstOfMonth = DateTime(currentYear, currentMonth, 1);
    final daysInMonth  = DateTime(currentYear, currentMonth + 1, 0).day;
    final weekdayOfFirst = firstOfMonth.weekday; // Mon=1 … Sun=7

    // Build all the day cells (excluding weekday header)
    List<Widget> dayCells = [];

    // Leading empty cells for the first week
    for (int i = 1; i < weekdayOfFirst; i++) {
      dayCells.add(Container());
    }

    // Fill in each day
    for (int day = 1; day <= daysInMonth; day++) {
      final d   = DateTime(currentYear, currentMonth, day);
      final iso = "${d.year.toString().padLeft(4,'0')}-"
                  "${d.month.toString().padLeft(2,'0')}-"
                  "${d.day.toString().padLeft(2,'0')}";

      int count = widget.dailyCounts[iso] ?? 0;
      Color bg;
      if (d.isAfter(todayOnly)) {
        bg = Colors.white;
      } else if (count >= 5) {
        bg = Colors.orange;
      } else if (count > 0) {
        double t = (count.clamp(0,5)) / 5.0;
        bg = Color.lerp(Colors.grey, Colors.orange, t)!;
      } else {
        bg = Colors.grey;
      }

      dayCells.add(_buildDayCell(day, bg));
    }

    // Chunk into rows of 7
    List<TableRow> rows = [];
    // Weekday header row
    rows.add(
      TableRow(
        children: weekDays
            .map((wd) => Center(
                  child: Text(wd,
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold)),
                ))
            .toList(),
      ),
    );
    // Date rows
    for (int i = 0; i < dayCells.length; i += 7) {
      final end = (i + 7 < dayCells.length) ? i + 7 : dayCells.length;
      final slice = dayCells.sublist(i, end);
      // pad to 7
      if (slice.length < 7) {
        slice.addAll(List.generate(7 - slice.length, (_) => Container()));
      }
      rows.add(TableRow(children: slice));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Month navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_left, size: 20),
              onPressed: _previousMonth,
            ),
            Text(
              "${monthNames[currentMonth - 1]} $currentYear",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.arrow_right, size: 20),
              onPressed: _nextMonth,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Calendar grid
        Table(children: rows),
      ],
    );
  }

  Widget _buildDayCell(int day, Color bg) {
    final textColor = bg == Colors.white ? Colors.black : Colors.white;
    return Container(
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      padding: EdgeInsets.all(4),
      child: Center(
        child: Text(
          day.toString(),
          style: TextStyle(fontSize: 10, color: textColor),
        ),
      ),
    );
  }
}