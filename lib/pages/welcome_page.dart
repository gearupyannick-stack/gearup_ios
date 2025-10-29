// lib/pages/welcome_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../main.dart';
import '../services/lives_storage.dart';

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

  Future<void> _continueWithICloud() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Automatically authenticate with Firebase Anonymous (iCloud data will sync)
      final auth = AuthService();
      await auth.signInAnonymously();
      
      // Mark onboarding done and enter
      await _markOnboardedAndEnter();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not connect: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              "Welcome to GearUp",
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

          // Single "Get Started" button
          Positioned(
            left: 16,
            right: 16,
            bottom: 24 + bottomPadding,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _busy ? null : _continueWithICloud,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  "Get Started",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
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