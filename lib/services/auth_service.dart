import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'api_service.dart';

class AuthService {
  final _secureStorage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();
  
  static const String _keyToken = 'jwt_token';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keySavedIdentifier = 'saved_identifier';
  static const String _keySavedRole = 'saved_role';
  static const String _keySavedPassword = 'saved_password';

  // In-memory session password
  String? sessionPassword;

  // Securely save Password
  Future<void> savePassword(String password) async {
    await _secureStorage.write(key: _keySavedPassword, value: password);
  }

  // Retrieve saved Password
  Future<String?> getSavedPassword() async {
    return await _secureStorage.read(key: _keySavedPassword);
  }

  // Delete saved Password
  Future<void> deleteSavedPassword() async {
    await _secureStorage.delete(key: _keySavedPassword);
  }

  // Securely save JWT Token
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _keyToken, value: token);
    apiService.setToken(token);
  }

  // Retrieve saved JWT Token
  Future<String?> getToken() async {
    final token = await _secureStorage.read(key: _keyToken);
    if (token != null) {
      apiService.setToken(token);
    }
    return token;
  }

  // Clear session on logout
  Future<void> logout() async {
    await _secureStorage.delete(key: _keyToken);
    apiService.setToken(null);
  }

  // Persist biometric toggle setting
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
    if (!enabled) {
      await deleteSavedPassword();
    }
  }

  // Check if biometric is enabled by user
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  // Save identifier and role for biometric quick login lookup
  Future<void> saveCredentialsInfo(String identifier, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavedIdentifier, identifier);
    await prefs.setString(_keySavedRole, role);
  }

  Future<Map<String, String?>> getSavedCredentialsInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'identifier': prefs.getString(_keySavedIdentifier),
      'role': prefs.getString(_keySavedRole),
    };
  }

  // Verify device compatibility with biometrics
  Future<bool> canUseBiometrics() async {
    final isSupported = await _auth.isDeviceSupported();
    final canCheck = await _auth.canCheckBiometrics;
    return isSupported || canCheck;
  }

  // Trigger Biometric scanner dialog (Face ID / Fingerprint check)
  Future<bool> authenticateWithBiometrics() async {
    try {
      final availableBiometrics = await _auth.getAvailableBiometrics();
      String localizedReason = 'Vui lòng xác thực vân tay hoặc khuôn mặt để đăng nhập nhanh';
      
      if (availableBiometrics.contains(BiometricType.face)) {
        localizedReason = 'Quét khuôn mặt (Face ID) để đăng nhập';
      }

      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}

final authService = AuthService();
