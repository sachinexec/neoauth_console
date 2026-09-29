import '../../../core/format.dart';
import '../../../core/json.dart';

enum RefreshTokenMode {
  rotating('Rotating', 'A refresh token is issued and replaced on every use.'),
  none('None', 'No refresh token: the user signs in again when the access token expires.');

  const RefreshTokenMode(this.label, this.description);
  final String label;
  final String description;

  static RefreshTokenMode parse(String? v) => v == 'none' ? none : rotating;
}

enum ClientType {
  public('Public', 'Mobile apps and single-page web apps. Cannot keep a secret; uses PKCE.'),
  confidential('Confidential', 'Server-side web apps that can keep a client secret.');

  const ClientType(this.label, this.description);
  final String label;
  final String description;

  static ClientType parse(String? v) => v == 'confidential' ? confidential : public;
}

/// Limits enforced by the server (backend `token-policy.ts` BOUNDS), seconds.
abstract final class PolicyBounds {
  static const minute = 60;
  static const hour = 3600;
  static const day = 86400;

  static const accessMin = 5 * minute;
  static const accessMaxPublic = hour;
  static const accessMaxConfidential = day;
  static const idleMin = hour;
  static const idleMax = 90 * day;
  static const absoluteMin = hour;
  static const absoluteMax = 400 * day;
  static const sessionMaxAgeMin = 5 * minute;

  static int accessMax(ClientType t) => t == ClientType.public ? accessMaxPublic : accessMaxConfidential;
}

/// A fully resolved policy (the server's `effective_token_policy`).
class TokenPolicy {
  const TokenPolicy({
    required this.accessTokenTtl,
    required this.refreshTokenMode,
    required this.refreshIdleTtl,
    required this.refreshAbsoluteTtl,
    this.sessionMaxAge,
  });

  final int accessTokenTtl;
  final RefreshTokenMode refreshTokenMode;
  final int refreshIdleTtl;
  final int refreshAbsoluteTtl;

  /// Null: no forced re-sign-in.
  final int? sessionMaxAge;

  /// Backend DEFAULT_POLICY.
  static const defaults = TokenPolicy(
    accessTokenTtl: 10 * PolicyBounds.minute,
    refreshTokenMode: RefreshTokenMode.rotating,
    refreshIdleTtl: 30 * PolicyBounds.day,
    refreshAbsoluteTtl: 90 * PolicyBounds.day,
  );

  factory TokenPolicy.fromJson(Json j) => TokenPolicyInput.fromJson(j).resolve(defaults);

  TokenPolicyInput toInput() => TokenPolicyInput(
    accessTokenTtl: accessTokenTtl,
    refreshTokenMode: refreshTokenMode,
    refreshIdleTtl: refreshIdleTtl,
    refreshAbsoluteTtl: refreshAbsoluteTtl,
    sessionMaxAge: sessionMaxAge,
    hasSessionMaxAge: true,
  );

  String get summary => [
    'Access ${formatSeconds(accessTokenTtl)}',
    if (refreshTokenMode == RefreshTokenMode.none)
      'no refresh'
    else
      'idle ${formatSeconds(refreshIdleTtl)}, max ${formatSeconds(refreshAbsoluteTtl)}',
    if (sessionMaxAge != null) 're-sign-in after ${formatSeconds(sessionMaxAge!)}',
  ].join(' · ');

  @override
  bool operator ==(Object other) =>
      other is TokenPolicy &&
      other.accessTokenTtl == accessTokenTtl &&
      other.refreshTokenMode == refreshTokenMode &&
      other.refreshIdleTtl == refreshIdleTtl &&
      other.refreshAbsoluteTtl == refreshAbsoluteTtl &&
      other.sessionMaxAge == sessionMaxAge;

  @override
  int get hashCode => Object.hash(accessTokenTtl, refreshTokenMode, refreshIdleTtl, refreshAbsoluteTtl, sessionMaxAge);
}

/// A partial policy, as stored on an app (`token_policy`) or a client
/// (`token_policy_override`). Unset fields inherit. `session_max_age` has
/// three states: unset (inherit), null (no limit) or seconds.
class TokenPolicyInput {
  const TokenPolicyInput({
    this.accessTokenTtl,
    this.refreshTokenMode,
    this.refreshIdleTtl,
    this.refreshAbsoluteTtl,
    this.sessionMaxAge,
    this.hasSessionMaxAge = false,
  });

  static const empty = TokenPolicyInput();

  final int? accessTokenTtl;
  final RefreshTokenMode? refreshTokenMode;
  final int? refreshIdleTtl;
  final int? refreshAbsoluteTtl;
  final int? sessionMaxAge;
  final bool hasSessionMaxAge;

  bool get isEmpty =>
      accessTokenTtl == null &&
      refreshTokenMode == null &&
      refreshIdleTtl == null &&
      refreshAbsoluteTtl == null &&
      !hasSessionMaxAge;

  factory TokenPolicyInput.fromJson(Json j) => TokenPolicyInput(
    accessTokenTtl: optInt(j, 'access_token_ttl'),
    refreshTokenMode: j['refresh_token_mode'] == null
        ? null
        : RefreshTokenMode.parse(optString(j, 'refresh_token_mode')),
    refreshIdleTtl: optInt(j, 'refresh_idle_ttl'),
    refreshAbsoluteTtl: optInt(j, 'refresh_absolute_ttl'),
    sessionMaxAge: optInt(j, 'session_max_age'),
    hasSessionMaxAge: j.containsKey('session_max_age'),
  );

  Json toJson() => {
    'access_token_ttl': ?accessTokenTtl,
    'refresh_token_mode': ?refreshTokenMode?.name,
    'refresh_idle_ttl': ?refreshIdleTtl,
    'refresh_absolute_ttl': ?refreshAbsoluteTtl,
    if (hasSessionMaxAge) 'session_max_age': sessionMaxAge,
  };

