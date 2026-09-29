import 'package:neoauth_console/core/format.dart';
import 'package:neoauth_console/features/apps/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const min = PolicyBounds.minute;
  const hour = PolicyBounds.hour;
  const day = PolicyBounds.day;

  List<PolicyField> fields(TokenPolicyInput p, [ClientType t = ClientType.public]) =>
      validatePolicy(p, clientType: t).map((e) => e.field).toList();

  test('every preset passes the server bounds for public clients', () {
    for (final p in PolicyPreset.all) {
      expect(validatePolicy(p.policy.toInput()), isEmpty, reason: p.name);
    }
  });

  test('presets match the requested values (idle clamped to the 1 h server minimum)', () {
    expect(PolicyPreset.sensitive.policy.accessTokenTtl, 5 * min);
    expect(PolicyPreset.sensitive.policy.refreshIdleTtl, PolicyBounds.idleMin);
    expect(PolicyPreset.sensitive.policy.refreshAbsoluteTtl, 12 * hour);
    expect(PolicyPreset.sensitive.policy.sessionMaxAge, 12 * hour);
    expect(PolicyPreset.standard.policy.accessTokenTtl, 10 * min);
    expect(PolicyPreset.staySignedIn.policy.refreshAbsoluteTtl, 400 * day);
  });

  test('access token lifetime depends on the client type', () {
    const twoHours = TokenPolicyInput(accessTokenTtl: 2 * hour);
    expect(fields(twoHours), [PolicyField.accessTokenTtl]);
    expect(fields(twoHours, ClientType.confidential), isEmpty);
    expect(fields(const TokenPolicyInput(accessTokenTtl: 25 * hour), ClientType.confidential), [
      PolicyField.accessTokenTtl,
    ]);
    expect(fields(const TokenPolicyInput(accessTokenTtl: 4 * min)), [PolicyField.accessTokenTtl]);
  });

  test('refresh windows are bounded and idle cannot exceed absolute', () {
    expect(fields(const TokenPolicyInput(refreshIdleTtl: 30 * min)), [PolicyField.refreshIdleTtl]);
    expect(fields(const TokenPolicyInput(refreshIdleTtl: 91 * day)), [PolicyField.refreshIdleTtl]);
    expect(fields(const TokenPolicyInput(refreshAbsoluteTtl: 401 * day)), [PolicyField.refreshAbsoluteTtl]);
    expect(fields(const TokenPolicyInput(refreshIdleTtl: 10 * day, refreshAbsoluteTtl: 5 * day)), [
      PolicyField.refreshIdleTtl,
    ]);
    // Only checked when both are present (a client may override one).
    expect(fields(const TokenPolicyInput(refreshIdleTtl: 10 * day)), isEmpty);
  });

  test('session max age: null means off, otherwise at least 5 minutes', () {
    expect(fields(const TokenPolicyInput(hasSessionMaxAge: true)), isEmpty);
    expect(fields(const TokenPolicyInput(sessionMaxAge: 60, hasSessionMaxAge: true)), [PolicyField.sessionMaxAge]);
    expect(fields(const TokenPolicyInput(sessionMaxAge: 5 * min, hasSessionMaxAge: true)), isEmpty);
  });

  test('messages use readable durations', () {
    final e = validatePolicy(const TokenPolicyInput(accessTokenTtl: 1));
    expect(e.single.message, 'Must be between 5 min and 1 h (public clients).');
  });

  test('formatSeconds and unit choice', () {
    expect(formatSeconds(600), '10 min');
    expect(formatSeconds(5400), '1 h 30 min');
    expect(formatSeconds(90 * day), '90 d');
    expect(DurationUnit.bestFor(12 * hour), DurationUnit.hours);
    expect(DurationUnit.bestFor(2 * day), DurationUnit.days);
    expect(DurationUnit.bestFor(90 * min), DurationUnit.minutes);
  });
}
