// lib/pages/welcome_page.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/auth_service.dart';
import '../main.dart';
import '../services/lives_storage.dart';
import '../services/analytics_service.dart';
import '../services/language_service.dart';

class Slide {
  final String imagePath;
  const Slide({required this.imagePath});
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final List<Slide> slides = const [
    Slide(imagePath: "assets/images/slide1.png"),
    Slide(imagePath: "assets/images/slide2.png"),
    Slide(imagePath: "assets/images/slide3.png"),
    Slide(imagePath: "assets/images/slide4.png"),
    Slide(imagePath: "assets/images/slide5.png"),
  ];

  final PageController _pageController = PageController();
  Timer? _timer;
  int currentPage = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Auto-slide every 5s
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_pageController.hasClients) return;
      final next = ((_pageController.page?.round() ?? currentPage) + 1) % slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      currentPage = next;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markOnboardedAndEnter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnboarded', true);
    if (!mounted) return;

    final livesStorage = LivesStorage();
    int currentLives;
    try {
      currentLives = await livesStorage.readLives();
    } catch (_) {
      currentLives = 5;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MainPage(
          initialLives: currentLives,
          livesStorage: livesStorage,
        ),
      ),
    );
  }

  Future<void> _continueAsGuest() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Sign in anonymously to Firebase
      final credential = await AuthService.instance.signInAnonymously();
      if (credential == null || credential.user == null) {
        throw 'Failed to create anonymous account.';
      }

      final user = credential.user!;

      // Persist auth state to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest', true);
      await prefs.setString('auth_method', 'anonymous');
      await prefs.setString('firebase_uid', user.uid);
      await prefs.setBool('google_signed_in', false);

      // Store timestamp for 2-day notification prompt
      await prefs.setString('anonymous_since', DateTime.now().toIso8601String());

      // Track sign-up in Analytics
      await AnalyticsService.instance.logSignUp(method: 'anonymous');
      await AnalyticsService.instance.setUserId(user.uid);

      // Mark onboarding done and enter
      await _markOnboardedAndEnter();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('welcome.couldNotContinueAsGuest'.tr(namedArgs: {'error': e.toString()})),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  
  Future<void> _continueWithGoogle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final credential = await AuthService.instance.signInWithGoogle();
      if (credential == null) {
        throw 'Sign-in cancelled.';
      }

      // Get user info from Firebase
      final user = credential.user;

      // CRITICAL: Persist auth state to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('google_signed_in', true);
      await prefs.setString('google_displayName', user?.displayName ?? '');
      await prefs.setString('google_email', user?.email ?? '');
      await prefs.setString('google_photoUrl', user?.photoURL ?? '');
      await prefs.setBool('use_google_name', true);
      await prefs.setBool('is_guest', false);
      await prefs.setString('auth_method', 'google');
      await prefs.setString('firebase_uid', user?.uid ?? '');
      // Remove anonymous timestamp if exists (user upgraded)
      await prefs.remove('anonymous_since');

      // Track sign-up in Analytics
      await AnalyticsService.instance.logSignUp(method: 'google');
      await AnalyticsService.instance.setUserId(user?.uid);

      // Mark onboarding done and enter
      await _markOnboardedAndEnter();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('welcome.signInFailed'.tr(namedArgs: {'error': e.toString()})),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                      setState(() {}); // Refresh the welcome page text
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // Background slideshow
          PageView.builder(
            controller: _pageController,
            itemCount: slides.length,
            onPageChanged: (index) => setState(() => currentPage = index),
            itemBuilder: (_, index) {
              return SizedBox.expand(
                child: Image.asset(
                  slides[index].imagePath,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),

          // Top title
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Text(
              "welcome.title".tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(blurRadius: 4, offset: Offset(2, 2), color: Colors.black54),
                ],
              ),
            ),
          ),

          // Language selector button - top right
          Positioned(
            top: 40,
            right: 16,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: _showLanguageSelector,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.language,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),

          // A soft gradient at bottom for readability
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 260,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(0, 0.2),
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54, Colors.black87],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Dots indicator above button
          Positioned(
            left: 0,
            right: 0,
            bottom: 140 + bottomPadding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(slides.length, (i) {
                final active = currentPage == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 12 : 8,
                  height: active ? 12 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? Colors.white : Colors.white54,
                  ),
                );
              }),
            ),
          ),


          // Bottom buttons
          Positioned(
            left: 16,
            right: 16,
            bottom: 24 + bottomPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Continue with Google (Android only)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _continueWithGoogle,
                    label: Text(
                      "welcome.continueWithGoogle".tr(),
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.white10,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Join as a guest (primary)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _continueAsGuest,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "welcome.joinAsGuest".tr(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_busy)
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                color: Colors.black38,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}