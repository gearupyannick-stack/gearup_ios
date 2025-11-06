// main.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// REMOVED: import 'pages/welcome_page.dart';
import 'pages/home_page.dart';
import 'pages/training_page.dart';
import 'pages/library_page.dart';
import 'pages/profile_page.dart';
import 'pages/welcome_page.dart';
import 'services/sound_manager.dart';
import 'services/premium_service.dart';
import 'services/ad_service.dart';
import 'pages/premium_page.dart';
import 'services/auth_service.dart';
import 'services/lives_storage.dart';
import 'services/language_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pages/race_page.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/analytics_service.dart';
import 'package:easy_localization/easy_localization.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Track app launch and update user properties in Analytics
Future<void> _trackAppLaunch(SharedPreferences prefs) async {
  try {
    // Log app open
    await AnalyticsService.instance.logAppOpen();

    // Check if this is first app open
    final isFirstOpen = !(prefs.getBool('isOnboarded') ?? false);
    if (isFirstOpen) {
      await AnalyticsService.instance.logFirstOpen();
    }

    // Set user ID from Firebase Auth
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await AnalyticsService.instance.setUserId(currentUser.uid);
    }

    // Update user properties
    final isPremium = prefs.getBool('isPremium') ?? false;
    final gearCount = prefs.getInt('gearCount') ?? 0;
    final dayStreak = prefs.getInt('dayStreak') ?? 0;

    // Determine auth method for iOS
    String authMethod = 'anonymous';
    if (currentUser != null && !currentUser.isAnonymous) {
      // Check provider data to determine if it's Apple Sign-In
      final providerData = currentUser.providerData;
      if (providerData.any((info) => info.providerId == 'apple.com')) {
        authMethod = 'apple';
      }
    }

    // Determine user type
    String userType = 'free';
    if (isPremium) {
      userType = 'premium';
    } else if (currentUser?.isAnonymous ?? false) {
      userType = 'guest';
    }

    // Update all user properties
    await AnalyticsService.instance.updateUserProperties(
      userType: userType,
      totalGears: gearCount,
      currentTrack: 1, // Default, will be updated as user progresses
      currentLevel: 1, // Default, will be updated as user progresses
      dayStreak: dayStreak,
      authMethod: authMethod,
    );

    debugPrint('Analytics: App launch tracked successfully');
  } catch (e) {
    debugPrint('Analytics: Error tracking app launch: $e');
    // Don't block app startup if analytics fails
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();

  // Force system UI to use dark theme (status bar, navigation bar)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF1E1E1E),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Set true during local dev to use test ads
  await AdService.instance.init(testMode: false);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Analytics
  await AnalyticsService.instance.init();

  await SoundManager.instance.init();
  // --------------------------
  // App Check: DEBUG provider (local dev)
  // --------------------------
  // This makes Firebase accept App Check requests from this debug build.
  // After first run, check logcat for the debug token and add it in:
  // Firebase Console -> App Check -> Manage debug tokens -> Add token
  //
  // IMPORTANT: Use only for local development. Remove or switch to
  // AndroidProvider.playIntegrity for production builds.
  try {
    await FirebaseAppCheck.instance.activate(
      // ignore: deprecated_member_use
      androidProvider: AndroidProvider.debug,
      // iosProvider: AppleProvider.debug, // uncomment if you also run local iOS debug builds
    );
    // optional: small delay to ensure activation (not required but safe)
    await Future.delayed(const Duration(milliseconds: 200));
  } catch (e, st) {
    // keep app running even if App Check activation fails — log to console
    // (this helps during development if package isn't added or something)
    debugPrint('AppCheck activation error: $e\n$st');
  }

  // Track app open and set user properties
  final prefs = await SharedPreferences.getInstance();
  await _trackAppLaunch(prefs);
  final bool areImagesLoaded = prefs.getBool('areImagesLoaded') ?? false;
  final bool shouldPreload = !areImagesLoaded;

  final livesStorage = LivesStorage();
  final int savedLives = await livesStorage.readLives();

  // Load saved language preference
  final savedLanguageCode = await LanguageService.getSavedLanguage();
  final Locale? startLocale = savedLanguageCode != null ? Locale(savedLanguageCode) : null;

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('es'), Locale('fr'), Locale('de'), Locale('it'), Locale('pt')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: startLocale, // Override device locale if user has set preference
      child: CarLearningApp(
        shouldPreload: shouldPreload,
        initialLives: savedLives,
        livesStorage: livesStorage,
      ),
    ),
  );
}

