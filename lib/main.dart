import 'dart:io' show Platform;

import 'package:neoauth/neoauth.dart';
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
  final config = AppConfig.fromEnvironment(flavor: appFlavor);
  final auth = NeoAuthClient(
    NeoAuthConfig(
      issuer: config.issuer,
      clientId: config.clientId,
      deviceName: 'NeoAuth Console (${Platform.operatingSystem})',
    ),
  );
  // Load the stored session before the first frame, so the router starts in
  // the right place.
  try {
    await auth.restore();
  } catch (e) {
    // An unreadable keychain entry just means signing in again.
    debugPrint('neoauth_console: could not restore the session: $e');
  }

  runApp(
    ProviderScope(
      // Failed requests surface an error with a retry button instead of
      // being retried silently in the background.
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        neoAuthClientProvider.overrideWithValue(auth),
        stepUpHandlerProvider.overrideWith(createStepUpHandler),
      ],
      child: const NeoAuthConsoleApp(),
    ),
  );
}
