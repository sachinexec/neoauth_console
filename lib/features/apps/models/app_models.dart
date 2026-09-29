import '../../../core/json.dart';
import 'login_method.dart';
import 'token_policy.dart';

export 'login_method.dart';
export 'token_policy.dart';

enum AttestationMode {
  off('Off', 'No device check.'),
  report('Report', 'Check devices and log failures, but let sign-ins through. Use while rolling out.'),
  enforce('Enforce', 'Reject native sign-ins from devices or builds that fail the check.');

  const AttestationMode(this.label, this.description);
  final String label;
  final String description;

  static AttestationMode parse(String? v) =>
      AttestationMode.values.firstWhere((m) => m.name == v, orElse: () => AttestationMode.off);
}

class AndroidAttestation {
  const AndroidAttestation({required this.packageName, required this.certificateSha256});
  final String packageName;
  final List<String> certificateSha256;

  factory AndroidAttestation.fromJson(Json j) => AndroidAttestation(
    packageName: optString(j, 'package_name') ?? '',
    certificateSha256: stringList(j, 'certificate_sha256'),
  );

  Json toJson() => {'package_name': packageName, 'certificate_sha256': certificateSha256};

  static final packagePattern = RegExp(r'^[a-zA-Z][\w.]+$');
  static final sha256Pattern = RegExp(r'^([0-9a-fA-F]{2}:?){32}$');
}

class IosAttestation {
  const IosAttestation({required this.teamId, required this.bundleId, this.allowDevelopment = false});
  final String teamId;
  final String bundleId;
  final bool allowDevelopment;

  factory IosAttestation.fromJson(Json j) => IosAttestation(
    teamId: optString(j, 'team_id') ?? '',
    bundleId: optString(j, 'bundle_id') ?? '',
    allowDevelopment: optBool(j, 'allow_development'),
  );

  Json toJson() => {'team_id': teamId, 'bundle_id': bundleId, 'allow_development': allowDevelopment};

  static final teamIdPattern = RegExp(r'^[A-Z0-9]{10}$');
}

/// Device attestation for native clients (backend `AttestationConfig`).
class AttestationConfig {
  const AttestationConfig({this.mode = AttestationMode.off, this.android, this.ios});
  final AttestationMode mode;
  final AndroidAttestation? android;
  final IosAttestation? ios;

  factory AttestationConfig.fromJson(Json j) => AttestationConfig(
    mode: AttestationMode.parse(optString(j, 'mode')),
    android: j['android'] is Map ? AndroidAttestation.fromJson(optMap(j, 'android')) : null,
    ios: j['ios'] is Map ? IosAttestation.fromJson(optMap(j, 'ios')) : null,
  );

  Json toJson() => {'mode': mode.name, 'android': ?android?.toJson(), 'ios': ?ios?.toJson()};

  /// Client-side check matching the server's rules.
  List<String> validate() => [
    if (android != null && !AndroidAttestation.packagePattern.hasMatch(android!.packageName))
      'Android package name is invalid.',
    if (android != null && android!.certificateSha256.isEmpty) 'Add at least one Android signing certificate SHA-256.',
    if (android != null && !android!.certificateSha256.every(AndroidAttestation.sha256Pattern.hasMatch))
      'Certificate fingerprints must be SHA-256 hex digests.',
    if (ios != null && !IosAttestation.teamIdPattern.hasMatch(ios!.teamId))
      'iOS team ID must be 10 uppercase letters or digits.',
    if (ios != null && ios!.bundleId.trim().isEmpty) 'iOS bundle ID is required.',
  ];
}

enum ApplicationType {
  web('Web', 'Browser sign-in through the hosted page (websites, server apps, SPAs).'),
  native('Native', 'iOS and Android apps.');

  const ApplicationType(this.label, this.description);
  final String label;
  final String description;

  static ApplicationType parse(String? v) => v == 'native' ? native : web;
}

/// A client of an app (`presentClient` on the server).
class ClientModel {
  const ClientModel({
    required this.clientId,
    required this.appSlug,
    required this.name,
    required this.applicationType,
    required this.clientType,
    required this.firstParty,
    required this.subjectType,
    required this.nativeLogin,
    required this.redirectUris,
    required this.postLogoutRedirectUris,
    required this.loginMethods,
    required this.tokenPolicyOverride,
    required this.attestation,
    required this.effectiveTokenPolicy,
    required this.effectiveLoginMethods,
    required this.status,
    this.backchannelLogoutUri,
    this.sectorIdentifierUri,
    this.createdAt,
    this.clientSecret,
  });

  final String clientId;
  final String appSlug;
  final String name;
  final ApplicationType applicationType;
  final ClientType clientType;
  final bool firstParty;

  /// `public` (first-party) or `pairwise` (third-party); fixed at creation.
  final String subjectType;
  final bool nativeLogin;
  final List<String> redirectUris;
  final List<String> postLogoutRedirectUris;
  final String? backchannelLogoutUri;
  final String? sectorIdentifierUri;

  /// Null inherits the app's methods.
  final List<LoginMethod>? loginMethods;
  final TokenPolicyInput tokenPolicyOverride;
  final AttestationConfig attestation;
  final TokenPolicy effectiveTokenPolicy;
  final EffectiveLoginMethods effectiveLoginMethods;
  final String status;
  final DateTime? createdAt;

