import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/json.dart';
import '../../shared/paged.dart';
import '../auth/admin_me.dart';
import 'billing_models.dart';

/// A user id as the billing service accepts it (a NeoAuth `sub`).
final billingSubPattern = RegExp(r'^[A-Za-z0-9._:-]{1,128}$');

/// [billingSubPattern], minus `.` and `..`, which would be collapsed out of the request path.
bool isBillingSub(String s) => billingSubPattern.hasMatch(s) && s != '.' && s != '..';

/// Entitlement keys and product slugs.
final billingKeyPattern = RegExp(r'^[a-z0-9][a-z0-9_.-]{0,63}$');
final billingSlugPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');
final billingAppSlugPattern = RegExp(r'^[a-z0-9][a-z0-9-]{1,39}$');

String _enc(String segment) => Uri.encodeComponent(segment);

/// Typed access to the billing admin API (`<BILLING_URL>/admin/v1`).
///
/// Secrets (store credentials, webhook secrets) only ever travel *to* the
/// service from here: the methods that take them return the app without them,
/// and nothing in this class keeps them.
class BillingRepository {
  BillingRepository(this._api);
  final ApiClient _api;

  Future<BillingMe> me() async => BillingMe.fromJson(await _api.get('/me'));

  // ── Apps and credentials ──────────────────────────────────────────────────

  Future<List<BillingApp>> apps() async => objList(await _api.get('/apps'), 'apps', BillingApp.fromJson);

  Future<BillingApp> app(String slug) async => BillingApp.fromJson(await _api.get('/apps/${_enc(slug)}'));

  Future<BillingApp> createApp({
    required String slug,
    required String name,
    required String apiAudience,
    required bool requireAccountBinding,
    required bool allowRestoreTransfer,
  }) async => BillingApp.fromJson(
    await _api.post(
      '/apps',
      body: {
        'slug': slug,
        'name': name,
        'api_audience': apiAudience,
        'require_account_binding': requireAccountBinding,
        'allow_restore_transfer': allowRestoreTransfer,
      },
    ),
  );

  /// Only the given fields change.
  Future<BillingApp> updateApp(
    String slug, {
    String? name,
    String? apiAudience,
    String? status,
    bool? requireAccountBinding,
    bool? allowRestoreTransfer,
  }) async => BillingApp.fromJson(
    await _api.patch(
      '/apps/${_enc(slug)}',
      body: {
        'name': ?name,
        'api_audience': ?apiAudience,
        'status': ?status,
        'require_account_binding': ?requireAccountBinding,
        'allow_restore_transfer': ?allowRestoreTransfer,
      },
    ),
  );

  /// Owner only; step-up. [privateKey] is the `.p8` text.
  Future<BillingApp> setApple(
    String slug, {
    required String bundleId,
    required String issuerId,
    required String keyId,
    required String privateKey,
    int? appAppleId,
    required bool allowSandbox,
  }) async => BillingApp.fromJson(
    await _api.put(
      '/apps/${_enc(slug)}/apple',
      body: {
        'bundle_id': bundleId,
        'issuer_id': issuerId,
        'key_id': keyId,
        'private_key': privateKey,
        'app_apple_id': ?appAppleId,
        'allow_sandbox': allowSandbox,
      },
    ),
  );

  Future<void> removeApple(String slug) => _api.deleteVoid('/apps/${_enc(slug)}/apple');

  /// Owner only; step-up. [serviceAccountJson] is the key file's text.
  Future<BillingApp> setGoogle(
    String slug, {
    required String packageName,
    required String serviceAccountJson,
    required bool allowSandbox,
  }) async => BillingApp.fromJson(
    await _api.put(
      '/apps/${_enc(slug)}/google',
      body: {'package_name': packageName, 'service_account_json': serviceAccountJson, 'allow_sandbox': allowSandbox},
    ),
  );

  Future<void> removeGoogle(String slug) => _api.deleteVoid('/apps/${_enc(slug)}/google');

