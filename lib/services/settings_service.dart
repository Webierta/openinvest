import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
//import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

import 'secure_storage_service.dart';

class SettingsService {
  static const String _keyRequireAuth = 'require_auth';
  static const String _keyAppPassword = 'app_password';
  static const String _keyAutoRefresh = 'auto_refresh';
  static const String _keyLastGlobalRefresh = 'last_global_refresh';
  static const String _keyLocale = 'app_locale';
  static final LocalAuthentication _auth = LocalAuthentication();

  // ELIMINADO: static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  // Ya no es necesario, SecureStorageService lo gestiona internamente.
  //static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<bool> isAuthRequired() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRequireAuth) ?? false;
  }

  static Future<void> setAuthRequired(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRequireAuth, value);
  }

  /// Obtiene la contraseña de la app.
  /// SecureStorageService se encarga de usar el keyring del SO o,
  /// si falla en Linux, usa el fallback cifrado local automáticamente.
  static Future<String?> getAppPassword() async {
    return await SecureStorageService.read(_keyAppPassword);
  }

  /// Guarda la contraseña de la app de forma segura.
  static Future<void> setAppPassword(String password) async {
    await SecureStorageService.write(_keyAppPassword, password);
  }

  /// Elimina la contraseña de la app (útil si el usuario desactiva el bloqueo).
  /// Limpia tanto el keyring como el archivo de fallback si existe.
  static Future<void> clearAppPassword() async {
    await SecureStorageService.delete(_keyAppPassword);
  }

  static Future<bool> isAutoRefreshEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoRefresh) ?? true; // Por defecto activado
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

  static Future<String?> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocale);
  }

  static Future<void> setLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, languageCode);
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
        localizedReason: 'Por favor, identíficate para acceder a OpenInvest',
      );
    } on PlatformException catch (_) {
      return false;
    }
  }
}
