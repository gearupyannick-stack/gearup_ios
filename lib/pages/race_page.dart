import 'package:flutter/material.dart';


class RacePage extends StatelessWidget {
  const RacePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Coming Soon graphic
              Image.asset(
                'assets/home/race.png',
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32),
              // Mysterious teaser
              const Text(
                'Prepare for the ultimate showdown.\n'
                'Form your team, earn your gears,\n'
                'and go head-to-head with up to 10 rivals\n'
                'in real-time multiplayer…\n'
                'Coming soon.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
