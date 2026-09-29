import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';

class NeoAuthConsoleApp extends ConsumerWidget {
  const NeoAuthConsoleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'NeoAuth Console',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
