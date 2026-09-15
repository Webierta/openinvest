import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class SettingsService {
  static const String _keyRequireAuth = 'require_auth';
  static const String _keyAppPassword = 'app_password';
  static const String _keyAutoRefresh = 'auto_refresh';
  static const String _keyLastGlobalRefresh = 'last_global_refresh';
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAuthRequired() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRequireAuth) ?? false;
  }

  static Future<void> setAuthRequired(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRequireAuth, value);
  }

  static Future<String?> getAppPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAppPassword);
  }

  static Future<void> setAppPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppPassword, password);
  }

  static Future<bool> isAutoRefreshEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoRefresh) ?? false;
  }

  static Future<void> setAutoRefreshEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoRefresh, value);
  }

  static Future<DateTime?> getLastGlobalRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyLastGlobalRefresh);
    return value == null ? null : DateTime.tryParse(value);
  }

  static Future<void> setLastGlobalRefresh(DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastGlobalRefresh, value.toIso8601String());
  }

  static Future<bool> canAuthenticate() async {
    if (Platform.isLinux) {
      return true; // Siempre podemos usar contraseña en Linux
    }

    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate({String? password}) async {
    if (Platform.isLinux) {
      if (password == null || password.trim().isEmpty) return false;

      final saved = await getAppPassword();
      if (saved == null || saved.trim().isEmpty) return false;

      return saved == password;
    }

    try {
      return await _auth.authenticate(
        localizedReason: 'Por favor, autentícate para acceder a OpenInvest',
      );
    } on PlatformException catch (_) {
      return false;
    }
  }
}
