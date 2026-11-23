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
  const AppConfig({
    required this.issuer,
    required this.clientId,
    required this.flavor,
    this.billingUrl = '',
    this.billingResource = '',
    this.extraInstances = const [],
  });

  /// The auth server, without a trailing slash.
  final String issuer;

  /// The console's native client ID for this environment.
  final String clientId;

  /// `dev` or `prod`.
  final String flavor;

  bool get isProd => flavor == 'prod';

  /// Base URL of the admin API. Also the console's access-token audience.
  String get adminBaseUrl => '$issuer/admin';

  /// The billing service (`neobilling-backend`), without a trailing slash;
  /// empty when this environment has no billing section.
  final String billingUrl;

  /// Token audience for the billing admin API, when it is not the console's
  /// own. Empty: the console's own access token is sent (the billing service's
  /// `ADMIN_AUDIENCE` must then equal [adminBaseUrl]).
  final String billingResource;

  /// Base URL of the billing admin API, or null when billing is not set up or
  /// the URL would send admin tokens over plain http to a remote host.
  String? get billingAdminBaseUrl {
    final uri = Uri.tryParse(billingUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && _isLocal(uri.host))) return null;
    return '$billingUrl/admin/v1';
  }

  bool get billingConfigured => billingAdminBaseUrl != null;

  /// Further, fully separate deployments of the auth service the console can
  /// switch to (`NEOAUTH_INSTANCES`). Empty: only [primaryInstance].
  final List<ConsoleInstance> extraInstances;

  /// The instance configured by `NEOAUTH_ISSUER` / `NEOAUTH_CLIENT_ID`. The
  /// only one with the Billing section.
  ConsoleInstance get primaryInstance =>
      ConsoleInstance(id: ConsoleInstance.primaryId, label: 'Primary', issuer: issuer, clientId: clientId);

  /// [primaryInstance], then [extraInstances] in their configured order.
  List<ConsoleInstance> get instances => [primaryInstance, ...extraInstances];

  bool get hasExtraInstances => extraInstances.isNotEmpty;

  /// The instance with [id], or the primary one when [id] is null or no
  /// longer configured.
  ConsoleInstance instanceById(String? id) => instances.firstWhere((i) => i.id == id, orElse: () => primaryInstance);

  static const _issuerDefine = String.fromEnvironment('NEOAUTH_ISSUER');
  static const _clientIdDefine = String.fromEnvironment('NEOAUTH_CLIENT_ID');
  static const _billingUrlDefine = String.fromEnvironment('BILLING_URL');
  static const _billingResourceDefine = String.fromEnvironment('BILLING_RESOURCE');
  static const _instancesDefine = String.fromEnvironment('NEOAUTH_INSTANCES');

  /// Builds the config from dart-defines, then the loaded env file.
  ///
  /// A `localhost` issuer means "this machine": the Android emulator reaches
  /// the host at 10.0.2.2, so it's rewritten there (for every instance).
  ///
  /// Throws a [FormatException] naming the problem when `NEOAUTH_INSTANCES`
  /// is malformed.
  factory AppConfig.fromEnvironment({bool? isAndroid, String? flavor, Map<String, String>? env}) {
    final values = env ?? _dotenv();
    String pick(String define, String key) => define.isNotEmpty ? define : (values[key] ?? '');

    final android = isAndroid ?? Platform.isAndroid;
    final configuredIssuer = stripTrailingSlash(pick(_issuerDefine, 'NEOAUTH_ISSUER'));
    var issuer = _forEmulator(configuredIssuer, android);
    if (issuer.isEmpty) issuer = 'http://localhost:3000';
    return AppConfig(
      issuer: issuer,
      clientId: pick(_clientIdDefine, 'NEOAUTH_CLIENT_ID'),
      flavor: flavor ?? values['APP_ENV'] ?? 'dev',
      billingUrl: _forEmulator(stripTrailingSlash(pick(_billingUrlDefine, 'BILLING_URL').trim()), android),
      billingResource: pick(_billingResourceDefine, 'BILLING_RESOURCE').trim(),
      extraInstances: parseInstances(
        pick(_instancesDefine, 'NEOAUTH_INSTANCES'),
        primaryIssuer: configuredIssuer.isEmpty ? issuer : configuredIssuer,
      ).map((i) => i.copyWith(issuer: _forEmulator(i.issuer, android))).toList(),
    );
  }

  /// Parses `NEOAUTH_INSTANCES`: comma-separated `Label|https://issuer|client-id`
  /// entries, e.g. `Partner|https://auth.partner.example.com|neoauth-console.native.XXXX`.
  /// Blank means none. Labels and issuers must be unique, and no issuer may
  /// repeat [primaryIssuer]. Issuers must be https (http only for localhost /
  /// 127.0.0.1 / 10.0.2.2), since admin tokens are sent to them.
  static List<ConsoleInstance> parseInstances(String raw, {required String primaryIssuer}) {
    final value = raw.trim();
    if (value.isEmpty) return const [];
    Never fail(int n, String problem) => throw FormatException(
      'NEOAUTH_INSTANCES entry $n: $problem. Expected comma-separated "Label|https://issuer|client-id" entries.',
    );
    final labels = <String>{'primary'};
    final issuers = <String>{stripTrailingSlash(primaryIssuer)};
    final result = <ConsoleInstance>[];
    final entries = value.split(',');
    for (var i = 0; i < entries.length; i++) {
      final n = i + 1;
      final parts = entries[i].split('|').map((p) => p.trim()).toList();
      if (parts.length != 3) fail(n, 'has ${parts.length} "|"-separated part(s), not 3');
      final (label, rawIssuer, clientId) = (parts[0], parts[1], parts[2]);
      if (label.isEmpty) fail(n, 'the label is empty');
      if (!labels.add(label.toLowerCase())) fail(n, 'the label "$label" is used twice (or is "Primary")');
      final issuer = stripTrailingSlash(rawIssuer);
      final uri = Uri.tryParse(issuer);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty || uri.hasQuery || uri.hasFragment) {
        fail(n, '"$rawIssuer" is not an absolute issuer URL');
      }
      if (uri.scheme != 'https' && !(uri.scheme == 'http' && _isLocal(uri.host))) {
        fail(n, '"$rawIssuer" must use https (http only for localhost)');
      }
      if (!issuers.add(issuer)) fail(n, 'the issuer "$issuer" is already configured');
      if (clientId.isEmpty || clientId.contains(RegExp(r'\s'))) fail(n, 'the client ID is empty or has spaces');
      result.add(ConsoleInstance(id: issuer, label: label, issuer: issuer, clientId: clientId));
    }
    return List.unmodifiable(result);
  }

  static bool _isLocal(String host) => host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';

  static String _forEmulator(String url, bool android) =>
      android ? url.replaceFirst(RegExp(r'^http://(localhost|127\.0\.0\.1)(?=[:/]|$)'), 'http://10.0.2.2') : url;

  static Map<String, String> _dotenv() => dotenv.isInitialized ? dotenv.env : const {};

  static String stripTrailingSlash(String url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}