  /// The secret NeoAuth signs `user.deleted` webhooks with. Owner only; step-up.
  Future<BillingApp> setNeoauthWebhookSecret(String slug, String secret) async =>
      BillingApp.fromJson(await _api.put('/apps/${_enc(slug)}/neoauth-webhook-secret', body: {'secret': secret}));

  // ── Catalog ───────────────────────────────────────────────────────────────

  Future<List<BillingProduct>> products(String slug) async =>
      objList(await _api.get('/apps/${_enc(slug)}/products'), 'products', BillingProduct.fromJson);

  Future<BillingProduct> createProduct(
    String slug, {
    required String productSlug,
    required String name,
    required ProductKind kind,
    String? appleProductId,
    String? googleProductId,
    int? periodDays,
    int? sortOrder,
    List<String> entitlements = const [],
  }) async => BillingProduct.fromJson(
    await _api.post(
      '/apps/${_enc(slug)}/products',
      body: {
        'slug': productSlug,
        'name': name,
        'kind': kind.name,
        'apple_product_id': ?appleProductId,
        'google_product_id': ?googleProductId,
        'period_days': ?periodDays,
        'sort_order': ?sortOrder,
        'entitlements': entitlements,
      },
    ),
  );

  /// Null store ids are sent as null to clear them; omit by passing [clearAppleId] false.
  Future<BillingProduct> updateProduct(
    String slug,
    String productSlug, {
    String? name,
    bool? active,
    int? sortOrder,
    int? periodDays,
    String? appleProductId,
    String? googleProductId,
    bool clearAppleId = false,
    bool clearGoogleId = false,
  }) async => BillingProduct.fromJson(
    await _api.patch(
      '/apps/${_enc(slug)}/products/${_enc(productSlug)}',
      body: {
        'name': ?name,
        'active': ?active,
        'sort_order': ?sortOrder,
        'period_days': ?periodDays,
        if (clearAppleId) 'apple_product_id': null else 'apple_product_id': ?appleProductId,
        if (clearGoogleId) 'google_product_id': null else 'google_product_id': ?googleProductId,
      },
    ),
  );

  /// Replaces the entitlements a product unlocks.
  Future<BillingProduct> setProductEntitlements(String slug, String productSlug, List<String> keys) async =>
      BillingProduct.fromJson(
        await _api.put('/apps/${_enc(slug)}/products/${_enc(productSlug)}/entitlements', body: {'entitlements': keys}),
      );

  Future<List<BillingEntitlement>> entitlements(String slug) async =>
      objList(await _api.get('/apps/${_enc(slug)}/entitlements'), 'entitlements', BillingEntitlement.fromJson);

  Future<BillingEntitlement> createEntitlement(String slug, {required String key, required String name}) async =>
      BillingEntitlement.fromJson(
        await _api.post('/apps/${_enc(slug)}/entitlements', body: {'key': key, 'name': name}),
      );

  // ── Customers, grants, events ─────────────────────────────────────────────

  /// Admin role. The server records every lookup in the audit log.
  Future<BillingCustomer> customer(String slug, String sub) async =>
      BillingCustomer.fromJson(await _api.get('/apps/${_enc(slug)}/users/${_enc(sub)}'));

  /// Admin; step-up. The reason is always recorded in the audit log.
  Future<BillingGrant> grant(
    String slug,
    String sub, {
    required String entitlement,
    required String reason,
    DateTime? expiresAt,
  }) async => BillingGrant.fromJson(
    await _api.post(
      '/apps/${_enc(slug)}/users/${_enc(sub)}/grants',
      body: {'entitlement': entitlement, 'reason': reason, 'expires_at': ?expiresAt?.toUtc().toIso8601String()},
    ),
  );

  /// Admin; step-up.
  Future<BillingGrant> revokeGrant(String slug, String grantId, {required String reason}) async =>
      BillingGrant.fromJson(await _api.delete('/apps/${_enc(slug)}/grants/${_enc(grantId)}', body: {'reason': reason}));