class CarLearningApp extends StatelessWidget {
  final bool shouldPreload; // <── add this
  final int initialLives;
  final LivesStorage livesStorage;

  const CarLearningApp({
    Key? key,
    required this.shouldPreload,
    required this.initialLives,
    required this.livesStorage,
  }) : super(key: key);

  Future<bool> _initializeApp() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool('isOnboarded') ?? false;
    
    // Auto-authenticate returning users silently in background
    if (onboarded) {
      try {
        final auth = AuthService();
        if (auth.currentUser == null) {
          await auth.signInAnonymously();
        }
      } catch (e) {
        debugPrint('Background auth failed: $e');
      }
    }
    
    return onboarded;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'app.title'.tr(),
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      routes: {'/premium': (ctx)=>const PremiumPage()},
      localizationsDelegates: EasyLocalization.of(context)!.delegates,
      supportedLocales: EasyLocalization.of(context)!.supportedLocales,
      locale: EasyLocalization.of(context)!.currentLocale,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF3D0000),
        appBarTheme: const AppBarTheme(
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
            backgroundColor: const Color(0xFF3D0000),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: Colors.redAccent,
          unselectedItemColor: Colors.white70,
        ),
        cardColor: const Color(0xFF1E1E1E),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          contentTextStyle: TextStyle(fontSize: 16, color: Colors.white70),
        ),
      ),

      home: FutureBuilder<bool>(
        future: _initializeApp(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final onboarded = snap.data!;
          if (!onboarded) {
            return const WelcomePage();
          }
          return MainPage(
            initialLives: initialLives,
            livesStorage: livesStorage,
          );
        },
      ),
    );
  }
}

/// Shows PreloadPage on first-ever launch, then future launches go straight to MainPage.
/// We mark `isFirstLaunch=false` immediately so the second app start bypasses preload.
class FirstLaunchGate extends StatefulWidget {
  final int initialLives;
  final LivesStorage livesStorage;

  const FirstLaunchGate({
    Key? key,
    required this.initialLives,
    required this.livesStorage,
  }) : super(key: key);

  @override
  State<FirstLaunchGate> createState() => _FirstLaunchGateState();
}

class _FirstLaunchGateState extends State<FirstLaunchGate> {
  @override
  void initState() {
    super.initState();
    // Initialize Premium state
    PremiumService.instance.init().then((_) { if(mounted) setState((){}); });
_markNotFirstAndShowPreload();
  }

  Future<void> _markNotFirstAndShowPreload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);

    // We navigate directly to PreloadPage. Typical pattern inside PreloadPage:
    // when loading completes, call:
    //   Navigator.pushReplacement(
    //     context,
    //     MaterialPageRoute(
    //       builder: (_) => MainPage(
    //         initialLives: widget.initialLives,
    //         livesStorage: widget.livesStorage,
    //       ),
    //     ),
    //   );
    //
    // If your current PreloadPage already navigates somewhere else,
    // adjust it to pushReplacement to the MainPage above.
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
    // Minimal splash while we route into PreloadPage
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.red)),
    );
  }
}

class MainPage extends StatefulWidget {
  final int initialLives;
  final LivesStorage livesStorage;

  const MainPage({
    Key? key,
    required this.initialLives,
    required this.livesStorage,
  }) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // Keep a strong reference to the tutorial so buttons can call next()/finish()
  TutorialCoachMark? _tutorialCoachMark;

  // ── CONFIG ─────────────────────────────────────────
  static const int _maxLives = 5;
  static const int _refillInterval = 600; // seconds per life

