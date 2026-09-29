import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/json.dart';
import 'models/app_models.dart';

/// Apps, clients, webhooks and provider support (admin API).
class AppsRepository {
  AppsRepository(this._api);
  final ApiClient _api;

  Future<ProviderSupport> providers() async => ProviderSupport.fromJson(await _api.get('/providers'));

  Future<List<AppModel>> list() async => objList(await _api.get('/apps'), 'apps', AppModel.fromJson);

  Future<AppModel> get(String slug) async => AppModel.fromJson(await _api.get('/apps/${Uri.encodeComponent(slug)}'));

  Future<AppModel> create({
    required String slug,
    required String name,
    required String apiAudience,
    String? description,
    String? iconUrl,
    String? marketingUrl,
    List<LoginMethod>? loginMethods,
  }) async {
    final json = await _api.post(
      '/apps',
      body: {
        'slug': slug,
        'name': name,
        'api_audience': apiAudience,
        'description': ?description,
        'icon_url': ?iconUrl,
        'marketing_url': ?marketingUrl,
        if (loginMethods != null) 'login_methods': LoginMethod.toWire(loginMethods),
      },
    );
    return AppModel.fromJson(json);
  }

  /// PATCH with only the given fields. Pass an explicit null in [fields] to clear.
  Future<AppModel> update(String slug, Json fields) async =>
      AppModel.fromJson(await _api.patch('/apps/${Uri.encodeComponent(slug)}', body: fields));

  Future<AppModel> setLoginMethods(String slug, Set<LoginMethod> methods) =>
      update(slug, {'login_methods': LoginMethod.toWire(methods)});

  Future<AppModel> setStatus(String slug, {required bool active}) =>
      update(slug, {'status': active ? 'active' : 'disabled'});

  Future<AppModel> setTokenPolicy(String slug, TokenPolicyInput policy) async => AppModel.fromJson(
    await _api.put('/apps/${Uri.encodeComponent(slug)}/token-policy', body: {'token_policy': policy.toJson()}),
  );

  // ── Clients ───────────────────────────────────────────────────────────────

  Future<ClientModel> createClient(
    String slug, {
    required String name,
    required ApplicationType applicationType,
    required ClientType clientType,
    required bool firstParty,
    required List<String> redirectUris,
    List<String> postLogoutRedirectUris = const [],
    String? backchannelLogoutUri,
    bool nativeLogin = false,
  }) async {
    final json = await _api.post(
      '/apps/${Uri.encodeComponent(slug)}/clients',
      body: {
        'name': name,
        'application_type': applicationType.name,
        'client_type': clientType.name,
        'first_party': firstParty,
        'redirect_uris': redirectUris,
        if (postLogoutRedirectUris.isNotEmpty) 'post_logout_redirect_uris': postLogoutRedirectUris,
        'backchannel_logout_uri': ?backchannelLogoutUri,
        if (firstParty) 'native_login': nativeLogin,
      },
    );
    return ClientModel.fromJson(json);
  }

  Future<ClientModel> client(String clientId) async =>
      ClientModel.fromJson(await _api.get('/clients/${Uri.encodeComponent(clientId)}'));

  Future<ClientModel> updateClient(String clientId, Json fields) async =>
      ClientModel.fromJson(await _api.patch('/clients/${Uri.encodeComponent(clientId)}', body: fields));

  /// Null [methods] goes back to inheriting the app's methods.
  Future<ClientModel> setClientLoginMethods(String clientId, Set<LoginMethod>? methods) =>
      updateClient(clientId, {'login_methods': methods == null ? null : LoginMethod.toWire(methods)});

  Future<ClientModel> setClientTokenPolicy(String clientId, TokenPolicyInput override) async => ClientModel.fromJson(
    await _api.put('/clients/${Uri.encodeComponent(clientId)}/token-policy', body: {'token_policy': override.toJson()}),
  );

  Future<ClientModel> setAttestation(String clientId, AttestationConfig config) =>
      updateClient(clientId, {'attestation': config.toJson()});

  /// Returns the new secret (shown once). Needs a recent sign-in.
  Future<String> rotateSecret(String clientId) async =>
      reqString(await _api.post('/clients/${Uri.encodeComponent(clientId)}/rotate-secret'), 'client_secret');

  // ── Webhooks ──────────────────────────────────────────────────────────────

  Future<WebhookEndpoint> createWebhook(String slug, {required String url, required List<String> events}) async =>
      WebhookEndpoint.fromJson(
        await _api.post('/apps/${Uri.encodeComponent(slug)}/webhooks', body: {'url': url, 'events': events}),
      );

  Future<void> deleteWebhook(String slug, String id) =>
      _api.deleteVoid('/apps/${Uri.encodeComponent(slug)}/webhooks/${Uri.encodeComponent(id)}');

  Future<PingResult> pingWebhook(String slug, String id) async => PingResult.fromJson(
    await _api.post('/apps/${Uri.encodeComponent(slug)}/webhooks/${Uri.encodeComponent(id)}/ping'),
  );
}

final appsRepositoryProvider = Provider<AppsRepository>((ref) => AppsRepository(ref.watch(apiClientProvider)));

/// What this server can run. Rarely changes, so kept for the session.
final providerSupportProvider = FutureProvider<ProviderSupport>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(appsRepositoryProvider).providers();
});

final appsListProvider = FutureProvider.autoDispose<List<AppModel>>((ref) => ref.watch(appsRepositoryProvider).list());

final appDetailProvider = FutureProvider.autoDispose.family<AppModel, String>(
  (ref, slug) => ref.watch(appsRepositoryProvider).get(slug),
);

final clientDetailProvider = FutureProvider.autoDispose.family<ClientModel, String>(
  (ref, clientId) => ref.watch(appsRepositoryProvider).client(clientId),
);

/// After any change to a client: refresh it and its app (which lists clients).
void refreshClient(WidgetRef ref, ClientModel c) {
  ref.invalidate(clientDetailProvider(c.clientId));
  ref.invalidate(appDetailProvider(c.appSlug));
  ref.invalidate(appsListProvider);
}