  Future<List<BillingSubscription>> subscriptions(String slug, {String? state, String? before, int limit = 50}) async =>
      objList(
        await _api.get('/apps/${_enc(slug)}/subscriptions', query: {'state': state, 'before': before, 'limit': limit}),
        'subscriptions',
        BillingSubscription.fromJson,
      );

  Future<List<BillingStoreEvent>> events(
    String slug, {
    String? status,
    String? storeKey,
    String? before,
    int limit = 50,
  }) async => objList(
    await _api.get(
      '/apps/${_enc(slug)}/events',
      query: {'status': status, 'store_key': storeKey, 'before': before, 'limit': limit},
    ),
    'events',
    BillingStoreEvent.fromJson,
  );

  /// Re-runs a stored store notification. Admin; step-up. Returns the
  /// server's outcome as text.
  Future<String> replayEvent(String slug, String eventId) async {
    final body = await _api.post('/apps/${_enc(slug)}/events/${_enc(eventId)}/replay');
    return body['result']?.toString() ?? 'done';
  }

  // ── API keys and webhooks (owner) ─────────────────────────────────────────

  Future<List<BillingApiKey>> apiKeys(String slug) async =>
      objList(await _api.get('/apps/${_enc(slug)}/api-keys'), 'api_keys', BillingApiKey.fromJson);

  /// Step-up. The key is in the result once and cannot be fetched again.
  Future<CreatedApiKey> createApiKey(String slug, {required String name, int? expiresInDays}) async =>
      CreatedApiKey.fromJson(
        await _api.post(
          '/apps/${_enc(slug)}/api-keys',
          body: {
            'name': name,
            'scopes': const ['entitlements:read'],
            'expires_in_days': ?expiresInDays,
          },
        ),
      );

  Future<void> revokeApiKey(String slug, String id) => _api.deleteVoid('/apps/${_enc(slug)}/api-keys/${_enc(id)}');

  Future<List<BillingWebhook>> webhooks(String slug) async =>
      objList(await _api.get('/apps/${_enc(slug)}/webhooks'), 'webhooks', BillingWebhook.fromJson);

  /// Step-up. The signing secret is in the result once.
  Future<CreatedWebhook> createWebhook(String slug, {required String url, required List<String> events}) async =>
      CreatedWebhook.fromJson(await _api.post('/apps/${_enc(slug)}/webhooks', body: {'url': url, 'events': events}));

  Future<void> deleteWebhook(String slug, String id) => _api.deleteVoid('/apps/${_enc(slug)}/webhooks/${_enc(id)}');

  Future<WebhookPing> pingWebhook(String slug, String id) async =>
      WebhookPing.fromJson(await _api.post('/apps/${_enc(slug)}/webhooks/${_enc(id)}/ping'));

  // ── Audit ─────────────────────────────────────────────────────────────────

  /// Admin role. [before] is the `created_at` of the last row seen.
  Future<List<BillingAuditEvent>> audit({String? before, int limit = 50}) async => objList(
    await _api.get('/audit', query: {'before': before, 'limit': limit}),
    'events',
    BillingAuditEvent.fromJson,
  );
}

// ── Providers ───────────────────────────────────────────────────────────────

/// Dio for the billing admin API. Sends the console's own NeoAuth access token,
/// or one for the configured billing resource. Rebuilt (and every provider
/// below with it) when the account changes, so nothing of one admin's session
/// is shown to the next.
final billingDioProvider = Provider<Dio>((ref) {
  ref.watch(currentUserIdProvider);
  final config = ref.watch(appConfigProvider);
  final base = config.billingAdminBaseUrl;
  if (base == null) throw StateError('Billing is not configured');
  final auth = ref.watch(neoAuthClientProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
  dio.interceptors.add(
    auth.interceptor(resource: config.billingResource.isEmpty ? null : config.billingResource, dio: dio),
  );
  return dio;
});

final billingApiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(billingDioProvider), onStepUp: ref.watch(stepUpHandlerProvider)),
);

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(ref.watch(billingApiClientProvider)),
);

