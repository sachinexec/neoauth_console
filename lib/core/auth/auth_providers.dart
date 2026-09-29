import 'package:neoauth/neoauth.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/admin_me.dart';
import '../api/api_client.dart';
import '../config.dart';

/// Overridden in `main()` with the dart-define configuration.
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

/// The SDK client. Overridden in `main()` with an instance that has already
/// restored its stored session.
final neoAuthClientProvider = Provider<NeoAuthClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return NeoAuthClient(NeoAuthConfig(issuer: config.issuer, clientId: config.clientId, deviceName: 'NeoAuth Console'));
});

/// The signed-in user (from the ID token), updated whenever the SDK's session
/// changes: sign-in, step-up, sign-out, or a session that ended server-side.
final currentUserProvider = NotifierProvider<CurrentUser, NeoAuthUser?>(CurrentUser.new);

class CurrentUser extends Notifier<NeoAuthUser?> {
  @override
  NeoAuthUser? build() {
    final auth = ref.watch(neoAuthClientProvider);
    void listener() => state = auth.currentUser;
    auth.addListener(listener);
    ref.onDispose(() => auth.removeListener(listener));
    return auth.currentUser;
  }

  @override
  bool updateShouldNotify(NeoAuthUser? previous, NeoAuthUser? next) =>
      previous?.claims['sub'] != next?.claims['sub'] || previous?.claims['auth_time'] != next?.claims['auth_time'];
}

/// Only the user ID, so dependants refetch when the account changes but not
/// when the same admin re-authenticates.
final currentUserIdProvider = Provider<String?>((ref) => ref.watch(currentUserProvider)?.id);

/// Dio for `<issuer>/admin`, with the SDK's bearer-token interceptor. The
/// console's access tokens are issued for the admin API by default.
final adminDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final auth = ref.watch(neoAuthClientProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.adminBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
  dio.interceptors.add(auth.interceptor());
  return dio;
});

/// Shows the re-authenticate sheet; overridden in `main()` (it needs the navigator).
final stepUpHandlerProvider = Provider<StepUpHandler?>((ref) => null);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(adminDioProvider), onStepUp: ref.watch(stepUpHandlerProvider)),
);

/// `GET /admin/me`: who is signed in and their console role. Errors with a
/// 403 when the account has no console role.
final meProvider = FutureProvider<AdminMe>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw StateError('Not signed in');
  final json = await ref.watch(apiClientProvider).get('/me');
  return AdminMe.fromJson(json);
});

/// The signed-in admin's role, or viewer while unknown (read-only by default).
final roleProvider = Provider<AdminRole>((ref) => ref.watch(meProvider).value?.role ?? AdminRole.viewer);
