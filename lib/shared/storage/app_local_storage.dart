import 'package:shared_preferences/shared_preferences.dart';

/// Single access point for local key-value persistence.
///
/// Feature stores may keep separate domain keys, but they should not open
/// SharedPreferences directly. This keeps the storage backend replaceable and
/// gives us one place for future migrations, backups and diagnostics.
class AppLocalStorage {
  AppLocalStorage._();

  static Future<String?> readString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> writeString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(key, value);
    if (!saved) {
      throw StateError('Failed to persist local value for key: $key');
    }
  }

  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final removed = await prefs.remove(key);
    if (!removed && prefs.containsKey(key)) {
      throw StateError('Failed to remove local value for key: $key');
    }
  }

  static Future<bool> containsKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(key);
  }
}
