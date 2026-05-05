// lib/core/services/auth_storage_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorageService {
  static const _tokenKey       = 'auth_token';
  static const _userNameKey    = 'user_name';
  static const _userRoleKey    = 'user_role';
  static const _userIdKey      = 'user_id';
  static const _permissionsKey = 'user_permissions';

  // ───────────────── SAVE ─────────────────

  static Future<void> saveAuth({
    required String token,
    String? userName,
    String? userRole,
    int? userId,
    List<String> permissions = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_tokenKey, token);

    if (userName != null) {
      await prefs.setString(_userNameKey, userName);
    }

    if (userRole != null) {
      await prefs.setString(_userRoleKey, userRole);
    }

    if (userId != null) {
      await prefs.setInt(_userIdKey, userId);
    }

    // 🔥 Important: remove old format before saving new one
    await prefs.remove(_permissionsKey);
    await prefs.setStringList(_permissionsKey, permissions);
  }

  // ───────────────── READ ─────────────────

  static Future<SharedPreferences> _prefs() async {
    return await SharedPreferences.getInstance();
  }

  static Future<String?> getToken() async {
    return (await _prefs()).getString(_tokenKey);
  }

  static Future<String?> getUserName() async {
    return (await _prefs()).getString(_userNameKey);
  }

  static Future<String?> getUserRole() async {
    return (await _prefs()).getString(_userRoleKey);
  }

  /// Supports both int (new) and String (old)
  static Future<int?> getUserId() async {
    final prefs = await _prefs();

    final intVal = prefs.getInt(_userIdKey);
    if (intVal != null) return intVal;

    final strVal = prefs.getString(_userIdKey);
    if (strVal != null) return int.tryParse(strVal);

    return null;
  }

  /// Handles:
  /// - New: List<String>
  /// - Old: JSON String
  /// - Corrupt data safely
  static Future<List<String>> getPermissions() async {
    final prefs = await _prefs();

    // ✅ Try new format
    try {
      final list = prefs.getStringList(_permissionsKey);
      if (list != null) return list;
    } catch (_) {
      // ignore and fallback
    }

    // ✅ Try old JSON format
    try {
      final raw = prefs.getString(_permissionsKey);

      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);

        if (decoded is List) {
          final result = decoded.map((e) => e.toString()).toList();

          // 🔥 Auto-migrate to new format
          await prefs.remove(_permissionsKey);
          await prefs.setStringList(_permissionsKey, result);

          return result;
        }
      }
    } catch (_) {
      // ignore corrupt data
    }

    return [];
  }

  // ───────────────── CLEAR ─────────────────

  static Future<void> clear() async {
    final prefs = await _prefs();

    await Future.wait([
      prefs.remove(_tokenKey),
      prefs.remove(_userNameKey),
      prefs.remove(_userRoleKey),
      prefs.remove(_userIdKey),
      prefs.remove(_permissionsKey),
    ]);
  }

  // ───────────────── HELPERS ─────────────────

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}