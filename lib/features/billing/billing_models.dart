import '../../core/json.dart';
import '../auth/admin_me.dart';

/// `GET /admin/v1/me` on the billing service: the caller and their billing
/// role (separate from the console role: billing keeps its own admin list).
class BillingMe {
  const BillingMe({required this.role, this.sub, this.authTime});

  final AdminRole role;
  final String? sub;
  final DateTime? authTime;

  factory BillingMe.fromJson(Json j) => BillingMe(
    role: AdminRole.parse(optString(j, 'role')),
    sub: optString(j, 'sub'),
    authTime: optDate(j, 'auth_time'),
  );
}

/// Store credentials as the server describes them: identifiers only. Secrets
/// are write-only and never come back.
class AppleCredentialInfo {
  const AppleCredentialInfo({
    required this.configured,
    this.bundleId,
    this.issuerId,
    this.keyId,
    this.appAppleId,
    this.allowSandbox = false,
  });

  final bool configured;
  final String? bundleId;
  final String? issuerId;
  final String? keyId;
  final int? appAppleId;
  final bool allowSandbox;

  factory AppleCredentialInfo.fromJson(Json j) => AppleCredentialInfo(
    configured: optBool(j, 'configured'),
    bundleId: optString(j, 'bundle_id'),
    issuerId: optString(j, 'issuer_id'),
    keyId: optString(j, 'key_id'),
    appAppleId: optInt(j, 'app_apple_id'),
    allowSandbox: optBool(j, 'allow_sandbox'),
  );
}

class GoogleCredentialInfo {
  const GoogleCredentialInfo({
    required this.configured,
    this.packageName,
    this.serviceAccountEmail,
    this.allowSandbox = false,
  });

  final bool configured;
  final String? packageName;
  final String? serviceAccountEmail;
  final bool allowSandbox;

  factory GoogleCredentialInfo.fromJson(Json j) => GoogleCredentialInfo(
    configured: optBool(j, 'configured'),
    packageName: optString(j, 'package_name'),
    serviceAccountEmail: optString(j, 'service_account_email'),
    allowSandbox: optBool(j, 'allow_sandbox'),
  );
}

class BillingApp {
  const BillingApp({
    required this.id,
    required this.slug,
    required this.name,
    required this.apiAudience,
    required this.status,
    required this.requireAccountBinding,
    required this.allowRestoreTransfer,
    required this.neoauthWebhookConfigured,
    required this.apple,
    required this.google,
    this.createdAt,
  });

  final String id;
  final String slug;
  final String name;

  /// The `aud` of the NeoAuth access tokens this app's clients send.
  final String apiAudience;
  final String status;
  final bool requireAccountBinding;
  final bool allowRestoreTransfer;
  final bool neoauthWebhookConfigured;
  final AppleCredentialInfo apple;
  final GoogleCredentialInfo google;
  final DateTime? createdAt;

  bool get isActive => status == 'active';

  factory BillingApp.fromJson(Json j) => BillingApp(
    id: optString(j, 'id') ?? '',
    slug: reqString(j, 'slug'),
    name: reqString(j, 'name'),
    apiAudience: optString(j, 'api_audience') ?? '',
    status: optString(j, 'status') ?? 'active',
    requireAccountBinding: optBool(j, 'require_account_binding', fallback: true),
    allowRestoreTransfer: optBool(j, 'allow_restore_transfer'),
    neoauthWebhookConfigured: optBool(j, 'neoauth_webhook_configured'),
    apple: AppleCredentialInfo.fromJson(optMap(j, 'apple')),
    google: GoogleCredentialInfo.fromJson(optMap(j, 'google')),
    createdAt: optDate(j, 'created_at'),
  );
}

class BillingEntitlement {
  const BillingEntitlement({required this.key, required this.name});
  final String key;
  final String name;

  factory BillingEntitlement.fromJson(Json j) =>
      BillingEntitlement(key: reqString(j, 'key'), name: reqString(j, 'name'));
}

enum ProductKind {
  subscription('Subscription'),
  lifetime('Lifetime');

  const ProductKind(this.label);
  final String label;

  static ProductKind parse(String? v) =>
      ProductKind.values.firstWhere((k) => k.name == v, orElse: () => ProductKind.subscription);
}

class BillingProduct {
  const BillingProduct({
    required this.slug,
    required this.name,
    required this.kind,
    required this.active,
    required this.sortOrder,
    required this.entitlements,
    this.appleProductId,
    this.googleProductId,
    this.periodDays,
  });

  final String slug;
  final String name;
  final ProductKind kind;
  final bool active;
  final int sortOrder;
  final String? appleProductId;
  final String? googleProductId;
  final int? periodDays;

  /// Entitlement keys it unlocks.
  final List<String> entitlements;

  factory BillingProduct.fromJson(Json j) => BillingProduct(
    slug: reqString(j, 'slug'),
    name: reqString(j, 'name'),
    kind: ProductKind.parse(optString(j, 'kind')),
    active: optBool(j, 'active', fallback: true),
    sortOrder: optInt(j, 'sort_order') ?? 0,
    appleProductId: optString(j, 'apple_product_id'),
    googleProductId: optString(j, 'google_product_id'),
    periodDays: optInt(j, 'period_days'),
    entitlements: stringList(j, 'entitlements'),
  );
}

