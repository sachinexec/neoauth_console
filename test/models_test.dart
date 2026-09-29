import 'package:neoauth_console/core/json.dart';
import 'package:neoauth_console/features/admins/admins.dart';
import 'package:neoauth_console/features/apps/models/app_models.dart';
import 'package:neoauth_console/features/audit/audit.dart';
import 'package:neoauth_console/features/auth/admin_me.dart';
import 'package:neoauth_console/features/overview/overview.dart';
import 'package:neoauth_console/features/users/users.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Parses responses recorded from the local backend, so a change in the
/// server's shapes shows up here.
void main() {
  group('recorded responses', () {
    test('GET /me', () {
      final me = AdminMe.fromJson(fixture('me'));
      expect(me.role, AdminRole.owner);
      expect(me.userId, isNotEmpty);
      expect(me.phone, startsWith('+'));
      expect(me.authTime, isNotNull);
    });

    test('GET /overview', () {
      final o = Overview.fromJson(fixture('overview'));
      expect(o.signups, hasLength(30));
      expect(o.signups.first.day.isBefore(o.signups.last.day), isTrue);
      expect(o.apps, isNotEmpty);
      expect(o.totals.apps, greaterThan(0));
    });

    test('GET /providers', () {
      final p = ProviderSupport.fromJson(fixture('providers'));
      expect(p.byMethod.keys, containsAll(LoginMethod.values));
      expect(p.of(LoginMethod.phone).native, isTrue);
    });

    test('GET /apps', () {
      final apps = objList(fixture('apps'), 'apps', AppModel.fromJson);
      expect(apps, isNotEmpty);
      final console = apps.firstWhere((a) => a.isConsole);
      expect(console.slug, 'neoauth-console');
      expect(console.clients.first.nativeLogin, isTrue);
      for (final a in apps) {
        expect(a.loginMethods, isNotEmpty);
        expect(a.webhooks, isNull, reason: 'the list omits webhooks');
      }
    });

    test('GET /apps/:slug includes webhooks and effective client settings', () {
      final app = AppModel.fromJson(fixture('app_detail'));
      expect(app.webhooks, isNotNull);
      final c = app.clients.first;
      expect(c.effectiveTokenPolicy.accessTokenTtl, greaterThanOrEqualTo(PolicyBounds.accessMin));
      expect(c.effectiveLoginMethods.web, isNotEmpty);
      expect(c.attestation.mode, AttestationMode.off);
    });

    test('GET /clients/:id', () {
      final c = ClientModel.fromJson(fixture('client'));
      expect(c.clientId, contains('.web.'));
      expect(c.applicationType, ApplicationType.web);
      expect(c.clientType, ClientType.public);
      expect(c.loginMethods, isNull, reason: 'null inherits the app');
      expect(c.tokenPolicyOverride.isEmpty, isTrue);
      expect(c.clientSecret, isNull);
    });

    test('GET /users and /users/:id', () {
      final users = objList(fixture('users'), 'users', UserSummary.fromJson);
      expect(users, isNotEmpty);
      final d = UserDetail.fromJson(fixture('user_detail'));
      expect(d.identities.first.provider, 'phone');
      expect(d.sessions, isNotEmpty);
      expect(d.sessions.first.grantId, isNotEmpty);
      expect(d.adminRole, AdminRole.owner);
      expect(d.apps.first.slug, 'neoauth-console');
    });

    test('GET /audit: bigint ids arrive as strings', () {
      final events = objList(fixture('audit'), 'events', AuditEvent.fromJson);
      expect(events, isNotEmpty);
      expect(int.tryParse(events.first.id), isNotNull);
      expect(events.first.event, contains('.'));
    });

    test('POST /apps/:slug/clients (confidential) returns the secret once', () {
      final c = ClientModel.fromJson(fixture('client_created'));
      expect(c.clientType, ClientType.confidential);
      expect(c.clientSecret, isNotEmpty);
      expect(c.backchannelLogoutUri, 'https://smoke.local/bcl');
    });

    test('PATCH /clients/:id with custom methods and attestation', () {
      final c = ClientModel.fromJson(fixture('client_patched'));
      expect(c.loginMethods, [LoginMethod.phone]);
      expect(c.effectiveLoginMethods.native, [LoginMethod.phone]);
      expect(c.attestation.mode, AttestationMode.report);
      expect(c.attestation.ios!.allowDevelopment, isTrue);
      expect(c.attestation.android, isNull);
    });

    test('POST /apps/:slug/webhooks returns the signing secret once', () {
      final w = WebhookEndpoint.fromJson(fixture('webhook_created'));
      expect(w.secret, startsWith('whsec_'));
      expect(w.events, ['user.deleted', 'session.revoked']);
    });

    test('GET /admins', () {
      final admins = objList(fixture('admins'), 'admins', AdminEntry.fromJson);
      expect(admins.single.role, AdminRole.owner);
    });
  });

  group('TokenPolicyInput', () {
    test('keeps unset, null and set session_max_age apart', () {
      expect(TokenPolicyInput.fromJson({}).toJson(), isEmpty);
      expect(TokenPolicyInput.fromJson({'session_max_age': null}).toJson(), {'session_max_age': null});
      expect(TokenPolicyInput.fromJson({'session_max_age': 3600}).toJson(), {'session_max_age': 3600});
    });

    test('round-trips and resolves over a base', () {
      final input = TokenPolicyInput.fromJson({'access_token_ttl': 1800, 'refresh_token_mode': 'none'});
      expect(input.toJson(), {'access_token_ttl': 1800, 'refresh_token_mode': 'none'});
      final resolved = input.resolve(TokenPolicy.defaults);
      expect(resolved.accessTokenTtl, 1800);
      expect(resolved.refreshTokenMode, RefreshTokenMode.none);
      expect(resolved.refreshIdleTtl, TokenPolicy.defaults.refreshIdleTtl);
    });

    test('value equality', () {
      expect(
        TokenPolicyInput.fromJson({'access_token_ttl': 600}),
        TokenPolicyInput.fromJson({'access_token_ttl': 600}),
      );
      expect(PolicyPreset.standard.policy, TokenPolicy.defaults);
    });
  });

  group('other models', () {
    test('login methods parse in canonical order and drop unknowns', () {
      expect(LoginMethod.parseList(['passkey', 'phone', 'fax']), [LoginMethod.phone, LoginMethod.passkey]);
      expect(LoginMethod.toWire({LoginMethod.email, LoginMethod.google}), ['google', 'email']);
    });

    test('attestation config round-trips and validates', () {
      const good = AttestationConfig(
        mode: AttestationMode.enforce,
        android: AndroidAttestation(
          packageName: 'in.neodiverse.app',
          certificateSha256: [
            'AB:CD:EF:01:23:45:67:89:AB:CD:EF:01:23:45:67:89:AB:CD:EF:01:23:45:67:89:AB:CD:EF:01:23:45:67:89',
          ],
        ),
        ios: IosAttestation(teamId: 'ABCDE12345', bundleId: 'in.neodiverse.app'),
      );
      expect(good.validate(), isEmpty);
      final parsed = AttestationConfig.fromJson(good.toJson());
      expect(parsed.mode, AttestationMode.enforce);
      expect(parsed.android!.certificateSha256, hasLength(1));
      expect(parsed.ios!.teamId, 'ABCDE12345');

      const bad = AttestationConfig(
        android: AndroidAttestation(packageName: '1bad', certificateSha256: ['nope']),
        ios: IosAttestation(teamId: 'short', bundleId: ''),
      );
      expect(bad.validate(), hasLength(4));
    });

    test('a confidential client response carries its secret once', () {
      final json = {...fixture('client'), 'client_type': 'confidential', 'client_secret': 's3cret'};
      final c = ClientModel.fromJson(json);
      expect(c.clientType, ClientType.confidential);
      expect(c.clientSecret, 's3cret');
    });

    test('webhook endpoints and ping results', () {
      final w = WebhookEndpoint.fromJson({
        'id': '01a0d9',
        'url': 'https://x.test/hook',
        'events': ['user.deleted'],
        'status': 'active',
        'created_at': '2026-09-25T15:14:33.300Z',
        'secret': 'whsec_x',
      });
      expect(w.secret, 'whsec_x');
      expect(PingResult.fromJson({'status': 204}).ok, isTrue);
      expect(PingResult.fromJson({'status': null, 'error': 'timeout'}).ok, isFalse);
    });

    test('a missing required field is a FormatException naming it', () {
      expect(
        () => AppModel.fromJson({'slug': 'x'}),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('"id"'))),
      );
    });
  });
}
