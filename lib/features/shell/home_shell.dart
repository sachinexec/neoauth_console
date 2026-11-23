import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/theme.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/instance_picker.dart';
import '../auth/no_access_screen.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The Billing branch, shown on the primary instance only.
const _billingBranch = 2;

const _destinations = [
  _Destination('Overview', Icons.dashboard_outlined, Icons.dashboard),
  _Destination('Apps', Icons.apps_outlined, Icons.apps),
  _Destination('Billing', Icons.payments_outlined, Icons.payments),
  _Destination('Users', Icons.people_outline, Icons.people),
  _Destination('Audit log', Icons.receipt_long_outlined, Icons.receipt_long),
  _Destination('Settings', Icons.settings_outlined, Icons.settings),
];

/// The signed-in frame: checks the console role, then shows a bottom
/// NavigationBar on phones and a NavigationRail on tablets. With more than one
/// instance configured, a banner on top names the active one.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) => InstanceBanner(child: _build(context, ref));

  Widget _build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    // Reloading for another instance or account: never show the last one's frame.
    if (!me.hasValue || me.isReloading) {
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

    final instance = ref.watch(activeInstanceProvider);
    final branches = [
      for (var i = 0; i < _destinations.length; i++)
        if (i != _billingBranch || ref.watch(billingAvailableProvider)) i,
    ];
    final selected = branches.indexOf(shell.currentIndex);
    final selectedIndex = selected < 0 ? 0 : selected;
    void go(int index) {
      final branch = branches[index];
      shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
    }

    // Keyed by instance, so no branch keeps a page (and its place) from another one.
    final body = KeyedSubtree(key: ValueKey(instance.id), child: shell);

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
                selectedIndex: selectedIndex,
                onDestinationSelected: go,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    semanticLabel: 'NeoAuth Console',
                  ),
                ),
                destinations: [
                  for (final d in branches.map((b) => _destinations[b]))
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: go,
        destinations: [
          for (final d in branches.map((b) => _destinations[b]))
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }
}
