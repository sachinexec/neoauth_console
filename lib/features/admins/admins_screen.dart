import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/format.dart';
import '../../core/router.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/dialogs.dart';
import '../auth/admin_me.dart';
import 'admins.dart';

/// Owner-only: who can use the console, and with which role.
class AdminsScreen extends ConsumerWidget {
  const AdminsScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<(String, AdminRole)>(context: context, builder: (_) => const _AddAdminDialog());
    if (result == null || !context.mounted) return;
    final list = await runAction(
      context,
      () => ref.read(adminsRepositoryProvider).setRole(result.$1, result.$2),
      success: '${result.$2.label} role granted',
    );
    if (list != null) ref.invalidate(adminsProvider);
  }

  Future<void> _changeRole(BuildContext context, WidgetRef ref, AdminEntry a, AdminRole role) async {
    if (role == a.role) return;
    final list = await runAction(
      context,
      () => ref.read(adminsRepositoryProvider).setRole(a.userId, role),
      success: '${a.displayName} is now ${role.label.toLowerCase()}',
    );
    if (list != null) {
      ref.invalidate(adminsProvider);
      ref.invalidate(meProvider);
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, AdminEntry a, {required bool self}) async {
    final ok = await showConfirmDialog(
      context,
      title: self ? 'Remove your own access?' : 'Remove ${a.displayName}?',
      message: self
          ? 'You will lose access to the console immediately.'
          : 'They will lose access to the console. Their account is not affected.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final list = await runAction(
      context,
      () => ref.read(adminsRepositoryProvider).remove(a.userId),
      success: 'Access removed',
    );
    if (list != null) {
      ref.invalidate(adminsProvider);
      if (self) ref.invalidate(meProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    final me = ref.watch(meProvider).value;
    final admins = ref.watch(adminsProvider);
    if (!role.isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admins')),
        body: const EmptyView(
          title: 'Owners only',
          message: 'Only owners can manage who has access to the console.',
          icon: Icons.lock_outline,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Admins')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add admin'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(adminsProvider.future),
        child: AsyncValueView(
          value: admins,
          onRetry: () => ref.invalidate(adminsProvider),
          data: (list) => PageBody(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              const _RolesHelp(),
              for (final a in list)
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    leading: const CircleAvatar(child: Icon(Icons.shield_outlined)),
                    title: Text(a.userId == me?.userId ? '${a.displayName} (you)' : a.displayName),
                    subtitle: Text('Since ${formatDate(a.createdAt)}'),
                    onTap: () => context.go(Routes.user(a.userId)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButton<AdminRole>(
                          value: a.role,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final r in AdminRole.values.reversed) DropdownMenuItem(value: r, child: Text(r.label)),
                          ],
                          onChanged: (r) => r == null ? null : _changeRole(context, ref, a, r),
                        ),
                        IconButton(
                          tooltip: 'Remove ${a.displayName}',
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: () => _remove(context, ref, a, self: a.userId == me?.userId),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolesHelp extends StatelessWidget {
  const _RolesHelp();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Viewer: read-only. Admin: manage apps, clients and users. '
      'Owner: also manage admins and export the marketing audience. There must always be one owner.',
      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

class _AddAdminDialog extends StatefulWidget {
  const _AddAdminDialog();

  @override
  State<_AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<_AddAdminDialog> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  AdminRole _role = AdminRole.viewer;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add admin'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('They must have signed in once. Ask them for the user ID shown on their "no access" screen.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _id,
              autofocus: true,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'User ID'),
              validator: (v) => uuidPattern.hasMatch((v ?? '').trim()) ? null : 'Enter a user ID (UUID)',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AdminRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [for (final r in AdminRole.values.reversed) DropdownMenuItem(value: r, child: Text(r.label))],
              onChanged: (r) => setState(() => _role = r ?? _role),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) Navigator.of(context).pop((_id.text.trim().toLowerCase(), _role));
          },
          child: const Text('Grant'),
        ),
      ],
    );
  }
}
