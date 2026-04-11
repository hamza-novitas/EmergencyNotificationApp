import 'package:local_auth/local_auth.dart';

class DeviceAuthService {
  DeviceAuthService._();

  static final LocalAuthentication _localAuth = LocalAuthentication();

  static Future<bool> authenticateIfAvailable({
    String reason = 'Authentication is required to respond to this emergency alert.',
  }) async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isSupported) {
        return true;
      }

      return _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
