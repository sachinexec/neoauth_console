import 'package:flutter_test/flutter_test.dart';
import 'package:neoauth_console/core/api/api_client.dart';
import 'package:neoauth_console/core/api/api_exception.dart';
import 'package:neoauth_console/features/auth/admin_me.dart';
import 'package:neoauth_console/features/billing/billing_models.dart';
import 'package:neoauth_console/features/billing/billing_repository.dart';

import '../helpers.dart';
import 'billing_harness.dart';

void main() {
  late FakeBilling server;
  late BillingRepository repo;
  var stepUps = 0;

  setUp(() {
    server = FakeBilling();
    stepUps = 0;
    repo = BillingRepository(
      ApiClient(
        server.dio,
        onStepUp: () async {
          stepUps++;
          return true;
        },
      ),
    );
  });

  group('models', () {
    test('an app: identifiers only, credentials as configured flags', () {
      final app = BillingApp.fromJson(appJson(google: true, appleSandbox: true));
      expect(app.slug, 'notes');
      expect(app.apple.configured, isTrue);
      expect(app.apple.keyId, 'ABC123DEFG');
      expect(app.apple.appAppleId, 123456789);
      expect(app.apple.allowSandbox, isTrue);
      expect(app.google.serviceAccountEmail, 'play@proj.iam.gserviceaccount.com');
      expect(app.requireAccountBinding, isTrue);
      expect(app.allowRestoreTransfer, isFalse);
    });

    test('an app without credentials', () {
      final app = BillingApp.fromJson(appJson(apple: false));
      expect(app.apple.configured, isFalse);
      expect(app.apple.bundleId, isNull);
      expect(app.google.configured, isFalse);
    });

    test('a product', () {
      final p = BillingProduct.fromJson(productJson());
      expect(p.kind, ProductKind.subscription);
      expect(p.entitlements, ['pro']);
      expect(p.periodDays, 30);
      expect(p.googleProductId, isNull);
    });

    test('grants are active until revoked or ended', () {
      final now = DateTime.now();
      expect(BillingGrant.fromJson(grantJson()).isActive(now), isTrue);
      expect(BillingGrant.fromJson(grantJson(revoked: true)).isActive(now), isFalse);
      final ended = BillingGrant.fromJson({
        ...grantJson(),
        'expires_at': now.subtract(const Duration(days: 1)).toUtc().toIso8601String(),
      });
      expect(ended.isActive(now), isFalse);
    });

    test('a customer', () {
      final c = BillingCustomer.fromJson(FakeBilling().customer);
      expect(c.entitlements.single.key, 'pro');
      expect(c.subscriptions.single.isSandbox, isTrue);
      expect(c.grants.single.reason, 'support ticket 42');
    });

    test('only stored notifications can be replayed', () {
      expect(BillingStoreEvent.fromJson(eventJson()).canReplay, isTrue);
      expect(BillingStoreEvent.fromJson(eventJson(source: 'client')).canReplay, isFalse);
      expect(BillingStoreEvent.fromJson(eventJson(source: 'reconcile')).canReplay, isFalse);
    });

    test('a created API key carries its secret, a listed one does not', () {
      final listed = BillingApiKey.fromJson({
        'id': 'k',
        'name': 'n',
        'prefix': 'nbk_abc',
        'scopes': ['entitlements:read'],
        'status': 'active',
      });
      expect(listed.prefix, 'nbk_abc');
      expect(() => CreatedApiKey.fromJson({'id': 'k', 'name': 'n'}), throwsFormatException);
    });

    test('a malformed row names the field', () {
      expect(
        () => BillingApp.fromJson({'name': 'x'}),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('slug'))),
      );
    });

    test('the role comes from the server, unknown means viewer', () {
      expect(BillingMe.fromJson({'role': 'owner', 'sub': 'u'}).role, AdminRole.owner);
      expect(BillingMe.fromJson({'role': 'root'}).role, AdminRole.viewer);
    });
  });

  group('requests', () {
    test('apps and one app', () async {
      expect((await repo.apps()).single.slug, 'notes');
      expect((await repo.app('notes')).name, 'Notes');
      expect(server.calls, ['GET /apps', 'GET /apps/notes']);
    });

    test('slugs are escaped in paths', () async {
      server.failures['GET /apps/a%20b/%2F'] = const FakeReply(404, {'message': 'x'});
      await expectLater(repo.customer('a b', '/'), throwsA(isA<ApiException>()));
      expect(server.calls.single, contains('/apps/a%20b/users/%2F'));
    });

    test('create app', () async {
      await repo.createApp(
        slug: 'notes2',
        name: 'Notes 2',
        apiAudience: 'https://api.notes2.test',
        requireAccountBinding: true,
        allowRestoreTransfer: false,
      );
      expect(server.bodies['POST /apps'], {
        'slug': 'notes2',
        'name': 'Notes 2',
        'api_audience': 'https://api.notes2.test',
        'require_account_binding': true,
        'allow_restore_transfer': false,
      });
    });

    test('update sends only what changed', () async {
      await repo.updateApp('notes', status: 'disabled');
      expect(server.bodies['PATCH /apps/notes'], {'status': 'disabled'});
    });

    test('credentials go to the service and come back without secrets', () async {
      final app = await repo.setApple(
        'notes',
        bundleId: 'com.example.notes',
        issuerId: 'issuer-issuer-1',
        keyId: 'ABC123DEFG',
        privateKey: '-----BEGIN PRIVATE KEY-----\nSECRET\n-----END PRIVATE KEY-----',
        allowSandbox: false,
      );
      final sent = server.bodies['PUT /apps/notes/apple']! as Map<Object?, Object?>;
      expect(sent['private_key'], contains('SECRET'));
      expect(sent.containsKey('app_apple_id'), isFalse);
      expect(app.apple.keyId, 'ABC123DEFG');

      await repo.setGoogle(
        'notes',
        packageName: 'com.example.notes',
        serviceAccountJson: '{"private_key":"X"}',
        allowSandbox: true,
      );
      expect(server.bodies['PUT /apps/notes/google'], {
        'package_name': 'com.example.notes',
        'service_account_json': '{"private_key":"X"}',
        'allow_sandbox': true,
      });

      await repo.setNeoauthWebhookSecret('notes', 'a-long-enough-secret');
      expect(server.bodies['PUT /apps/notes/neoauth-webhook-secret'], {'secret': 'a-long-enough-secret'});

      await repo.removeApple('notes');
      await repo.removeGoogle('notes');
      expect(server.calls, containsAll(['DELETE /apps/notes/apple', 'DELETE /apps/notes/google']));
    });

    test('products and the product-to-entitlement mapping', () async {
      await repo.createProduct(
        'notes',
        productSlug: 'pro_yearly',
        name: 'Pro yearly',
        kind: ProductKind.subscription,
        appleProductId: 'a.y',
        periodDays: 365,
        entitlements: ['pro'],
      );
      expect(server.bodies['POST /apps/notes/products'], {
        'slug': 'pro_yearly',
        'name': 'Pro yearly',
        'kind': 'subscription',
        'apple_product_id': 'a.y',
        'period_days': 365,
        'entitlements': ['pro'],
      });
      await repo.setProductEntitlements('notes', 'pro_monthly', ['pro', 'ads_free']);
      expect(server.bodies['PUT /apps/notes/products/pro_monthly/entitlements'], {
        'entitlements': ['pro', 'ads_free'],
      });
      await repo.updateProduct('notes', 'pro_monthly', active: false, clearAppleId: true);
      expect(server.bodies['PATCH /apps/notes/products/pro_monthly'], {'active': false, 'apple_product_id': null});
      expect((await repo.entitlements('notes')).map((e) => e.key), ['pro', 'ads_free']);
      await repo.createEntitlement('notes', key: 'vip', name: 'VIP');
      expect(server.bodies['POST /apps/notes/entitlements'], {'key': 'vip', 'name': 'VIP'});
    });

    test('a grant sends a UTC expiry and the reason; a revoke carries its reason in a DELETE body', () async {
      final until = DateTime.utc(2030, 5, 6, 7);
      await repo.grant('notes', 'user-1', entitlement: 'pro', reason: 'support ticket 42', expiresAt: until);
      expect(server.bodies['POST /apps/notes/users/user-1/grants'], {
        'entitlement': 'pro',
        'reason': 'support ticket 42',
        'expires_at': '2030-05-06T07:00:00.000Z',
      });
      final g = await repo.revokeGrant('notes', 'g-1', reason: 'duplicate');
      expect(server.bodies['DELETE /apps/notes/grants/g-1'], {'reason': 'duplicate'});
      expect(g.revokedAt, isNotNull);
    });

    test('a grant without an expiry omits the field', () async {
      await repo.grant('notes', 'user-1', entitlement: 'pro', reason: 'beta tester');
      expect(
        (server.bodies['POST /apps/notes/users/user-1/grants']! as Map<Object?, Object?>).containsKey('expires_at'),
        isFalse,
      );
    });

    test('step-up: confirmed once, the grant is retried and succeeds', () async {
      server.failures['POST /apps/notes/users/user-1/grants'] = stepUpReply;
      final g = await repo.grant('notes', 'user-1', entitlement: 'pro', reason: 'support ticket 42');
      expect(g.id, 'g-2');
      expect(stepUps, 1);
      expect(server.calls.where((c) => c == 'POST /apps/notes/users/user-1/grants'), hasLength(2));
    });

    test('step-up cancelled: the grant is not sent again', () async {
      repo = BillingRepository(ApiClient(server.dio, onStepUp: () async => false));
      server.failures['POST /apps/notes/users/user-1/grants'] = stepUpReply;
      await expectLater(
        repo.grant('notes', 'user-1', entitlement: 'pro', reason: 'support ticket 42'),
        throwsA(isA<ApiException>().having((e) => e.isStepUpCancelled, 'cancelled', isTrue)),
      );
      expect(server.calls.where((c) => c.startsWith('POST')), hasLength(1));
    });

    test('a 403 for the role is not a step-up', () async {
      server.failures['GET /apps/notes/users/user-1'] = const FakeReply(403, {
        'statusCode': 403,
        'error': 'Forbidden',
        'message': 'requires the admin role',
      });
      await expectLater(
        repo.customer('notes', 'user-1'),
        throwsA(isA<ApiException>().having((e) => e.isForbidden, 'forbidden', isTrue)),
      );
      expect(stepUps, 0);
    });

    test('replay returns the outcome', () async {
      expect(await repo.replayEvent('notes', 'ev-1'), 'processed');
    });

    test('lists pass their filters and cursors', () async {
      await repo.events('notes', status: 'failed', before: '2026-01-01T00:00:01.000Z');
      await repo.subscriptions('notes', state: 'grace', limit: 20);
      await repo.audit(before: '2026-01-01T00:00:00.000Z');
      final q = [for (final r in server.adapter.requests) r.queryParameters];
      expect(q[0], {'status': 'failed', 'before': '2026-01-01T00:00:01.000Z', 'limit': 50});
      expect(q[1], {'state': 'grace', 'limit': 20});
      expect(q[2], {'before': '2026-01-01T00:00:00.000Z', 'limit': 50});
    });

    test('API keys: the secret is in the creation result only', () async {
      final created = await repo.createApiKey('notes', name: 'api-server', expiresInDays: 90);
      expect(created.secret, startsWith('nbk_'));
      expect(server.bodies['POST /apps/notes/api-keys'], {
        'name': 'api-server',
        'scopes': ['entitlements:read'],
        'expires_in_days': 90,
      });
      expect(await repo.apiKeys('notes'), isEmpty);
      await repo.revokeApiKey('notes', 'k-1');
    });

    test('webhooks: the signing secret is in the creation result only', () async {
      final created = await repo.createWebhook(
        'notes',
        url: 'https://api.example.com/hooks',
        events: ['entitlement.granted'],
      );
      expect(created.secret, startsWith('whsec_'));
      expect(await repo.webhooks('notes'), isEmpty);
      await repo.deleteWebhook('notes', 'w-1');
    });
  });
}