/// The caller's billing role. A 403 here means no billing role at all.
final billingMeProvider = FutureProvider<BillingMe>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) throw StateError('Not signed in');
  return ref.watch(billingRepositoryProvider).me();
});

/// The billing role, or viewer while unknown (read-only by default).
final billingRoleProvider = Provider<AdminRole>((ref) => ref.watch(billingMeProvider).value?.role ?? AdminRole.viewer);

final billingAppsProvider = FutureProvider.autoDispose<List<BillingApp>>(
  (ref) => ref.watch(billingRepositoryProvider).apps(),
);

final billingAppProvider = FutureProvider.autoDispose.family<BillingApp, String>(
  (ref, slug) => ref.watch(billingRepositoryProvider).app(slug),
);

final billingProductsProvider = FutureProvider.autoDispose.family<List<BillingProduct>, String>(
  (ref, slug) => ref.watch(billingRepositoryProvider).products(slug),
);

final billingEntitlementsProvider = FutureProvider.autoDispose.family<List<BillingEntitlement>, String>(
  (ref, slug) => ref.watch(billingRepositoryProvider).entitlements(slug),
);

final billingApiKeysProvider = FutureProvider.autoDispose.family<List<BillingApiKey>, String>(
  (ref, slug) => ref.watch(billingRepositoryProvider).apiKeys(slug),
);

final billingWebhooksProvider = FutureProvider.autoDispose.family<List<BillingWebhook>, String>(
  (ref, slug) => ref.watch(billingRepositoryProvider).webhooks(slug),
);

String _cursor(DateTime? d) => (d ?? DateTime.now()).toUtc().toIso8601String();

/// Store-event filter. Records compare by value.
typedef BillingEventsFilter = ({String slug, String? status, String? storeKey});

final billingEventsProvider = NotifierProvider.autoDispose
    .family<BillingEventsList, PagedState<BillingStoreEvent>, BillingEventsFilter>(BillingEventsList.new);

class BillingEventsList extends PagedNotifier<BillingStoreEvent> {
  BillingEventsList(this.filter);
  final BillingEventsFilter filter;

  @override
  Future<List<BillingStoreEvent>> fetch({String? before, required int limit}) => ref
      .read(billingRepositoryProvider)
      .events(filter.slug, status: filter.status, storeKey: filter.storeKey, before: before, limit: limit);

  @override
  String cursorOf(BillingStoreEvent item) => _cursor(item.receivedAt);
}

typedef BillingSubscriptionsFilter = ({String slug, String? state});

final billingSubscriptionsProvider = NotifierProvider.autoDispose
    .family<BillingSubscriptionsList, PagedState<BillingSubscription>, BillingSubscriptionsFilter>(
      BillingSubscriptionsList.new,
    );

class BillingSubscriptionsList extends PagedNotifier<BillingSubscription> {
  BillingSubscriptionsList(this.filter);
  final BillingSubscriptionsFilter filter;

  @override
  Future<List<BillingSubscription>> fetch({String? before, required int limit}) =>
      ref.read(billingRepositoryProvider).subscriptions(filter.slug, state: filter.state, before: before, limit: limit);

  @override
  String cursorOf(BillingSubscription item) => _cursor(item.createdAt);
}

final billingAuditProvider = NotifierProvider.autoDispose<BillingAuditLog, PagedState<BillingAuditEvent>>(
  BillingAuditLog.new,
);

class BillingAuditLog extends PagedNotifier<BillingAuditEvent> {
  @override
  Future<List<BillingAuditEvent>> fetch({String? before, required int limit}) =>
      ref.read(billingRepositoryProvider).audit(before: before, limit: limit);

  @override
  String cursorOf(BillingAuditEvent item) => _cursor(item.at);
}