/// An entitlement as the app sees it (`active`, with source and state).
class ActiveEntitlement {
  const ActiveEntitlement({required this.key, this.expiresAt, this.product, this.source, this.state, this.willRenew});

  final String key;
  final DateTime? expiresAt;
  final String? product;
  final String? source;
  final String? state;
  final bool? willRenew;

  factory ActiveEntitlement.fromJson(Json j) => ActiveEntitlement(
    key: reqString(j, 'key'),
    expiresAt: optDate(j, 'expires_at'),
    product: optString(j, 'product'),
    source: optString(j, 'source'),
    state: optString(j, 'state'),
    willRenew: j['will_renew'] is bool ? j['will_renew'] as bool : null,
  );
}

class BillingSubscription {
  const BillingSubscription({
    required this.id,
    required this.platform,
    required this.state,
    required this.environment,
    required this.kind,
    required this.storeKey,
    required this.autoRenew,
    required this.erased,
    required this.ackPending,
    this.userSub,
    this.periodStart,
    this.expiresAt,
    this.graceExpiresAt,
    this.revokeReason,
    this.revokedAt,
    this.lastEventAt,
    this.lastSyncedAt,
    this.createdAt,
  });

  final String id;
  final String? userSub;
  final String platform;
  final String storeKey;
  final String kind;
  final String environment;
  final String state;
  final bool autoRenew;
  final bool erased;
  final bool ackPending;
  final DateTime? periodStart;
  final DateTime? expiresAt;
  final DateTime? graceExpiresAt;
  final String? revokeReason;
  final DateTime? revokedAt;
  final DateTime? lastEventAt;
  final DateTime? lastSyncedAt;
  final DateTime? createdAt;

  bool get isSandbox => environment == 'sandbox';

  factory BillingSubscription.fromJson(Json j) => BillingSubscription(
    id: reqString(j, 'id'),
    userSub: optString(j, 'user_sub'),
    platform: optString(j, 'platform') ?? '',
    storeKey: optString(j, 'store_key') ?? '',
    kind: optString(j, 'kind') ?? '',
    environment: optString(j, 'environment') ?? 'production',
    state: optString(j, 'state') ?? '',
    autoRenew: optBool(j, 'auto_renew'),
    erased: optBool(j, 'erased'),
    ackPending: optBool(j, 'ack_pending'),
    periodStart: optDate(j, 'period_start'),
    expiresAt: optDate(j, 'expires_at'),
    graceExpiresAt: optDate(j, 'grace_expires_at'),
    revokeReason: optString(j, 'revoke_reason'),
    revokedAt: optDate(j, 'revoked_at'),
    lastEventAt: optDate(j, 'last_event_at'),
    lastSyncedAt: optDate(j, 'last_synced_at'),
    createdAt: optDate(j, 'created_at'),
  );
}

class BillingGrant {
  const BillingGrant({
    required this.id,
    required this.reason,
    this.entitlement,
    this.expiresAt,
    this.revokedAt,
    this.grantedBy,
    this.createdAt,
  });

  final String id;
  final String? entitlement;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final String reason;
  final String? grantedBy;
  final DateTime? createdAt;

  /// Still in force at [now].
  bool isActive(DateTime now) => revokedAt == null && (expiresAt == null || expiresAt!.isAfter(now));

  factory BillingGrant.fromJson(Json j) => BillingGrant(
    id: reqString(j, 'id'),
    entitlement: optString(j, 'entitlement'),
    expiresAt: optDate(j, 'expires_at'),
    revokedAt: optDate(j, 'revoked_at'),
    reason: optString(j, 'reason') ?? '',
    grantedBy: optString(j, 'granted_by'),
    createdAt: optDate(j, 'created_at'),
  );
}

/// `GET /admin/v1/apps/:slug/users/:sub`.
class BillingCustomer {
  const BillingCustomer({
    required this.sub,
    required this.entitlements,
    required this.subscriptions,
    required this.grants,
  });

  final String sub;
  final List<ActiveEntitlement> entitlements;
  final List<BillingSubscription> subscriptions;
  final List<BillingGrant> grants;

  factory BillingCustomer.fromJson(Json j) => BillingCustomer(
    sub: reqString(j, 'sub'),
    entitlements: objList(j, 'entitlements', ActiveEntitlement.fromJson),
    subscriptions: objList(j, 'subscriptions', BillingSubscription.fromJson),
    grants: [
      if (j['grants'] is List)
        for (final g in j['grants'] as List<dynamic>)
          if (g is Map) BillingGrant.fromJson(g.cast<String, dynamic>()),
    ],
  );
}

/// A stored store event (notification, client verify, reconcile, admin).
class BillingStoreEvent {
  const BillingStoreEvent({
    required this.id,
    required this.platform,
    required this.source,
    required this.eventType,
    required this.status,
    required this.attempts,
    required this.hasPayload,
    this.storeEventId,
    this.subtype,
    this.storeKey,
    this.eventTime,
    this.receivedAt,
    this.outcome,
    this.error,
  });

