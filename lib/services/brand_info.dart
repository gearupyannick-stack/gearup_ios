import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class BrandInfo {
  final String name;
  final String country;
  final String countryFlag;
  final int foundedYear;
  final String tagline;
  final String specialty;
  final String description;

  const BrandInfo({
    required this.name,
    required this.country,
    required this.countryFlag,
    required this.foundedYear,
    required this.tagline,
    required this.specialty,
    required this.description,
  });

  factory BrandInfo.fromJson(Map<String, dynamic> json) {
    return BrandInfo(
      name: json['name'] as String,
      country: json['country'] as String,
      countryFlag: json['countryFlag'] as String,
      foundedYear: json['foundedYear'] as int,
      tagline: json['tagline'] as String,
      specialty: json['specialty'] as String,
      description: json['description'] as String,
    );
  }
}

class BrandInfoData {
  static Map<String, BrandInfo>? _brands;
  static String? _currentLanguage;

  static Future<void> loadBrands(String languageCode) async {
    // Reload if language changed
    if (_brands != null && _currentLanguage == languageCode) return;

    final String jsonString = await rootBundle.loadString('assets/brands/brands_$languageCode.json');
    final Map<String, dynamic> jsonData = json.decode(jsonString);

    _brands = {};
    jsonData.forEach((key, value) {
      _brands![key] = BrandInfo.fromJson(value as Map<String, dynamic>);
    });

    _currentLanguage = languageCode;
  }

  static BrandInfo? getBrandInfo(String brandKey) {
    return _brands?[brandKey];
  }
}
