import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neokit_flavor_banner/neokit_flavor_banner.dart';

import 'core/auth/auth_providers.dart';
import 'core/router.dart';
import 'core/theme.dart';

class NeoAuthConsoleApp extends ConsumerWidget {
  const NeoAuthConsoleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      // The recent-apps label on Android; matches the launcher name.
      title: ref.watch(appConfigProvider).isProd ? 'NeoAuth Console' : 'NeoAuth Console Dev',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => FlavorBanner(flavor: appFlavor, child: child!),
    );
  }
}