/// One deployment of the auth service: its own issuer, database, users and
/// admins, and its own console client.
class ConsoleInstance {
  const ConsoleInstance({required this.id, required this.label, required this.issuer, required this.clientId});

  static const primaryId = 'primary';

  /// Stable across launches: [primaryId], or the issuer for the others (as
  /// configured, before any emulator rewrite).
  final String id;

  /// Shown in the instance picker and banner.
  final String label;

  /// The auth server, without a trailing slash.
  final String issuer;

  /// This instance's console client ID (each instance bootstraps its own).
  final String clientId;

  bool get isPrimary => id == primaryId;

  /// Base URL of this instance's admin API, and its access-token audience.
  String get adminBaseUrl => '$issuer/admin';

  /// The SDK's secure-storage key, so sessions of different instances never
  /// mix. Null for the primary instance: it keeps the SDK default, so sessions
  /// stored before instances existed stay signed in.
  String? get storageKey => isPrimary ? null : 'console.instance.${id.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}';

  ConsoleInstance copyWith({String? issuer}) =>
      ConsoleInstance(id: id, label: label, issuer: issuer ?? this.issuer, clientId: clientId);

  @override
  bool operator ==(Object other) =>
      other is ConsoleInstance &&
      other.id == id &&
      other.label == label &&
      other.issuer == issuer &&
      other.clientId == clientId;

  @override
  int get hashCode => Object.hash(id, label, issuer, clientId);

  @override
  String toString() => 'ConsoleInstance($label, $issuer)';
}

/// Loads `.env.<flavor>`. `appFlavor` is compiled in from the Gradle/Xcode
/// `--flavor`; a build without one (e.g. `flutter test`) gets dev, never prod.
Future<void> loadEnvironment(String? appFlavor) => dotenv.load(fileName: '.env.${appFlavor ?? 'dev'}');
