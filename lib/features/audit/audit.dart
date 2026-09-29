import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/json.dart';
import '../../shared/paged.dart';

/// A row of `GET /admin/audit`. The ID is a bigint, sent as a string.
class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.at,
    required this.event,
    required this.data,
    this.userId,
    this.clientId,
    this.appId,
    this.ip,
    this.userAgent,
  });

  final String id;
  final DateTime at;
  final String event;
  final String? userId;
  final String? clientId;
  final String? appId;
  final String? ip;
  final String? userAgent;
  final Map<String, dynamic> data;

  factory AuditEvent.fromJson(Json j) => AuditEvent(
    id: j['id'].toString(),
    at: reqDate(j, 'at'),
    event: reqString(j, 'event'),
    userId: optString(j, 'user_id'),
    clientId: optString(j, 'client_id'),
    appId: optString(j, 'app_id'),
    ip: _blankToNull(optString(j, 'ip')),
    userAgent: _blankToNull(optString(j, 'user_agent')),
    data: optMap(j, 'data'),
  );

  static String? _blankToNull(String? s) => (s == null || s.isEmpty) ? null : s;

  /// Event names the server records, for the filter's suggestions.
  static const knownEvents = [
    'admin.app_created',
    'admin.app_token_policy_changed',
    'admin.app_updated',
    'admin.audience_exported',
    'admin.client_created',
    'admin.client_secret_rotated',
    'admin.client_token_policy_changed',
    'admin.client_updated',
    'admin.role_granted',
    'admin.role_revoked',
    'admin.webhook_created',
    'admin.webhook_deleted',
    'app.first_use',
    'attestation.failed',
    'attestation.registration_failed',
    'consent.granted',
    'grant.revoked',
    'identity.unlinked',
    'login.success',
    'session.logout',
    'session.revoked',
    'session.revoked_all',
    'token.issued',
    'user.created',
    'user.deleted',
    'user.erased',
    'user.suspended',
    'user.unsuspended',
    'user.updated',
  ];
}

/// Audit filter. Records compare by value, so each filter gets its own list.
typedef AuditFilter = ({String? event, String? userId});

final auditLogProvider = NotifierProvider.autoDispose.family<AuditLog, PagedState<AuditEvent>, AuditFilter>(
  AuditLog.new,
);

class AuditLog extends PagedNotifier<AuditEvent> {
  AuditLog(this.filter);
  final AuditFilter filter;

  @override
  Future<List<AuditEvent>> fetch({String? before, required int limit}) async => objList(
    await ref
        .read(apiClientProvider)
        .get('/audit', query: {'event': filter.event, 'user_id': filter.userId, 'before': before, 'limit': limit}),
    'events',
    AuditEvent.fromJson,
  );

  @override
  String cursorOf(AuditEvent item) => item.id;
}