  // ── STATE ──────────────────────────────────────────
  int _currentIndex = 0;
  int gearCount = 0;
  late int lives;
  Timer? _lifeTimer;
  bool _hasShownRatePopup = false;
  bool _isShowingAdAction = false;
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
  final GlobalKey _levelProgressKey = GlobalKey();
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
        levelProgressKey: _levelProgressKey,
      ),
      TrainingPage(
        onLifeWon: () async {
          int newLives = await widget.livesStorage.readLives();
          setState(() => lives = newLives);

          // Track life earned from training
          AnalyticsService.instance.logLifeEarned(
            source: 'training',
            livesNow: newLives,
          );
        },
        recordChallengeCompletion: recordChallengeCompletion,
      ),
      const RacePage(), 
      const LibraryPage(),
      ProfilePage(onReplayTutorial: () => _maybeShowTutorial(force: true)),
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
              .add(const Duration(seconds: _refillInterval));
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
    // 1) Decrement & persist (skip if Premium)
    if (!PremiumService.instance.isPremium) {
      setState(() { if (lives > 0) lives--; });
      await widget.livesStorage.writeLives(lives);

      // Track life lost
      AnalyticsService.instance.logLifeLost(
        context: 'challenge_fail',
        livesRemaining: lives,
      );
    }
