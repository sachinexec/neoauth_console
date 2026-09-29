import 'dart:io' show Platform;

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration for one environment (flavor).
///
/// Values come from `.env.dev` or `.env.prod`, picked by the `--flavor` the app
/// was built with (see `loadEnvironment`). A `--dart-define` of the same name
/// overrides the file, for one-off builds:
///
/// ```sh
/// fvm flutter run --flavor dev
/// fvm flutter run --flavor prod --dart-define=NEOAUTH_ISSUER=https://auth.example.com
/// ```
class AppConfig {
  const AppConfig({required this.issuer, required this.clientId, required this.flavor});

  /// The auth server, without a trailing slash.
  final String issuer;

  /// The console's native client ID for this environment.
  final String clientId;

  /// `dev` or `prod`.
  final String flavor;

  bool get isProd => flavor == 'prod';

  /// Base URL of the admin API. Also the console's access-token audience.
  String get adminBaseUrl => '$issuer/admin';

  static const _issuerDefine = String.fromEnvironment('NEOAUTH_ISSUER');
  static const _clientIdDefine = String.fromEnvironment('NEOAUTH_CLIENT_ID');

  /// Builds the config from dart-defines, then the loaded env file.
  ///
  /// A `localhost` issuer means "this machine": the Android emulator reaches
  /// the host at 10.0.2.2, so it's rewritten there.
  factory AppConfig.fromEnvironment({bool? isAndroid, String? flavor, Map<String, String>? env}) {
    final values = env ?? _dotenv();
    String pick(String define, String key) => define.isNotEmpty ? define : (values[key] ?? '');

    var issuer = stripTrailingSlash(pick(_issuerDefine, 'NEOAUTH_ISSUER'));
    if (issuer.isEmpty) issuer = 'http://localhost:3000';
    if (isAndroid ?? Platform.isAndroid) {
      issuer = issuer.replaceFirst(RegExp(r'^http://(localhost|127\.0\.0\.1)(?=[:/]|$)'), 'http://10.0.2.2');
    }
    return AppConfig(
      issuer: issuer,
      clientId: pick(_clientIdDefine, 'NEOAUTH_CLIENT_ID'),
      flavor: flavor ?? values['APP_ENV'] ?? 'dev',
    );
  }

  static Map<String, String> _dotenv() => dotenv.isInitialized ? dotenv.env : const {};

  static String stripTrailingSlash(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}

/// Loads `.env.<flavor>`. `appFlavor` is compiled in from the Gradle/Xcode
/// `--flavor`; a build without one (e.g. `flutter test`) gets dev, never prod.
Future<void> loadEnvironment(String? appFlavor) => dotenv.load(fileName: '.env.${appFlavor ?? 'dev'}');
