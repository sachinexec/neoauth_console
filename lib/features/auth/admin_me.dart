import '../../core/json.dart';

/// A console role. Viewers read; admins change apps, clients and users;
/// owners also manage admins and export the marketing audience.
enum AdminRole {
  viewer('Viewer'),
  admin('Admin'),
  owner('Owner');

  const AdminRole(this.label);
  final String label;

  String get wire => name;

  bool atLeast(AdminRole other) => index >= other.index;
  bool get canEdit => atLeast(AdminRole.admin);
  bool get isOwner => this == AdminRole.owner;

  static AdminRole parse(String? v) => AdminRole.values.firstWhere((r) => r.name == v, orElse: () => AdminRole.viewer);

  static AdminRole? tryParse(String? v) {
    for (final r in AdminRole.values) {
      if (r.name == v) return r;
    }
    return null;
  }
}

/// `GET /admin/me`.
class AdminMe {
  const AdminMe({required this.userId, required this.role, this.name, this.email, this.phone, this.authTime});

  final String? userId;
  final String? name;
  final String? email;
  final String? phone;
  final AdminRole role;

  /// When this session last signed in (not refreshed).
  final DateTime? authTime;

  String get displayName => name ?? email ?? phone ?? userId ?? 'Admin';

  factory AdminMe.fromJson(Json j) => AdminMe(
    userId: optString(j, 'user_id'),
    name: optString(j, 'name'),
    email: optString(j, 'email'),
    phone: optString(j, 'phone'),
    role: AdminRole.parse(optString(j, 'role')),
    authTime: optDate(j, 'auth_time'),
  );
}
