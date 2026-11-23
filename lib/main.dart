import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/auth/auth_providers.dart';
import 'core/config.dart';
import 'features/auth/step_up.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadEnvironment(appFlavor);
  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment(flavor: appFlavor);
  } on FormatException catch (e) {
    runApp(_ConfigErrorApp(e.message));
    return;
  }
  final clients = NeoAuthClients.console(deviceName: 'NeoAuth Console (${Platform.operatingSystem})');
  const store = SharedPreferencesInstanceStore();
  String? storedInstance;
  try {
    storedInstance = await store.load();
  } catch (e) {
    debugPrint('neoauth_console: could not read the last instance: $e');
  }
  // Load the stored session of the instance shown first before the first
  // frame, so the router starts in the right place. The others load when
  // switched to.
  await clients.restore(config.instanceById(storedInstance));

  runApp(
    ProviderScope(
      // Failed requests surface an error with a retry button instead of
      // being retried silently in the background.
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        neoAuthClientsProvider.overrideWithValue(clients),
        instanceSelectionStoreProvider.overrideWithValue(store),
        initialInstanceIdProvider.overrideWithValue(storedInstance),
        stepUpHandlerProvider.overrideWith(createStepUpHandler),
      ],
      child: const NeoAuthConsoleApp(),
    ),
  );
}

/// A malformed setting in the env file: say which, instead of a blank screen.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: SelectableText('Configuration error\n\n$message', textAlign: TextAlign.center)),
        ),
      ),
    ),
  );
}
