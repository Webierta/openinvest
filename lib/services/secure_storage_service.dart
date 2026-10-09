import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static encrypt.Encrypter? _fallbackEncrypter;
  static const String _fallbackFileName = 'openinvest_fallback.dat';

  // Sal estática para derivar la clave. No es seguridad de grado militar,
  // pero evita la lectura casual del archivo de fallback.
  static const String _appSalt = 'OpenInvest_SecureFallback_Salt_2024!';

  /// Obtiene o crea el cifrador de fallback basado en el usuario del sistema.
  static Future<encrypt.Encrypter> _getFallbackEncrypter() async {
    if (_fallbackEncrypter != null) return _fallbackEncrypter!;

    // Usamos el usuario del sistema como parte de la clave.
    // Si no está disponible, usamos un valor por defecto.
    final user =
        Platform.environment['USER'] ??
        Platform.environment['USERNAME'] ??
        'default_user';

    // AES requiere una clave de 32 bytes (256 bits). Rellenamos o recortamos.
    final rawKey = '$user$_appSalt';
    final paddedKey = rawKey.padRight(32, '0').substring(0, 32);

    _fallbackEncrypter = encrypt.Encrypter(
      encrypt.AES(encrypt.Key.fromUtf8(paddedKey)),
    );
    return _fallbackEncrypter!;
  }

  /// Lee un valor. Intenta el almacenamiento seguro primero; si falla en Linux, usa el fallback.
  static Future<String?> read(String key) async {
    if (!Platform.isLinux) {
      return await _storage.read(key: key);
    }

    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint(
        '⚠️ [Linux] flutter_secure_storage falló: $e. Usando fallback cifrado.',
      );
      return await _readFallback(key);
    }
  }

  /// Escribe un valor. Intenta el almacenamiento seguro primero; si falla en Linux, usa el fallback.
  static Future<void> write(String key, String value) async {
    if (!Platform.isLinux) {
      await _storage.write(key: key, value: value);
      return;
    }

    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint(
        '⚠️ [Linux] flutter_secure_storage falló al escribir: $e. Usando fallback cifrado.',
      );
      await _writeFallback(key, value);
    }
  }

  /// Elimina un valor de ambos almacenes para mantener la limpieza.
  static Future<void> delete(String key) async {
    if (Platform.isLinux) {
      try {
        await _storage.delete(key: key);
      } catch (_) {
        // Ignorar si ya falló el almacenamiento seguro
      }
    } else {
      await _storage.delete(key: key);
    }
    await _deleteFallback(key);
  }

  // --- Métodos Privados del Fallback ---

  static Future<String?> _readFallback(String key) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$_fallbackFileName');
      if (!await file.exists()) return null;

      final encryptedData = await file.readAsString();
      final encrypter = await _getFallbackEncrypter();
      final decrypted = encrypter.decrypt(
        encrypt.Encrypted.fromBase64(encryptedData),
      );

      // El formato del fallback es "clave=valor"
      final parts = decrypted.split('=');
      if (parts.length == 2 && parts[0] == key) {
        return parts[1];
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error al leer el fallback de seguridad: $e');
      return null;
    }
  }

  static Future<void> _writeFallback(String key, String value) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$_fallbackFileName');
      final encrypter = await _getFallbackEncrypter();

      final dataToEncrypt = '$key=$value';
      final encrypted = encrypter.encrypt(dataToEncrypt);

      await file.writeAsString(encrypted.base64);
    } catch (e) {
      debugPrint('❌ Error al escribir en el fallback de seguridad: $e');
    }
  }

  static Future<void> _deleteFallback(String key) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$_fallbackFileName');
      if (await file.exists()) {
        // Para simplificar, si hay múltiples claves, borramos todo el archivo
        // o podrías implementar un parseo para borrar solo la línea.
        // Dado que OpenInvest solo guarda 1-2 claves de auth, borrar el archivo es seguro.
        await file.delete();
      }
    } catch (e) {
      debugPrint('❌ Error al eliminar el fallback de seguridad: $e');
    }
  }
}
