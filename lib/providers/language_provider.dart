import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const _key = 'language_code';

  /// null = follow system, 'en' or 'de' = override
  String? _languageCode;
  String? get languageCode => _languageCode;

  Locale? get locale =>
      _languageCode != null ? Locale(_languageCode!) : null;

  LanguageProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    _languageCode = saved; // null if never set
    notifyListeners();
  }

  Future<void> setLanguage(String? code) async {
    _languageCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, code);
    }
  }
}