// 2) If we’ve dropped below max, schedule the next life *relative to now*
    if (lives < _maxLives) {
      final prefs = await SharedPreferences.getInstance();
      final nextDue = DateTime.now().add(const Duration(seconds: _refillInterval));
      await prefs.setString('nextLifeDueTime', nextDue.toIso8601String());
      _lifeTimerRemaining.value = nextDue.difference(DateTime.now()).inSeconds;

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
          title: Text('lives.lost'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'lives.lostMessage'.tr(),
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
                    final prefs = await SharedPreferences.getInstance();
                    prefs.remove('nextLifeDueTime');

                    // Track life earned from rating
                    AnalyticsService.instance.logLifeEarned(
                      source: 'rate_app',
                      livesNow: lives,
                    );

                    Navigator.of(ctx).pop();
                    final uri = Uri.parse(
                      // NOTE: keep your existing Android package here.
                      'https://play.google.com/store/apps/details?id=com.gearup.app'
                    );
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: Text(
                    'lives.rateButton'.tr(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              child: Text('lives.noThanks'.tr()),
            ),
          ],
        ),
      );
    }
  }

  /// Watch ad to recover a life
  Future<void> _onWatchAdForLife() async {
    if (_isShowingAdAction) return;
    setState(() => _isShowingAdAction = true);

    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text('lives.loadingAd'.tr())));

    try {
      // AdService should call the provided onEarnedLife callback synchronously
      final shown = await AdService.instance.showRewardedHomeLife(
        onEarnedLife: () {
          // Grant 1 life
          setState(() {
            lives = (lives + 1).clamp(0, _maxLives);
          });
          widget.livesStorage.writeLives(lives);

          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text('lives.earnedOne'.tr())),
          );
        },
      );

      scaffoldMessengerKey.currentState?.clearSnackBars();

      if (!shown) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('lives.adUnavailable'.tr())),
        );
      }
      // if shown==true, the onEarnedLife callback will have run and persisted new lives.
    } catch (e) {
      scaffoldMessengerKey.currentState?.clearSnackBars();
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('lives.adError'.tr(namedArgs: {'error': e.toString()}))),
      );
      debugPrint('Error in _onWatchAdForLife: $e');
    } finally {
      if (mounted) setState(() => _isShowingAdAction = false);
    }
  }

  Future<void> _maybeShowTutorial({bool force = false}) async {
    // Show the tutorial only when:
    //  - force == true  (replay request from profile), OR
    //  - there is no 'hasSeenTutorial' flag in SharedPreferences yet.
    //
    // When we decide to show it, we immediately set the flag to true so it
    // won't reappear on subsequent app launches.

    final prefs = await SharedPreferences.getInstance();
    final bool hasSeen = prefs.getBool('hasSeenTutorial') ?? false;

    if (force) {
      // Replay requested from profile: always show, and persist that user has seen it.
      await prefs.setBool('hasSeenTutorial', true);
      // Track tutorial replay
      AnalyticsService.instance.logTutorialReplayed();
      WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
      return;
    }

    // Normal behaviour: if not seen before, mark seen and show once.
    if (!hasSeen) {
      await prefs.setBool('hasSeenTutorial', true);
      // Track tutorial begin
      AnalyticsService.instance.logTutorialBegin();
      WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
    }
  }

  void _showTutorial() {
    // screen dimensions for centering text
    final size = MediaQuery.of(context).size;
    final middleTop = size.height * 0.5 - 50;
    final sidePadding = size.width * 0.1;
    // you already changed this value — keep it
    final skipYOffset = (50 / size.height) * 15.0; // Alignment y goes from -1 to 1

    // local reference to the coach mark so our Continue buttons can call next()/finish()
    // use the field instead of a local variable
    // late TutorialCoachMark tutorialCoachMark;

    // small reusable style for the textual content
    const TextStyle tutorialTextStyle = TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w500,
    );

    final targets = <TargetFocus>[
      // 1) Gear
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "tutorial.gear".tr(),
                  textAlign: TextAlign.center,
                  style: tutorialTextStyle,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _tutorialCoachMark?.next(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text("tutorial.continue".tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // 2) Streak
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "tutorial.streak".tr(),
                  textAlign: TextAlign.center,
                  style: tutorialTextStyle,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _tutorialCoachMark?.next(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text("tutorial.continue".tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // 3) Lives
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "tutorial.lives".tr(),
                  textAlign: TextAlign.center,
                  style: tutorialTextStyle,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _tutorialCoachMark?.next(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text("tutorial.continue".tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // 4) Level progress bar / Map (NEW)
      // NOTE: declare and attach _levelProgressKey to the actual progress/map widget in home_page.dart
      TargetFocus(
        identify: "LevelProgress",
        keyTarget: _levelProgressKey,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: middleTop,
              left: sidePadding,
              right: sidePadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "tutorial.levelProgress".tr(),
                  textAlign: TextAlign.center,
                  style: tutorialTextStyle,
                ),
                const SizedBox(height: 12),
                Text(
                  "tutorial.levelProgressTip".tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _tutorialCoachMark?.next(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text("tutorial.continue".tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // 5) Home tab
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "tutorial.homeTab".tr(),
                  textAlign: TextAlign.center,
                  style: tutorialTextStyle,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _tutorialCoachMark?.next(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text("tutorial.continue".tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // 6) Training tab
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "tutorial.trainingTab".tr(),
                  textAlign: TextAlign.center,
                  style: tutorialTextStyle,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _tutorialCoachMark?.next(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text("tutorial.continue".tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // Multiplayer / Race (NEW)
      TargetFocus(
        identify: "Multiplayer",
        keyTarget: _tabRaceKey, // reuses existing Race tab key
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(
              top: middleTop,
              left: sidePadding,
              right: sidePadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "tutorial.multiplayer".tr(),
                  textAlign: TextAlign.center,
                  style: tutorialTextStyle,
                ),
                const SizedBox(height: 12),
                Text(
                  "tutorial.multiplayerTip".tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _tutorialCoachMark?.next(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text("tutorial.continue".tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // 7) Library tab
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "tutorial.libraryTab".tr(),
                  textAlign: TextAlign.center,
                  style: tutorialTextStyle,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _tutorialCoachMark?.next(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text("tutorial.continue".tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // 8) Profile tab (mention Replay)
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "tutorial.profileTab".tr(),
                  textAlign: TextAlign.center,
                  style: tutorialTextStyle,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _tutorialCoachMark?.next(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text("tutorial.continue".tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // 9) FirstFlag (FINAL)
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "tutorial.firstFlag".tr(),
                  textAlign: TextAlign.center,
                  style: tutorialTextStyle,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _tutorialCoachMark?.finish(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text("tutorial.finish".tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ];

    // build and show
    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black87,
      textSkip: "tutorial.skip".tr(),
      textStyleSkip: const TextStyle(color: Colors.white),
      // Move SKIP to center + skipYOffset down
      alignSkip: Alignment(0, skipYOffset),
      showSkipInLastTarget: false,
      paddingFocus: 10,
      onFinish: () {
        print("Tutorial finished");
        AnalyticsService.instance.logTutorialComplete();
      },
      onClickTarget: (t) => print("Clicked on ${t.identify}"),
      onSkip: () {
        print("Tutorial skipped");
        AnalyticsService.instance.logTutorialSkip();
        return true;
      },
    );

    _tutorialCoachMark?.show(
      context: context,
      rootOverlay: true,
    );
  }

  String _getStreakTitle(int streak) {
    if (streak >= 100) return "streak.gearupLegend".tr();
    if (streak >= 60) return "streak.turboMaster".tr();
    if (streak >= 30) return "streak.carMaster".tr();
    if (streak >= 14) return "streak.risingRacer".tr();
    if (streak >= 7) return "streak.committedDriver".tr();
    if (streak >= 3) return "streak.starter".tr();
    return "streak.newbie".tr();
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
        content: Text("achievements.unlocked".tr(namedArgs: {'title': title})),
        duration: const Duration(seconds: 2),
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
      // Track streak milestone
      AnalyticsService.instance.logStreakMilestone(milestone: streak);

      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text("streak.bonus".tr(namedArgs: {'count': streak.toString()})),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.deepOrangeAccent,
        ),
      );
    }
  }

  void _playStreakAnimation() {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text("streak.fireUp".tr()),
        duration: const Duration(seconds: 2),
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

    // Track streak update in Analytics
    AnalyticsService.instance.logStreakUpdated(
      newStreakCount: currentStreak,
      streakTitle: streakTitle,
    );

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

      // Track daily goal completed
      AnalyticsService.instance.logDailyGoalCompleted(challengesCompleted: count);

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

  void _showCategorySelectionPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('categories.title'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current category - Road Legal Cars
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'categories.roadLegalCars'.tr(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'categories.current'.tr(namedArgs: {'count': gearCount.toString()}),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Coming soon categories
                _buildLockedCategory('categories.raceCars'.tr()),
                const SizedBox(height: 12),
                _buildLockedCategory('categories.vintageCars'.tr()),
                const SizedBox(height: 12),
                _buildLockedCategory('categories.motorsport'.tr()),
                const SizedBox(height: 16),
                Text(
                  'categories.stayTuned'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white60,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('calendar.close'.tr()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLockedCategory(String categoryName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.lock, color: Colors.grey.shade600, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'categories.comingSoon'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLivesPopup() async {
    // Refresh lives when opening popup
    lives = await widget.livesStorage.readLives();

    // Track lives popup opened
    AnalyticsService.instance.logLivesPopupOpened(currentLives: lives);

    return showDialog(
      context: context,
      builder: (context) {
        if (lives >= _maxLives) {
          return AlertDialog(
            title: Text('lives.title'.tr()),
            content: Text('lives.full'.tr()),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('common.ok'.tr())),
            ],
          );
        } else {
          // inside the AlertDialog you return when lives < _maxLives
          return AlertDialog(
            title: Text('lives.title'.tr()),
            content: ValueListenableBuilder<int>(
              valueListenable: _lifeTimerRemaining,
              builder: (context, remaining, child) {
                final minutes = remaining ~/ 60;
                final seconds = remaining % 60;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("lives.remaining".tr(namedArgs: {'count': lives.toString(), 'max': _maxLives.toString()})),
                    const SizedBox(height: 8),
                    Text("lives.nextIn".tr(namedArgs: {'minutes': minutes.toString(), 'seconds': seconds.toString()})),
                    const SizedBox(height: 12),

                    // Watch ad button to recover 1 life
                    if (!PremiumService.instance.isPremium)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: Text("lives.watchAd".tr()),
                        onPressed: () {
                          Navigator.of(context).pop();  // close popup first
                          _onWatchAdForLife();
                        },
                      ),

                    const SizedBox(height: 8),

                    // TRAINING CTA: jump to Training tab so user can earn a life
                    ElevatedButton.icon(
                      icon: const Icon(Icons.fitness_center),
                      label: Text("lives.trainForLife".tr()),
                      onPressed: () {
                        Navigator.of(context).pop();               // close the popup
                        setState(() { _currentIndex = 1; });       // switch to Training tab (index 1)
                        scaffoldMessengerKey.currentState?.showSnackBar(
                          SnackBar(
                            content: Text('training.completeToEarnLife'.tr()),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    // Upgrade hint inside popup
                    if (!PremiumService.instance.isPremium)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upgrade),
                        label: Text("lives.unlimited".tr()),
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pushNamed('/premium');
                        },
                      ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('common.ok'.tr())),
            ],
          );
        }
      },
    );
  }

  void _showCalendarPopup() async {
    // Track calendar viewed
    AnalyticsService.instance.logCalendarViewed();

    final prefs = await SharedPreferences.getInstance();
    final rawJson   = prefs.getString('dailyCounts') ?? '{}';
    final Map<String, dynamic> dailyCounts = json.decode(rawJson);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("calendar.title".tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayCalendarWidget(
              dailyCounts: dailyCounts.cast<String,int>(),
            ),
            const SizedBox(height: 12),
            Text("calendar.complete5".tr(),
                  style: const TextStyle(fontSize:11, color:Colors.grey)),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: (dailyCounts[DateTime.now().toIso8601String().split('T').first] ?? 0).clamp(0,5)/5),
          ],
        ),
        actions: [ TextButton(onPressed: () => Navigator.pop(context), child: Text("calendar.close".tr())) ],
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
            GestureDetector(
              onTap: _showCategorySelectionPopup,
              child: Row(
                key: _gearKey,
                children: [
                  Image.asset('assets/icons/gear.png', height: 24),
                  const SizedBox(width: 4),
                  Text('$gearCount', style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
            // Daily streak
            Row(
              key: _streakKey,
              children: [
                Icon(Icons.local_fire_department,
                    color: challengesCompletedToday ? Colors.orange : Colors.grey),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _showCalendarPopup,
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      '$dayStreak 🔥 $streakTitle',
                      style: const TextStyle(
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
                  const SizedBox(width: 8),
                  Text(
                    PremiumService.instance.isPremium ? '∞' : '$lives',
                    style: const TextStyle(fontSize: 18),
                  ),
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
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.white70,
        items: [
          BottomNavigationBarItem(
            icon: Container(key: _tabHomeKey, child: const Icon(Icons.home)),
            label: 'navigation.home'.tr(),
          ),
          BottomNavigationBarItem(
            icon: Container(key: _tabTrainingKey, child: const Icon(Icons.fitness_center)),
            label: 'navigation.training'.tr(),
          ),
          BottomNavigationBarItem(
            icon: Container(key: _tabRaceKey, child: const Icon(Icons.flag)),
            label: 'navigation.race'.tr(),
          ),
          BottomNavigationBarItem(
            icon: Container(key: _tabLibraryKey, child: const Icon(Icons.library_books)),
            label: 'navigation.library'.tr(),
          ),
          BottomNavigationBarItem(
            icon: Container(key: _tabProfileKey, child: const Icon(Icons.person)),
            label: 'navigation.profile'.tr(),
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

  List<String> get weekDays => [
    'calendar.weekdays.mon'.tr(),
    'calendar.weekdays.tue'.tr(),
    'calendar.weekdays.wed'.tr(),
    'calendar.weekdays.thu'.tr(),
    'calendar.weekdays.fri'.tr(),
    'calendar.weekdays.sat'.tr(),
    'calendar.weekdays.sun'.tr()
  ];

  List<String> get monthNames => [
    "calendar.months.january".tr(),
    "calendar.months.february".tr(),
    "calendar.months.march".tr(),
    "calendar.months.april".tr(),
    "calendar.months.may".tr(),
    "calendar.months.june".tr(),
    "calendar.months.july".tr(),
    "calendar.months.august".tr(),
    "calendar.months.september".tr(),
    "calendar.months.october".tr(),
    "calendar.months.november".tr(),
    "calendar.months.december".tr()
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
                      style: const TextStyle(
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
              icon: const Icon(Icons.arrow_left, size: 20),
              onPressed: _previousMonth,
            ),
            Text(
              "${monthNames[currentMonth - 1]} $currentYear",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_right, size: 20),
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
      padding: const EdgeInsets.all(4),
      child: Center(
        child: Text(
          day.toString(),
          style: TextStyle(fontSize: 10, color: textColor),
        ),
      ),
    );
  }
}