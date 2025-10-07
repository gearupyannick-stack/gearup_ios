import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage/lives_storage.dart';
import 'challenges/brand_challenge_page.dart';
import 'challenges/models_by_brand_challenge_page.dart';
import 'challenges/model_challenge_page.dart';
import 'challenges/origin_challenge_page.dart';
import 'challenges/engine_type_challenge_page.dart';
import 'challenges/max_speed_challenge_page.dart';
import 'challenges/acceleration_challenge_page.dart';
import 'challenges/power_challenge_page.dart';
import 'challenges/special_feature_challenge_page.dart';

class TrainingPage extends StatefulWidget {
  final VoidCallback? onLifeWon;
  final VoidCallback? recordChallengeCompletion;

  TrainingPage({this.onLifeWon, this.recordChallengeCompletion});

  @override
  _TrainingPageState createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  final LivesStorage livesStorage = LivesStorage();

  Map<String, String> bestResults = {
    'Brand': 'Brand - New challenge',
    'Models by Brand': 'Models by Brand - New challenge',
    'Model': 'Model - New challenge',
    'Origin': 'Origin - New challenge',
    'Engine Type': 'Engine Type - New challenge',
    'Max Speed': 'Max Speed - New challenge',
    'Acceleration': 'Acceleration - New challenge',
    'Power': 'Power - New challenge',
    'Special Feature': 'Special Feature - New challenge',
  };

  @override
  void initState() {
    super.initState();
    _loadBestResults();
  }

  Future<void> _loadBestResults() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      bestResults.forEach((label, _) {
        final key = 'best_${label.replaceAll(' ', '')}';
        bestResults[label] = prefs.getString(key) ?? '$label - New challenge';
      });
    });
  }

  /// New helper for "Coming soon" buttons
  Widget _buildComingSoonButton(String label) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.all(16),
          alignment: Alignment.centerLeft,
        ),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Coming soon'),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Text(label,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildButton(String label, Widget page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.centerLeft,
        ),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          );

        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(bestResults[label]!,
                style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildButton('Brand', BrandChallengePage()),
          _buildButton('Models by Brand', ModelsByBrandChallengePage()),
          _buildButton('Model', ModelChallengePage()),
          _buildButton('Origin', OriginChallengePage()),
          _buildButton('Engine Type', EngineTypeChallengePage()),
          _buildButton('Max Speed', MaxSpeedChallengePage()),
          _buildButton('Acceleration', AccelerationChallengePage()),
          _buildButton('Power', PowerChallengePage()),
          _buildButton('Special Feature', SpecialFeatureChallengePage()),          
          SizedBox(height: 24),
          _buildComingSoonButton('Engine Sound'),
          _buildComingSoonButton('Head lights'),
          _buildComingSoonButton('Rear Lights'),
          _buildComingSoonButton('Signals'),
        ],
      ),
    );
  }
}
