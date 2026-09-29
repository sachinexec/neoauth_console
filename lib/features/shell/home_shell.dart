import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/async_value_view.dart';
import '../auth/no_access_screen.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Overview', Icons.dashboard_outlined, Icons.dashboard),
  _Destination('Apps', Icons.apps_outlined, Icons.apps),
  _Destination('Users', Icons.people_outline, Icons.people),
  _Destination('Audit log', Icons.receipt_long_outlined, Icons.receipt_long),
  _Destination('Settings', Icons.settings_outlined, Icons.settings),
];

/// The signed-in frame: checks the console role, then shows a bottom
/// NavigationBar on phones and a NavigationRail on tablets.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  void _go(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    if (!me.hasValue) {
      final error = me.error;
      if (error is ApiException && error.isForbidden) return const NoAccessScreen();
      if (error != null) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ErrorView(error: error, onRetry: () => ref.invalidate(meProvider)),
                ),
                TextButton.icon(
                  onPressed: () => ref.read(neoAuthClientProvider).signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      }
      return const Scaffold(body: LoadingView(label: 'Loading your account'));
    }

    if (Breakpoints.useRail(context)) {
      final extended = MediaQuery.sizeOf(context).width >= Breakpoints.extendedRail;
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                extended: extended,
                labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                selectedIndex: shell.currentIndex,
                onDestinationSelected: _go,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    semanticLabel: 'NeoAuth Console',
                  ),
                ),
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }
}
