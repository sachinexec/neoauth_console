import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/json.dart';
import '../../shared/paged.dart';
import '../auth/admin_me.dart';

/// A row of `GET /admin/users`.
class UserSummary {
  const UserSummary({
    required this.id,
    required this.status,
    required this.appCount,
    this.name,
    this.primaryEmail,
    this.phone,
    this.createdAt,
  });

  final String id;
  final String? name;
  final String? primaryEmail;
  final String? phone;
  final String status;
  final DateTime? createdAt;
  final int appCount;

  String get displayName => name ?? primaryEmail ?? phone ?? id;

  factory UserSummary.fromJson(Json j) => UserSummary(
    id: reqString(j, 'id'),
    name: optString(j, 'name'),
    primaryEmail: optString(j, 'primary_email'),
    phone: optString(j, 'phone'),
    status: optString(j, 'status') ?? 'active',
    createdAt: optDate(j, 'created_at'),
    appCount: optInt(j, 'app_count') ?? 0,
  );
}

class UserIdentity {
  const UserIdentity({
    required this.id,
    required this.provider,
    this.email,
    this.phone,
    this.createdAt,
    this.lastUsedAt,
  });
  final String id;
  final String provider;
  final String? email;
  final String? phone;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;

  factory UserIdentity.fromJson(Json j) => UserIdentity(
    id: reqString(j, 'id'),
    provider: optString(j, 'provider') ?? '',
    email: optString(j, 'email'),
    phone: optString(j, 'phone'),
    createdAt: optDate(j, 'created_at'),
    lastUsedAt: optDate(j, 'last_used_at'),
  );
}

class UserApp {
  const UserApp({
    required this.slug,
    required this.name,
    this.iconUrl,
    this.firstSeenAt,
    this.lastSeenAt,
    this.signupSource,
  });
  final String slug;
  final String name;
  final String? iconUrl;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;
  final String? signupSource;

  factory UserApp.fromJson(Json j) => UserApp(
    slug: reqString(j, 'slug'),
    name: optString(j, 'name') ?? '',
    iconUrl: optString(j, 'icon_url'),
    firstSeenAt: optDate(j, 'first_seen_at'),
    lastSeenAt: optDate(j, 'last_seen_at'),
    signupSource: optString(j, 'signup_source'),
  );
}

class UserPasskey {
  const UserPasskey({
    required this.id,
    this.name,
    this.deviceType,
    this.backedUp = false,
    this.createdAt,
    this.lastUsedAt,
  });
  final String id;
  final String? name;
  final String? deviceType;
  final bool backedUp;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;

  factory UserPasskey.fromJson(Json j) => UserPasskey(
    id: reqString(j, 'id'),
    name: optString(j, 'name'),
    deviceType: optString(j, 'device_type'),
    backedUp: optBool(j, 'backed_up'),
    createdAt: optDate(j, 'created_at'),
    lastUsedAt: optDate(j, 'last_used_at'),
  );
}

class UserSession {
  const UserSession({
    required this.grantId,
    required this.clientId,
    this.clientName,
    this.appSlug,
    this.appName,
    this.loginMethod,
    this.deviceName,
    this.platform,
    this.userAgent,
    this.ip,
    this.createdAt,
    this.lastUsedAt,
  });

  final String grantId;
  final String clientId;
  final String? clientName;
  final String? appSlug;
  final String? appName;
  final String? loginMethod;
  final String? deviceName;
  final String? platform;
  final String? userAgent;
  final String? ip;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;

  factory UserSession.fromJson(Json j) => UserSession(
    grantId: reqString(j, 'grant_id'),
    clientId: optString(j, 'client_id') ?? '',
    clientName: optString(j, 'client_name'),
    appSlug: optString(j, 'app_slug'),
    appName: optString(j, 'app_name'),
    loginMethod: optString(j, 'login_method'),
    deviceName: optString(j, 'device_name'),
    platform: optString(j, 'platform'),
    userAgent: optString(j, 'user_agent'),
    ip: optString(j, 'ip'),
    createdAt: optDate(j, 'created_at'),
    lastUsedAt: optDate(j, 'last_used_at'),
  );
}

