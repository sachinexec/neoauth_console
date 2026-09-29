import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/format.dart';
import '../../core/router.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/copy_field.dart';
import '../../shared/widgets/dialogs.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to use the console.',
      confirmLabel: 'Sign out',
    );
    if (ok) await ref.read(neoAuthClientProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).value;
    final config = ref.watch(appConfigProvider);
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(roleProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageBody(
        children: [
          SectionCard(
            title: 'Signed in',
            trailing: StatusChip(label: role.label, tone: ChipTone.info, icon: Icons.shield_outlined),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoRow(label: 'Name', value: me?.name ?? '—'),
                InfoRow(label: 'Phone', value: me?.phone ?? '—'),
                InfoRow(label: 'Email', value: me?.email ?? '—'),
                InfoRow(label: 'Signed in', value: formatDateTime(me?.authTime)),
                if (user != null && user.methods.isNotEmpty) InfoRow(label: 'Method', value: user.methods.join(', ')),
                const SizedBox(height: 8),
                if (me?.userId != null) CopyField(label: 'User ID', value: me!.userId!, dense: true),
              ],
            ),
          ),
          if (role.isOwner)
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Admins'),
                    subtitle: const Text('Who can use the console, and their roles'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(Routes.admins),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.campaign_outlined),
                    title: const Text('Marketing audience'),
                    subtitle: const Text('Export users who opted in to hearing about our apps'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(Routes.audience),
                  ),
                ],
              ),
            ),
          SectionCard(
            title: 'Server',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CopyField(label: 'Issuer', value: config.issuer, dense: true),
                const SizedBox(height: 12),
                CopyField(label: 'Console client ID', value: config.clientId, dense: true),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _signOut(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
        ],
      ),
    );
  }
}