  /// Fills unset fields from [base] (no clamping; the server clamps on read).
  TokenPolicy resolve(TokenPolicy base) => TokenPolicy(
    accessTokenTtl: accessTokenTtl ?? base.accessTokenTtl,
    refreshTokenMode: refreshTokenMode ?? base.refreshTokenMode,
    refreshIdleTtl: refreshIdleTtl ?? base.refreshIdleTtl,
    refreshAbsoluteTtl: refreshAbsoluteTtl ?? base.refreshAbsoluteTtl,
    sessionMaxAge: hasSessionMaxAge ? sessionMaxAge : base.sessionMaxAge,
  );

  @override
  bool operator ==(Object other) =>
      other is TokenPolicyInput &&
      other.accessTokenTtl == accessTokenTtl &&
      other.refreshTokenMode == refreshTokenMode &&
      other.refreshIdleTtl == refreshIdleTtl &&
      other.refreshAbsoluteTtl == refreshAbsoluteTtl &&
      other.hasSessionMaxAge == hasSessionMaxAge &&
      other.sessionMaxAge == sessionMaxAge;

  @override
  int get hashCode => Object.hash(
    accessTokenTtl,
    refreshTokenMode,
    refreshIdleTtl,
    refreshAbsoluteTtl,
    hasSessionMaxAge,
    sessionMaxAge,
  );
}

/// Which field a validation message is about, so the editor can show it inline.
enum PolicyField { accessTokenTtl, refreshIdleTtl, refreshAbsoluteTtl, sessionMaxAge }

class PolicyError {
  const PolicyError(this.field, this.message);
  final PolicyField field;
  final String message;
  @override
  String toString() => message;
}

/// Mirrors the server's `validatePolicy`, with readable durations. An app
/// policy is checked as [ClientType.public], since any of its clients may be.
List<PolicyError> validatePolicy(TokenPolicyInput p, {ClientType clientType = ClientType.public}) {
  final errors = <PolicyError>[];
  final at = p.accessTokenTtl;
  if (at != null) {
    final max = PolicyBounds.accessMax(clientType);
    if (at < PolicyBounds.accessMin || at > max) {
      errors.add(
        PolicyError(
          PolicyField.accessTokenTtl,
          'Must be between ${formatSeconds(PolicyBounds.accessMin)} and ${formatSeconds(max)}'
          '${clientType == ClientType.public ? ' (public clients)' : ''}.',
        ),
      );
    }
  }
  final idle = p.refreshIdleTtl;
  if (idle != null && (idle < PolicyBounds.idleMin || idle > PolicyBounds.idleMax)) {
    errors.add(
      PolicyError(
        PolicyField.refreshIdleTtl,
        'Must be between ${formatSeconds(PolicyBounds.idleMin)} and ${formatSeconds(PolicyBounds.idleMax)}.',
      ),
    );
  }
  final abs = p.refreshAbsoluteTtl;
  if (abs != null && (abs < PolicyBounds.absoluteMin || abs > PolicyBounds.absoluteMax)) {
    errors.add(
      PolicyError(
        PolicyField.refreshAbsoluteTtl,
        'Must be between ${formatSeconds(PolicyBounds.absoluteMin)} and ${formatSeconds(PolicyBounds.absoluteMax)}.',
      ),
    );
  }
  if (idle != null && abs != null && idle > abs) {
    errors.add(
      const PolicyError(PolicyField.refreshIdleTtl, 'Idle timeout cannot be longer than the maximum lifetime.'),
    );
  }
  final sma = p.sessionMaxAge;
  if (p.hasSessionMaxAge && sma != null && sma < PolicyBounds.sessionMaxAgeMin) {
    errors.add(
      PolicyError(
        PolicyField.sessionMaxAge,
        'Must be at least ${formatSeconds(PolicyBounds.sessionMaxAgeMin)}, or off.',
      ),
    );
  }
  return errors;
}

/// One-tap starting points in the policy editor.
class PolicyPreset {
  const PolicyPreset(this.name, this.description, this.policy);
  final String name;
  final String description;
  final TokenPolicy policy;

  static const sensitive = PolicyPreset(
    'Sensitive',
    'Short sessions for admin and payment apps: sign in again after 12 hours.',
    TokenPolicy(
      accessTokenTtl: 5 * PolicyBounds.minute,
      refreshTokenMode: RefreshTokenMode.rotating,
      // 30 minutes was asked for, but the server's minimum idle timeout is 1 hour.
      refreshIdleTtl: PolicyBounds.idleMin,
      refreshAbsoluteTtl: 12 * PolicyBounds.hour,
      sessionMaxAge: 12 * PolicyBounds.hour,
    ),
  );

  static const standard = PolicyPreset(
    'Standard',
    'The server default: signed in for up to 90 days, 30 days when idle.',
    TokenPolicy(
      accessTokenTtl: 10 * PolicyBounds.minute,
      refreshTokenMode: RefreshTokenMode.rotating,
      refreshIdleTtl: 30 * PolicyBounds.day,
      refreshAbsoluteTtl: 90 * PolicyBounds.day,
    ),
  );

  static const staySignedIn = PolicyPreset(
    'Stay signed in',
    'Consumer apps: signed in for over a year, 90 days when idle.',
    TokenPolicy(
      accessTokenTtl: 60 * PolicyBounds.minute,
      refreshTokenMode: RefreshTokenMode.rotating,
      refreshIdleTtl: 90 * PolicyBounds.day,
      refreshAbsoluteTtl: 400 * PolicyBounds.day,
    ),
  );

  static const all = [sensitive, standard, staySignedIn];
}
