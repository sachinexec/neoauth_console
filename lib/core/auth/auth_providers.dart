import 'package:neoauth/neoauth.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/admin_me.dart';
import '../api/api_client.dart';
import '../config.dart';
import 'instances.dart';

export 'instances.dart';

/// Overridden in `main()` with the dart-define configuration.
final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

/// One SDK client per instance. Overridden in `main()` with one whose
/// selected instance has already restored its stored session.
final neoAuthClientsProvider = Provider<NeoAuthClients>((ref) => NeoAuthClients.console(deviceName: 'NeoAuth Console'));

/// Where the last chosen instance is remembered on this device.
final instanceSelectionStoreProvider = Provider<InstanceSelectionStore>(
  (ref) => const SharedPreferencesInstanceStore(),
);

/// The instance chosen at startup (the remembered one). Overridden in `main()`.
final initialInstanceIdProvider = Provider<String?>((ref) => null);

/// The instance the console is talking to. Everything below (the SDK client,
/// the admin API, every data provider built on them) depends on it, so
/// switching drops whatever was loaded from the previous instance.
final activeInstanceProvider = NotifierProvider<ActiveInstance, ConsoleInstance>(ActiveInstance.new);

class ActiveInstance extends Notifier<ConsoleInstance> {
  @override
  ConsoleInstance build() => ref.watch(appConfigProvider).instanceById(ref.read(initialInstanceIdProvider));

  /// Switches to [instance] once its stored session is loaded, and remembers
  /// the choice. The router then shows its sign-in when there is no session.
  Future<void> select(ConsoleInstance instance) async {
    if (instance == state) return;
    await ref.read(neoAuthClientsProvider).restore(instance);
    try {
      await ref.read(instanceSelectionStoreProvider).save(instance.id);
    } catch (e) {
      debugPrint('neoauth_console: could not remember the instance: $e');
    }
    if (ref.mounted) state = instance;
  }
}

/// The active instance's SDK client.
final neoAuthClientProvider = Provider<NeoAuthClient>(
  (ref) => ref.watch(neoAuthClientsProvider).clientFor(ref.watch(activeInstanceProvider)),
);

/// The Billing section belongs to the primary instance only.
final billingAvailableProvider = Provider<bool>((ref) => ref.watch(activeInstanceProvider).isPrimary);

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

/// Dio for the active instance's `<issuer>/admin`, with the SDK's bearer-token
/// interceptor. The console's access tokens are issued for the admin API by
/// default.
final adminDioProvider = Provider<Dio>((ref) {
  final instance = ref.watch(activeInstanceProvider);
  final auth = ref.watch(neoAuthClientProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: instance.adminBaseUrl,
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

/// The signed-in admin's role, or viewer while unknown (read-only by default),
/// including while it reloads for another instance or account.
final roleProvider = Provider<AdminRole>((ref) {
  final me = ref.watch(meProvider);
  return me.isReloading ? AdminRole.viewer : me.value?.role ?? AdminRole.viewer;
});