  final String id;
  final String platform;
  final String? storeEventId;
  final String source;
  final String eventType;
  final String? subtype;
  final String? storeKey;
  final DateTime? eventTime;
  final DateTime? receivedAt;
  final String status;
  final String? outcome;
  final int attempts;
  final String? error;
  final bool hasPayload;

  /// The server only replays stored notifications.
  bool get canReplay => source == 'notification' || source == 'admin';

  factory BillingStoreEvent.fromJson(Json j) => BillingStoreEvent(
    id: reqString(j, 'id'),
    platform: optString(j, 'platform') ?? '',
    storeEventId: optString(j, 'store_event_id'),
    source: optString(j, 'source') ?? '',
    eventType: optString(j, 'event_type') ?? '',
    subtype: optString(j, 'subtype'),
    storeKey: optString(j, 'store_key'),
    eventTime: optDate(j, 'event_time'),
    receivedAt: optDate(j, 'received_at'),
    status: optString(j, 'status') ?? '',
    outcome: optString(j, 'outcome'),
    attempts: optInt(j, 'attempts') ?? 0,
    error: optString(j, 'error'),
    hasPayload: optBool(j, 'has_payload'),
  );
}

class BillingApiKey {
  const BillingApiKey({
    required this.id,
    required this.name,
    required this.prefix,
    required this.scopes,
    required this.status,
    this.expiresAt,
    this.lastUsedAt,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String name;

  /// Shown instead of the key (`nbk_<prefix>`).
  final String prefix;
  final List<String> scopes;
  final String status;
  final DateTime? expiresAt;
  final DateTime? lastUsedAt;
  final String? createdBy;
  final DateTime? createdAt;

  bool get isActive => status == 'active';

  factory BillingApiKey.fromJson(Json j) => BillingApiKey(
    id: reqString(j, 'id'),
    name: reqString(j, 'name'),
    prefix: optString(j, 'prefix') ?? '',
    scopes: stringList(j, 'scopes'),
    status: optString(j, 'status') ?? 'active',
    expiresAt: optDate(j, 'expires_at'),
    lastUsedAt: optDate(j, 'last_used_at'),
    createdBy: optString(j, 'created_by'),
    createdAt: optDate(j, 'created_at'),
  );
}

/// A new API key: the only time its secret is ever returned.
class CreatedApiKey {
  const CreatedApiKey({required this.key, required this.secret});
  final BillingApiKey key;
  final String secret;

  factory CreatedApiKey.fromJson(Json j) => CreatedApiKey(key: BillingApiKey.fromJson(j), secret: reqString(j, 'key'));
}

class BillingWebhook {
  const BillingWebhook({
    required this.id,
    required this.url,
    required this.events,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String url;
  final List<String> events;
  final String status;
  final DateTime? createdAt;

  /// Every event a webhook can subscribe to.
  static const allEvents = <String>[
    'entitlement.granted',
    'entitlement.updated',
    'entitlement.revoked',
    'subscription.initial_purchase',
    'subscription.renewal',
    'subscription.cancellation',
    'subscription.uncancellation',
    'subscription.expiration',
    'subscription.billing_issue',
    'subscription.product_change',
    'subscription.refund',
    'subscription.paused',
    'subscription.transfer',
    'trial.started',
    'trial.converted',
  ];

  factory BillingWebhook.fromJson(Json j) => BillingWebhook(
    id: reqString(j, 'id'),
    url: reqString(j, 'url'),
    events: stringList(j, 'events'),
    status: optString(j, 'status') ?? 'active',
    createdAt: optDate(j, 'created_at'),
  );
}

/// A new webhook endpoint: the only time its signing secret is returned.
class CreatedWebhook {
  const CreatedWebhook({required this.webhook, required this.secret});
  final BillingWebhook webhook;
  final String secret;

  factory CreatedWebhook.fromJson(Json j) =>
      CreatedWebhook(webhook: BillingWebhook.fromJson(j), secret: reqString(j, 'secret'));
}

class WebhookPing {
  const WebhookPing({required this.ok, this.status, this.error});
  final bool ok;
  final int? status;
  final String? error;

  factory WebhookPing.fromJson(Json j) =>
      WebhookPing(ok: optBool(j, 'ok'), status: optInt(j, 'status'), error: optString(j, 'error'));
}

class BillingAuditEvent {
  const BillingAuditEvent({
    required this.id,
    required this.event,
    required this.at,
    required this.data,
    this.actor,
    this.userSub,
    this.appId,
  });

  final String id;
  final String event;
  final String? actor;
  final String? userSub;
  final String? appId;
  final DateTime at;
  final Map<String, dynamic> data;

  factory BillingAuditEvent.fromJson(Json j) => BillingAuditEvent(
    id: j['id'].toString(),
    event: reqString(j, 'event'),
    actor: optString(j, 'actor'),
    userSub: optString(j, 'user_sub'),
    appId: optString(j, 'app_id'),
    at: reqDate(j, 'created_at'),
    data: optMap(j, 'data'),
  );
}
