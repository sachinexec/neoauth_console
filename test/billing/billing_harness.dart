import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:neoauth_console/core/api/api_client.dart';
import 'package:neoauth_console/core/auth/auth_providers.dart';
import 'package:neoauth_console/core/config.dart';
import 'package:neoauth_console/features/auth/admin_me.dart';
import 'package:neoauth_console/features/billing/billing_repository.dart';

import '../helpers.dart';

/// Shapes below follow the billing service's admin views (`appView`,
/// `productView`, `grantView`, ...), so the parsing is held to the real contract.
Map<String, Object?> appJson({
  String slug = 'notes',
  String name = 'Notes',
  bool apple = true,
  bool google = false,
  bool appleSandbox = false,
}) => {
  'id': 'app-id-$slug',
  'slug': slug,
  'name': name,
  'api_audience': 'https://api.$slug.test',
  'status': 'active',
  'require_account_binding': true,
  'allow_restore_transfer': false,
  'neoauth_webhook_configured': false,
  'apple': apple
      ? {
          'configured': true,
          'bundle_id': 'com.example.$slug',
          'issuer_id': 'issuer-issuer-1',
          'key_id': 'ABC123DEFG',
          'app_apple_id': 123456789,
          'allow_sandbox': appleSandbox,
        }
      : {'configured': false},
  'google': google
      ? {
          'configured': true,
          'package_name': 'com.example.$slug',
          'service_account_email': 'play@proj.iam.gserviceaccount.com',
          'allow_sandbox': false,
        }
      : {'configured': false},
  'created_at': '2026-01-01T00:00:00.000Z',
  'updated_at': '2026-01-01T00:00:00.000Z',
};

Map<String, Object?> productJson({String slug = 'pro_monthly', List<String> entitlements = const ['pro']}) => {
  'id': 'p-$slug',
  'slug': slug,
  'name': 'Pro monthly',
  'kind': 'subscription',
  'apple_product_id': 'com.example.pro.monthly',
  'google_product_id': null,
  'active': true,
  'sort_order': 0,
  'period_days': 30,
  'metadata': <String, Object?>{},
  'entitlements': entitlements,
};

Map<String, Object?> subscriptionJson({String state = 'active'}) => {
  'id': 'sub-1',
  'user_sub': 'user-1',
  'platform': 'apple',
  'store_key': '1000000123456789',
  'product_id': 'p-1',
  'kind': 'subscription',
  'environment': 'sandbox',
  'state': state,
  'auto_renew': true,
  'period_start': '2026-01-01T00:00:00.000Z',
  'expires_at': '2030-02-01T00:00:00.000Z',
  'grace_expires_at': null,
  'revoke_reason': null,
  'revoked_at': null,
  'last_event_at': '2026-01-01T00:00:00.000Z',
  'last_synced_at': '2026-01-01T00:00:00.000Z',
  'next_check_at': null,
  'ack_pending': false,
  'erased': false,
  'version': 3,
  'created_at': '2026-01-01T00:00:00.000Z',
  'updated_at': '2026-01-01T00:00:00.000Z',
};

Map<String, Object?> grantJson({String id = 'g-1', bool revoked = false}) => {
  'id': id,
  'entitlement': 'pro',
  'expires_at': null,
  'revoked_at': revoked ? '2026-01-02T00:00:00.000Z' : null,
  'reason': 'support ticket 42',
  'granted_by': 'admin:admin-1',
  'created_at': '2026-01-01T00:00:00.000Z',
};

Map<String, Object?> eventJson({String id = 'ev-1', String source = 'notification', bool hasPayload = true}) => {
  'id': id,
  'platform': 'apple',
  'store_event_id': 'uuid-1',
  'source': source,
  'event_type': 'DID_RENEW',
  'subtype': null,
  'store_key': '1000000123456789',
  'event_time': '2026-01-01T00:00:00.000Z',
  'received_at': '2026-01-01T00:00:01.000Z',
  'status': 'failed',
  'outcome': null,
  'attempts': 2,
  'error': 'boom',
  'has_payload': hasPayload,
};

/// A scripted billing service. [role] answers `/me`; mutations are recorded in
/// [calls] as `METHOD path` with their bodies in [bodies].
class FakeBilling {
  FakeBilling({this.role = 'owner'}) {
    adapter.handler = _handle;
  }

  String role;
  final adapter = FakeAdapter();
  final bodies = <String, Object?>{};

  /// Every request, `METHOD /path`.
  List<String> get calls => [for (final r in adapter.requests) '${r.method} ${r.path}'];

  List<Map<String, Object?>> apps = [appJson()];
  List<Map<String, Object?>> products = [productJson()];
  List<Map<String, Object?>> entitlements = [
    {'id': 'e-1', 'key': 'pro', 'name': 'Pro'},
    {'id': 'e-2', 'key': 'ads_free', 'name': 'Ads free'},
  ];
  Map<String, Object?> customer = {
    'sub': 'user-1',
    'entitlements': [
      {
        'key': 'pro',
        'active': true,
        'expires_at': null,
        'product': null,
        'source': 'grant',
        'state': 'granted',
        'will_renew': null,
      },
    ],
    'subscriptions': [subscriptionJson()],
    'grants': [grantJson()],
  };
  List<Map<String, Object?>> events = [eventJson()];
  List<Map<String, Object?>> apiKeys = [];
  List<Map<String, Object?>> webhooks = [];
  List<Map<String, Object?>> audit = [];