  /// Only present in the response that created a confidential client.
  final String? clientSecret;

  bool get isActive => status == 'active';

  factory ClientModel.fromJson(Json j) => ClientModel(
    clientId: reqString(j, 'client_id'),
    appSlug: optString(j, 'app_slug') ?? '',
    name: optString(j, 'name') ?? '',
    applicationType: ApplicationType.parse(optString(j, 'application_type')),
    clientType: ClientType.parse(optString(j, 'client_type')),
    firstParty: optBool(j, 'first_party', fallback: true),
    subjectType: optString(j, 'subject_type') ?? 'public',
    nativeLogin: optBool(j, 'native_login'),
    redirectUris: stringList(j, 'redirect_uris'),
    postLogoutRedirectUris: stringList(j, 'post_logout_redirect_uris'),
    backchannelLogoutUri: optString(j, 'backchannel_logout_uri'),
    sectorIdentifierUri: optString(j, 'sector_identifier_uri'),
    loginMethods: j['login_methods'] is List ? LoginMethod.parseList(stringList(j, 'login_methods')) : null,
    tokenPolicyOverride: TokenPolicyInput.fromJson(optMap(j, 'token_policy_override')),
    attestation: AttestationConfig.fromJson(optMap(j, 'attestation')),
    effectiveTokenPolicy: TokenPolicy.fromJson(optMap(j, 'effective_token_policy')),
    effectiveLoginMethods: EffectiveLoginMethods.fromJson(optMap(j, 'effective_login_methods')),
    status: optString(j, 'status') ?? 'active',
    createdAt: optDate(j, 'created_at'),
    clientSecret: optString(j, 'client_secret'),
  );
}

/// A webhook endpoint (`WebhookEndpointView`). [secret] only on creation.
class WebhookEndpoint {
  const WebhookEndpoint({
    required this.id,
    required this.url,
    required this.events,
    required this.status,
    this.createdAt,
    this.secret,
  });

  final String id;
  final String url;
  final List<String> events;
  final String status;
  final DateTime? createdAt;
  final String? secret;

  factory WebhookEndpoint.fromJson(Json j) => WebhookEndpoint(
    id: reqString(j, 'id'),
    url: reqString(j, 'url'),
    events: stringList(j, 'events'),
    status: optString(j, 'status') ?? 'active',
    createdAt: optDate(j, 'created_at'),
    secret: optString(j, 'secret'),
  );

  /// Backend WEBHOOK_EVENTS.
  static const allEvents = {
    'user.updated': 'Profile changed',
    'user.suspended': 'Account suspended',
    'user.unsuspended': 'Account restored',
    'user.deleted': 'Account deleted',
    'session.revoked': 'Session signed out',
  };
}

/// Result of `POST .../webhooks/:id/ping`.
class PingResult {
  const PingResult({this.status, this.error});
  final int? status;
  final String? error;

  bool get ok => status != null && status! >= 200 && status! < 300;

  factory PingResult.fromJson(Json j) => PingResult(status: optInt(j, 'status'), error: optString(j, 'error'));
}

/// An app (`presentApp` on the server). [webhooks] is only filled by `GET /apps/:slug`.
class AppModel {
  const AppModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.apiAudience,
    required this.loginMethods,
    required this.tokenPolicy,
    required this.status,
    required this.isConsole,
    required this.clients,
    this.description,
    this.iconUrl,
    this.marketingUrl,
    this.createdAt,
    this.webhooks,
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final String apiAudience;
  final String? iconUrl;
  final String? marketingUrl;
  final List<LoginMethod> loginMethods;
  final TokenPolicyInput tokenPolicy;
  final String status;
  final bool isConsole;
  final List<ClientModel> clients;
  final DateTime? createdAt;
  final List<WebhookEndpoint>? webhooks;

  bool get isActive => status == 'active';

  /// The app's policy with server defaults filled in.
  TokenPolicy get resolvedPolicy => tokenPolicy.resolve(TokenPolicy.defaults);

  /// Webhooks carry internal user IDs, so the server allows them only on apps
  /// whose clients are all first-party.
  bool get webhooksAllowed => clients.every((c) => c.firstParty);

  factory AppModel.fromJson(Json j) => AppModel(
    id: reqString(j, 'id'),
    slug: reqString(j, 'slug'),
    name: optString(j, 'name') ?? '',
    description: optString(j, 'description'),
    apiAudience: optString(j, 'api_audience') ?? '',
    iconUrl: optString(j, 'icon_url'),
    marketingUrl: optString(j, 'marketing_url'),
    loginMethods: LoginMethod.parseList(stringList(j, 'login_methods')),
    tokenPolicy: TokenPolicyInput.fromJson(optMap(j, 'token_policy')),
    status: optString(j, 'status') ?? 'active',
    isConsole: optBool(j, 'is_console'),
    clients: objList(j, 'clients', ClientModel.fromJson),
    createdAt: optDate(j, 'created_at'),
    webhooks: j['webhooks'] is List ? objList(j, 'webhooks', WebhookEndpoint.fromJson) : null,
  );

  static final slugPattern = RegExp(r'^[a-z0-9][a-z0-9-]{1,39}$');
}
