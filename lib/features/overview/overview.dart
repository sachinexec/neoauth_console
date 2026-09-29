import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/json.dart';

class OverviewTotals {
  const OverviewTotals({
    required this.activeUsers,
    required this.suspendedUsers,
    required this.signups30d,
    required this.apps,
    required this.clients,
    required this.activeSessions30d,
  });

  final int activeUsers;
  final int suspendedUsers;
  final int signups30d;
  final int apps;
  final int clients;
  final int activeSessions30d;

  factory OverviewTotals.fromJson(Json j) => OverviewTotals(
    activeUsers: optInt(j, 'active_users') ?? 0,
    suspendedUsers: optInt(j, 'suspended_users') ?? 0,
    signups30d: optInt(j, 'signups_30d') ?? 0,
    apps: optInt(j, 'apps') ?? 0,
    clients: optInt(j, 'clients') ?? 0,
    activeSessions30d: optInt(j, 'active_sessions_30d') ?? 0,
  );
}

class AppUsage {
  const AppUsage({
    required this.slug,
    required this.name,
    required this.users,
    required this.new30d,
    required this.active30d,
  });
  final String slug;
  final String name;
  final int users;
  final int new30d;
  final int active30d;

  factory AppUsage.fromJson(Json j) => AppUsage(
    slug: reqString(j, 'slug'),
    name: optString(j, 'name') ?? '',
    users: optInt(j, 'users') ?? 0,
    new30d: optInt(j, 'new_30d') ?? 0,
    active30d: optInt(j, 'active_30d') ?? 0,
  );
}

class DailySignups {
  const DailySignups(this.day, this.signups);
  final DateTime day;
  final int signups;

  /// `day` is `YYYY-MM-DD` (server time zone); parsed as a local date.
  factory DailySignups.fromJson(Json j) {
    final raw = reqString(j, 'day');
    final p = raw.split('-').map(int.parse).toList();
    return DailySignups(DateTime(p[0], p[1], p[2]), optInt(j, 'signups') ?? 0);
  }
}

/// `GET /admin/overview`.
class Overview {
  const Overview({required this.totals, required this.apps, required this.signups});
  final OverviewTotals totals;
  final List<AppUsage> apps;
  final List<DailySignups> signups;

  factory Overview.fromJson(Json j) => Overview(
    totals: OverviewTotals.fromJson(optMap(j, 'totals')),
    apps: objList(j, 'apps', AppUsage.fromJson),
    signups: objList(j, 'signups', DailySignups.fromJson),
  );
}

final overviewProvider = FutureProvider.autoDispose<Overview>((ref) async {
  return Overview.fromJson(await ref.watch(apiClientProvider).get('/overview'));
});
