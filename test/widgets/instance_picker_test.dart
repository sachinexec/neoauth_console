import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoauth/neoauth.dart';
import 'package:neoauth_console/core/auth/auth_providers.dart';
import 'package:neoauth_console/core/config.dart';
import 'package:neoauth_console/core/router.dart';
import 'package:neoauth_console/shared/widgets/instance_picker.dart';

import '../helpers.dart';

class _MemoryStore implements InstanceSelectionStore {
  String? value;

  @override
  Future<String?> load() async => value;

  @override
  Future<void> save(String instanceId) async => value = instanceId;
}

const _partnerIssuer = 'https://auth.partner.example.com';

AppConfig _config({bool extras = true}) => AppConfig(
  issuer: 'https://auth.example.com',
  clientId: 'console.primary',
  flavor: 'dev',
  billingUrl: 'https://billing.example.com',
  extraInstances: extras
      ? const [
          ConsoleInstance(id: _partnerIssuer, label: 'Partner', issuer: _partnerIssuer, clientId: 'console.partner'),
        ]
      : const [],
);

/// Shows what the API layer targets right now.
class _Probe extends ConsumerWidget {
  const _Probe();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Column(
      children: [
        Text('api ${ref.watch(adminDioProvider).options.baseUrl}'),
        Text('sdk ${ref.watch(neoAuthClientProvider).config.issuer}'),
        Text('billing ${ref.watch(billingAvailableProvider)}'),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Keychain / Keystore reads go to an empty in-memory stub: no stored sessions.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  final created = <ConsoleInstance, NeoAuthClient>{};

  Future<_MemoryStore> pump(WidgetTester tester, AppConfig config, {String? initial}) async {
    created.clear();
    final store = _MemoryStore()..value = initial;
    final clients = NeoAuthClients(
      (i) => created[i] = NeoAuthClient(
        NeoAuthConfig(issuer: i.issuer, clientId: i.clientId, storageKey: i.storageKey),
        http: Dio()..httpClientAdapter = FakeAdapter(),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          neoAuthClientsProvider.overrideWithValue(clients),
          instanceSelectionStoreProvider.overrideWithValue(store),
          initialInstanceIdProvider.overrideWithValue(initial),
        ],
        child: const MaterialApp(home: InstanceBanner(child: _Probe())),
      ),
    );
    return store;
  }

  testWidgets('no picker or banner with only the primary instance', (tester) async {
    await pump(tester, _config(extras: false));
    expect(find.byKey(const Key('instance.picker')), findsNothing);
    expect(find.byKey(const Key('instance.current')), findsNothing);
    expect(find.text('api https://auth.example.com/admin'), findsOneWidget);
    expect(find.text('billing true'), findsOneWidget);
  });

  testWidgets('switching instances retargets the API layer and SDK client, and is remembered', (tester) async {
    final store = await pump(tester, _config());
    expect(find.byKey(const Key('instance.picker')), findsOneWidget);
    expect(find.textContaining('Primary'), findsOneWidget);
    expect(find.text('api https://auth.example.com/admin'), findsOneWidget);
    expect(find.text('sdk https://auth.example.com'), findsOneWidget);
    expect(find.text('billing true'), findsOneWidget);

    await tester.tap(find.byKey(const Key('instance.picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('instance.$_partnerIssuer')));
    await tester.pumpAndSettle();

    expect(find.text('api $_partnerIssuer/admin'), findsOneWidget);
    expect(find.text('sdk $_partnerIssuer'), findsOneWidget);
    expect(find.text('billing false'), findsOneWidget);
    final banner = tester.widget<Text>(find.byKey(const Key('instance.current')));
    expect(banner.textSpan!.toPlainText(), contains('Partner'));
    expect(store.value, _partnerIssuer);

    // Separate clients with separate secure-storage keys: sessions never mix.
    final primary = created.keys.firstWhere((i) => i.isPrimary);
    final partner = created.keys.firstWhere((i) => !i.isPrimary);
    expect(identical(created[primary], created[partner]), isFalse);
    expect(created[partner]!.config.storageKey, isNot(created[primary]!.config.storageKey));

    // And back.
    await tester.tap(find.byKey(const Key('instance.picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('instance.${ConsoleInstance.primaryId}')));
    await tester.pumpAndSettle();
    expect(find.text('api https://auth.example.com/admin'), findsOneWidget);
    expect(store.value, ConsoleInstance.primaryId);
  });

  testWidgets('starts on the remembered instance', (tester) async {
    await pump(tester, _config(), initial: _partnerIssuer);
    expect(find.text('api $_partnerIssuer/admin'), findsOneWidget);
    expect(find.text('billing false'), findsOneWidget);
  });

  testWidgets('signed out: the sign-in screen names the instance and switches with the router', (tester) async {
    created.clear();
    final clients = NeoAuthClients(
      (i) => created[i] = NeoAuthClient(
        NeoAuthConfig(issuer: i.issuer, clientId: i.clientId, storageKey: i.storageKey),
        http: Dio()..httpClientAdapter = FakeAdapter(),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          neoAuthClientsProvider.overrideWithValue(clients),
          instanceSelectionStoreProvider.overrideWithValue(_MemoryStore()),
        ],
        child: Consumer(builder: (_, ref, _) => MaterialApp.router(routerConfig: ref.watch(routerProvider))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('https://auth.example.com'), findsOneWidget);

    await tester.tap(find.byKey(const Key('instance.picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('instance.$_partnerIssuer')));
    await tester.pumpAndSettle();

    expect(find.text(_partnerIssuer), findsOneWidget);
    final banner = tester.widget<Text>(find.byKey(const Key('instance.current')));
    expect(banner.textSpan!.toPlainText(), contains('Partner'));
  });
}
