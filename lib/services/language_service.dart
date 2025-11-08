import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

/// Service to handle language selection and persistence
class LanguageService {
  static const String _kLanguagePreferenceKey = 'saved_locale_code';

  /// Available languages in the app
  static const Map<String, String> availableLanguages = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
    'it': 'Italiano',
    'pt': 'Português',
  };

  /// Flag emojis for each language
  static const Map<String, String> languageFlags = {
    'en': '🇺🇸',
    'es': '🇪🇸',
    'fr': '🇫🇷',
    'de': '🇩🇪',
    'it': '🇮🇹',
    'pt': '🇵🇹',
  };

  /// Save language preference to SharedPreferences
  static Future<void> saveLanguagePreference(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLanguagePreferenceKey, languageCode);
      debugPrint('Language preference saved: $languageCode');
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }

  /// Get saved language preference from SharedPreferences
  static Future<String?> getSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString(_kLanguagePreferenceKey);
      debugPrint('Loaded language preference: $savedLang');
      return savedLang;
    } catch (e) {
      debugPrint('Error loading language preference: $e');
      return null;
    }
  }

  /// Change app language and persist the choice
  static Future<void> changeLanguage(BuildContext context, String languageCode) async {
    try {
      final newLocale = Locale(languageCode);

      // Change the locale using easy_localization
      await context.setLocale(newLocale);

      // Save the preference
      await saveLanguagePreference(languageCode);

      debugPrint('Language changed to: $languageCode');
    } catch (e) {
      debugPrint('Error changing language: $e');
      rethrow;
    }
  }

  /// Get the display name for a language code
  static String getLanguageName(String languageCode) {
    return availableLanguages[languageCode] ?? 'Unknown';
  }

  /// Get the flag emoji for a language code
  static String getLanguageFlag(String languageCode) {
    return languageFlags[languageCode] ?? '🌐';
  }

  /// Get current language code from context
  static String getCurrentLanguageCode(BuildContext context) {
    return context.locale.languageCode;
  }

  /// Returns the column index for the car description based on current locale
  /// The CSV has translations for description in different columns:
  /// - English (en): column 2
  /// - French (fr): column 11
  /// - Italian (it): column 12
  /// - Spanish (es): column 13
  /// - Portuguese (pt): column 14
  /// - German (de): column 15
  static int getDescriptionIndex(BuildContext context) {
    final locale = context.locale.languageCode;

    switch (locale) {
      case 'fr':
        return 11;
      case 'it':
        return 12;
      case 'es':
        return 13;
      case 'pt':
        return 14;
      case 'de':
        return 15;
      case 'en':
      default:
        return 2; // Default to English
    }
  }

  /// Returns the column index for the car special feature based on current locale
  /// The CSV has translations for special feature in different columns:
  /// - English (en): column 10
  /// - French (fr): column 16
  /// - Italian (it): column 17
  /// - Spanish (es): column 18
  /// - Portuguese (pt): column 19
  /// - German (de): column 20
  static int getSpecialFeatureIndex(BuildContext context) {
    final locale = context.locale.languageCode;

    switch (locale) {
      case 'fr':
        return 16;
      case 'it':
        return 17;
      case 'es':
        return 18;
      case 'pt':
        return 19;
      case 'de':
        return 20;
      case 'en':
      default:
        return 10; // Default to English
    }
  }
}
