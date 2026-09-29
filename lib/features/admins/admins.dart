import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/json.dart';
import '../auth/admin_me.dart';

/// A row of `GET /admin/admins`.
class AdminEntry {
  const AdminEntry({
    required this.userId,
    required this.role,
    this.name,
    this.primaryEmail,
    this.phone,
    this.createdAt,
  });
  final String userId;
  final AdminRole role;
  final String? name;
  final String? primaryEmail;
  final String? phone;
  final DateTime? createdAt;

  String get displayName => name ?? primaryEmail ?? phone ?? userId;

  factory AdminEntry.fromJson(Json j) => AdminEntry(
    userId: reqString(j, 'user_id'),
    role: AdminRole.parse(optString(j, 'role')),
    name: optString(j, 'name'),
    primaryEmail: optString(j, 'primary_email'),
    phone: optString(j, 'phone'),
    createdAt: optDate(j, 'created_at'),
  );
}

/// A row of `GET /admin/audience`: users who opted in to hearing about our other apps.
class AudienceMember {
  const AudienceMember({required this.id, required this.apps, this.name, this.primaryEmail, this.phone});
  final String id;
  final String? name;
  final String? primaryEmail;
  final String? phone;
  final List<String> apps;

  factory AudienceMember.fromJson(Json j) => AudienceMember(
    id: reqString(j, 'id'),
    name: optString(j, 'name'),
    primaryEmail: optString(j, 'primary_email'),
    phone: optString(j, 'phone'),
    apps: stringList(j, 'apps'),
  );
}

class AdminsRepository {
  AdminsRepository(this._api);
  final ApiClient _api;

  Future<List<AdminEntry>> list() async => objList(await _api.get('/admins'), 'admins', AdminEntry.fromJson);

  /// Grants or changes a role. Owner only; needs a recent sign-in.
  Future<List<AdminEntry>> setRole(String userId, AdminRole role) async =>
      objList(await _api.put('/admins/$userId', body: {'role': role.wire}), 'admins', AdminEntry.fromJson);

  Future<List<AdminEntry>> remove(String userId) async =>
      objList(await _api.delete('/admins/$userId'), 'admins', AdminEntry.fromJson);

  /// Owner only; needs a recent sign-in.
  Future<List<AudienceMember>> audience({String? targetApp, String? before, int limit = 100}) async => objList(
    await _api.get('/audience', query: {'target_app': targetApp, 'before': before, 'limit': limit}),
    'users',
    AudienceMember.fromJson,
  );
}

final adminsRepositoryProvider = Provider<AdminsRepository>((ref) => AdminsRepository(ref.watch(apiClientProvider)));

final adminsProvider = FutureProvider.autoDispose<List<AdminEntry>>(
  (ref) => ref.watch(adminsRepositoryProvider).list(),
);

final uuidPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