  /// Make the next request that matches fail with this reply (once).
  final failures = <String, FakeReply>{};

  FakeReply _handle(RequestOptions o) {
    final key = '${o.method} ${o.path}';
    bodies[key] = o.data;
    final fail = failures.remove(key);
    if (fail != null) return fail;
    switch (key) {
      case 'GET /me':
        return FakeReply(200, {
          'sub': 'admin-1',
          'role': role,
          'kind': 'user',
          'auth_time': '2026-01-01T00:00:00.000Z',
        });
      case 'GET /apps':
        return FakeReply(200, {'apps': apps});
      case 'POST /apps':
        return FakeReply(
          201,
          appJson(slug: (o.data as Map)['slug'] as String, name: (o.data as Map)['name'] as String),
        );
      case 'GET /apps/notes':
        return FakeReply(200, apps.first);
      case 'PATCH /apps/notes':
      case 'PUT /apps/notes/apple':
      case 'PUT /apps/notes/google':
      case 'PUT /apps/notes/neoauth-webhook-secret':
        return FakeReply(200, apps.first);
      case 'DELETE /apps/notes/apple':
      case 'DELETE /apps/notes/google':
      case 'DELETE /apps/notes/api-keys/k-1':
      case 'DELETE /apps/notes/webhooks/w-1':
        return const FakeReply(204);
      case 'GET /apps/notes/products':
        return FakeReply(200, {'products': products});
      case 'POST /apps/notes/products':
      case 'PATCH /apps/notes/products/pro_monthly':
      case 'PUT /apps/notes/products/pro_monthly/entitlements':
        return FakeReply(200, products.first);
      case 'GET /apps/notes/entitlements':
        return FakeReply(200, {'entitlements': entitlements});
      case 'POST /apps/notes/entitlements':
        return FakeReply(201, {'id': 'e-3', 'key': (o.data as Map)['key'], 'name': (o.data as Map)['name']});
      case 'GET /apps/notes/users/user-1':
        return FakeReply(200, customer);
      case 'POST /apps/notes/users/user-1/grants':
        return FakeReply(201, grantJson(id: 'g-2'));
      case 'DELETE /apps/notes/grants/g-1':
        return FakeReply(200, grantJson(revoked: true));
      case 'GET /apps/notes/events':
        return FakeReply(200, {'events': events});
      case 'GET /apps/notes/subscriptions':
        return FakeReply(200, {
          'subscriptions': [subscriptionJson()],
        });
      case 'POST /apps/notes/events/ev-1/replay':
        return const FakeReply(200, {'result': 'processed'});
      case 'GET /apps/notes/api-keys':
        return FakeReply(200, {'api_keys': apiKeys});
      case 'POST /apps/notes/api-keys':
        return const FakeReply(201, {
          'id': 'k-1',
          'name': 'api-server',
          'prefix': 'nbk_0123456789ab',
          'scopes': ['entitlements:read'],
          'status': 'active',
          'expires_at': null,
          'last_used_at': null,
          'created_by': 'admin:admin-1',
          'created_at': '2026-01-01T00:00:00.000Z',
          'key': 'nbk_0123456789ab_THE-ONLY-TIME-THIS-IS-SHOWN',
        });
      case 'GET /apps/notes/webhooks':
        return FakeReply(200, {'webhooks': webhooks});
      case 'POST /apps/notes/webhooks':
        return const FakeReply(201, {
          'id': 'w-1',
          'url': 'https://api.example.com/hooks',
          'events': ['entitlement.granted'],
          'status': 'active',
          'created_at': '2026-01-01T00:00:00.000Z',
          'secret': 'whsec_THE-ONLY-TIME-THIS-IS-SHOWN',
        });
      case 'GET /audit':
        return FakeReply(200, {'events': audit});
    }
    return FakeReply(404, {'statusCode': 404, 'message': 'no route $key'});
  }

  Dio get dio => Dio(BaseOptions(baseUrl: 'https://billing.test/admin/v1'))..httpClientAdapter = adapter;
}

const stepUpReply = FakeReply(403, {
  'statusCode': 403,
  'error': 'step_up_required',
  'message': 'Sign in again to confirm this action.',
});

AppConfig testConfig({String billingUrl = 'https://billing.test'}) =>
    AppConfig(issuer: 'https://auth.test', clientId: 'console', flavor: 'dev', billingUrl: billingUrl);

/// Overrides that put the screens in front of [server] as a user with [server.role].
List<Override> billingOverrides(FakeBilling server, {AppConfig? config, StepUpHandler? onStepUp}) => [
  appConfigProvider.overrideWithValue(config ?? testConfig()),
  currentUserIdProvider.overrideWithValue('admin-1'),
  billingApiClientProvider.overrideWithValue(ApiClient(server.dio, onStepUp: onStepUp)),
];

Widget host(List<Override> overrides, Widget child) => ProviderScope(
  retry: (_, _) => null,
  overrides: overrides,
  child: MaterialApp(home: child),
);

/// Like [host], with a router so screens can navigate; [child] is at `/start`.
Widget hostRouter(List<Override> overrides, Widget child) => ProviderScope(
  retry: (_, _) => null,
  overrides: overrides,
  child: MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (_, _) => Scaffold(body: child),
        ),
        GoRoute(
          path: '/billing/:slug',
          builder: (_, s) => Scaffold(body: Text('detail ${s.pathParameters['slug']}')),
        ),
      ],
    ),
  ),
);

/// Roles as the console shows them.
AdminRole roleOf(String name) => AdminRole.parse(name);
