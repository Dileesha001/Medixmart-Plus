import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Multi-platform backend API host resolver for Medixmart Plus.
///
/// Resolves the default local pharmacy host URL across Flutter Web, Windows
/// desktop, and Android emulator, while allowing runtime LAN IP overrides for
/// physical Android devices on the pharmacy Wi-Fi network.
class ApiConfig {
  static const int defaultPort = 3000;

  /// Optional host IP or full URL override (e.g. `192.168.1.100` or
  /// `http://192.168.1.100:3000`).
  static String customHost = '';

  static String get baseUrl {
    final trimmed = customHost.trim();
    if (trimmed.isNotEmpty) {
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final normalized = trimmed.endsWith('/')
            ? trimmed.substring(0, trimmed.length - 1)
            : trimmed;
        return normalized.endsWith('/api') ? normalized : '$normalized/api';
      }
      final hostWithPort =
          trimmed.contains(':') ? trimmed : '$trimmed:$defaultPort';
      return 'http://$hostWithPort/api';
    }

    if (kIsWeb) {
      return 'http://localhost:$defaultPort/api';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$defaultPort/api';
    }

    return 'http://127.0.0.1:$defaultPort/api';
  }

  static const Duration connectTimeout = Duration(seconds: 5);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