/// `GET /admin/users/:id`.
class UserDetail {
  const UserDetail({
    required this.id,
    required this.status,
    required this.identities,
    required this.apps,
    required this.passkeys,
    required this.sessions,
    this.name,
    this.picture,
    this.primaryEmail,
    this.emailVerifiedAt,
    this.phone,
    this.phoneVerifiedAt,
    this.deletionScheduledAt,
    this.createdAt,
    this.updatedAt,
    this.adminRole,
  });

  final String id;
  final String? name;
  final String? picture;
  final String? primaryEmail;
  final DateTime? emailVerifiedAt;
  final String? phone;
  final DateTime? phoneVerifiedAt;
  final String status;
  final DateTime? deletionScheduledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<UserIdentity> identities;
  final List<UserApp> apps;
  final List<UserPasskey> passkeys;
  final List<UserSession> sessions;
  final AdminRole? adminRole;

  String get displayName => name ?? primaryEmail ?? phone ?? id;
  bool get isSuspended => status == 'suspended';

  factory UserDetail.fromJson(Json j) => UserDetail(
    id: reqString(j, 'id'),
    name: optString(j, 'name'),
    picture: optString(j, 'picture'),
    primaryEmail: optString(j, 'primary_email'),
    emailVerifiedAt: optDate(j, 'email_verified_at'),
    phone: optString(j, 'phone'),
    phoneVerifiedAt: optDate(j, 'phone_verified_at'),
    status: optString(j, 'status') ?? 'active',
    deletionScheduledAt: optDate(j, 'deletion_scheduled_at'),
    createdAt: optDate(j, 'created_at'),
    updatedAt: optDate(j, 'updated_at'),
    identities: objList(j, 'identities', UserIdentity.fromJson),
    apps: objList(j, 'apps', UserApp.fromJson),
    passkeys: objList(j, 'passkeys', UserPasskey.fromJson),
    sessions: objList(j, 'sessions', UserSession.fromJson),
    adminRole: AdminRole.tryParse(optString(j, 'admin_role')),
  );
}

class UsersRepository {
  UsersRepository(this._api);
  final ApiClient _api;

  Future<List<UserSummary>> search(String query, {String? before, int limit = 50}) async => objList(
    await _api.get('/users', query: {'q': query.trim(), 'before': before, 'limit': limit}),
    'users',
    UserSummary.fromJson,
  );

  Future<UserDetail> get(String id) async => UserDetail.fromJson(await _api.get('/users/$id'));

  /// Needs a recent sign-in.
  Future<void> suspend(String id, String reason) => _api.postVoid('/users/$id/suspend', body: {'reason': reason});

  Future<void> unsuspend(String id) => _api.postVoid('/users/$id/unsuspend');

  Future<void> revokeSession(String id, String grantId) =>
      _api.deleteVoid('/users/$id/sessions/${Uri.encodeComponent(grantId)}');

  /// Needs a recent sign-in. Returns how many sessions were revoked.
  Future<int> revokeAllSessions(String id) async => optInt(await _api.delete('/users/$id/sessions'), 'revoked') ?? 0;

  /// Needs a recent sign-in. Returns when the data will be erased.
  Future<DateTime?> delete(String id) async => optDate(await _api.delete('/users/$id'), 'erase_after');
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) => UsersRepository(ref.watch(apiClientProvider)));

/// Search results for a query ('' lists everyone, newest first).
final userSearchProvider = NotifierProvider.autoDispose.family<UserSearch, PagedState<UserSummary>, String>(
  UserSearch.new,
);

class UserSearch extends PagedNotifier<UserSummary> {
  UserSearch(this.query);
  final String query;

  @override
  Future<List<UserSummary>> fetch({String? before, required int limit}) =>
      ref.read(usersRepositoryProvider).search(query, before: before, limit: limit);

  @override
  String cursorOf(UserSummary item) => item.id;
}

final userDetailProvider = FutureProvider.autoDispose.family<UserDetail, String>(
  (ref, id) => ref.watch(usersRepositoryProvider).get(id),
);
