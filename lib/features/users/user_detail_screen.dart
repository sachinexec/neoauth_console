import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/format.dart';
import '../../core/router.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/copy_field.dart';
import '../../shared/widgets/dialogs.dart';
import 'users.dart';

class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDetailProvider(userId));
    return Scaffold(
      appBar: AppBar(
        title: Text(user.value?.displayName ?? 'User'),
        actions: [
          IconButton(
            tooltip: 'Audit log for this user',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.go(Routes.auditFor(userId: userId)),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(userDetailProvider(userId)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(userDetailProvider(userId).future),
        child: AsyncValueView(
          value: user,
          onRetry: () => ref.invalidate(userDetailProvider(userId)),
          data: (u) => _UserBody(user: u),
        ),
      ),
    );
  }
}

class _UserBody extends ConsumerWidget {
  const _UserBody({required this.user});
  final UserDetail user;

  UsersRepository _repo(WidgetRef ref) => ref.read(usersRepositoryProvider);

  void _refresh(WidgetRef ref) {
    ref.invalidate(userDetailProvider(user.id));
    ref.invalidate(userSearchProvider);
  }

  Future<void> _suspend(BuildContext context, WidgetRef ref) async {
    final reason = await showTextInputDialog(
      context,
      title: 'Suspend ${user.displayName}?',
      message: 'They are signed out everywhere and cannot sign in to any app until unsuspended. Apps are notified.',
      label: 'Reason',
      confirmLabel: 'Suspend',
      destructive: true,
    );
    if (reason == null || !context.mounted) return;
    final ok = await runAction(context, () async {
      await _repo(ref).suspend(user.id, reason);
      return true;
    }, success: 'User suspended');
    if (ok == true) _refresh(ref);
  }

  Future<void> _unsuspend(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Unsuspend ${user.displayName}?',
      message: 'They will be able to sign in again.',
      confirmLabel: 'Unsuspend',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await runAction(context, () async {
      await _repo(ref).unsuspend(user.id);
      return true;
    }, success: 'User unsuspended');
    if (ok == true) _refresh(ref);
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, UserSession s) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sign out this session?',
      message:
          '${s.appName ?? s.clientName ?? s.clientId} on ${s.deviceName ?? s.platform ?? 'an unknown device'} will be signed out.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final ok = await runAction(context, () async {
      await _repo(ref).revokeSession(user.id, s.grantId);
      return true;
    }, success: 'Session signed out');
    if (ok == true) _refresh(ref);
  }

  Future<void> _revokeAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sign out everywhere?',
      message: 'All ${user.sessions.length} sessions of ${user.displayName} end now, in every app.',
      confirmLabel: 'Sign out all',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final n = await runAction(context, () => _repo(ref).revokeAllSessions(user.id));
    if (n == null || !context.mounted) return;
    showSnack(context, n == 1 ? '1 session signed out' : '$n sessions signed out');
    _refresh(ref);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this account?',
      message:
          '${user.displayName} is signed out everywhere and their account is scheduled for erasure in every app. '
          'This cannot be undone.',
      confirmLabel: 'Delete account',
      destructive: true,
      typedConfirmation: 'DELETE',
    );
    if (!confirmed || !context.mounted) return;
    final result = await runAction(context, () async => (await _repo(ref).delete(user.id),));
    if (result == null || !context.mounted) return;
    final eraseAfter = result.$1;
    showSnack(
      context,
      eraseAfter == null ? 'Account deleted' : 'Account deleted. Data is erased after ${formatDate(eraseAfter)}.',
    );
    _refresh(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final u = user;
    final me = ref.watch(meProvider).value;
    final canEdit = ref.watch(roleProvider).canEdit;
    final isSelf = me?.userId == u.id;
    final deleted = u.status == 'deleted' || u.deletionScheduledAt != null;

    return PageBody(
      children: [
        SectionCard(
          title: 'Account',
          trailing: Wrap(
            spacing: 6,
            children: [
              if (u.adminRole != null)
                StatusChip(label: u.adminRole!.label, tone: ChipTone.info, icon: Icons.shield_outlined),
              StatusChip.status(u.status),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CopyField(label: 'User ID', value: u.id, dense: true),
              const SizedBox(height: 8),
              InfoRow(label: 'Name', value: u.name ?? '—'),
              InfoRow(
                label: 'Phone',
                value: u.phone == null ? '—' : '${u.phone}${u.phoneVerifiedAt != null ? ' (verified)' : ''}',
              ),
              InfoRow(
                label: 'Email',
                value: u.primaryEmail == null
                    ? '—'
                    : '${u.primaryEmail}${u.emailVerifiedAt != null ? ' (verified)' : ''}',
              ),
              InfoRow(label: 'Joined', value: formatDateTime(u.createdAt)),
              InfoRow(label: 'Updated', value: formatDateTime(u.updatedAt)),
              if (u.deletionScheduledAt != null)
                InfoRow(label: 'Erasure', value: 'Scheduled for ${formatDateTime(u.deletionScheduledAt)}'),
            ],
          ),
        ),
        SectionCard(
          title: 'Sign-in methods',
          child: u.identities.isEmpty
              ? const Text('None')
              : Column(
                  children: [
                    for (final i in u.identities)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_providerIcon(i.provider)),
                        title: Text(_providerLabel(i.provider)),
                        subtitle: Text(
                          [
                            ?(i.phone ?? i.email),
                            'Added ${formatDate(i.createdAt)}',
                            'Last used ${formatRelative(i.lastUsedAt)}',
                          ].join(' · '),
                        ),
                      ),
                  ],
                ),
        ),
        SectionCard(
          title: 'Apps used',
          child: u.apps.isEmpty
              ? const Text('None yet')
              : Column(
                  children: [
                    for (final a in u.apps)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(a.name),
                        subtitle: Text(
                          'First ${formatDate(a.firstSeenAt)} · last ${formatRelative(a.lastSeenAt)}'
                          '${a.signupSource != null ? ' · via ${a.signupSource}' : ''}',
                        ),
                        onTap: () => context.go(Routes.app(a.slug)),
                      ),
                  ],
                ),
        ),
        SectionCard(
          title: 'Passkeys',
          child: u.passkeys.isEmpty
              ? const Text('None')
              : Column(
                  children: [
                    for (final p in u.passkeys)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.fingerprint),
                        title: Text(p.name ?? 'Passkey'),
                        subtitle: Text(
                          [
                            if (p.deviceType != null) p.deviceType == 'multiDevice' ? 'Synced' : 'This device only',
                            if (p.backedUp) 'backed up',
                            'last used ${formatRelative(p.lastUsedAt)}',
                          ].join(' · '),
                        ),
                      ),
                  ],
                ),
        ),
        SectionCard(
          title: 'Active sessions',
          subtitle: '${u.sessions.length} signed-in ${u.sessions.length == 1 ? 'device' : 'devices'}',
          trailing: canEdit && u.sessions.isNotEmpty
              ? TextButton(onPressed: () => _revokeAll(context, ref), child: const Text('Sign out all'))
              : null,
          child: u.sessions.isEmpty
              ? const Text('No active sessions')
              : Column(
                  children: [
                    for (final s in u.sessions)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          s.platform == 'ios' || s.platform == 'android' ? Icons.phone_iphone : Icons.computer,
                        ),
                        title: Text('${s.appName ?? s.appSlug ?? 'App'} · ${s.deviceName ?? s.platform ?? 'Browser'}'),
                        subtitle: Text(
                          [
                            s.clientName ?? s.clientId,
                            if (s.loginMethod != null) 'via ${s.loginMethod}',
                            'active ${formatRelative(s.lastUsedAt)}',
                            if (s.ip != null && s.ip!.isNotEmpty) s.ip!,
                          ].join(' · '),
                        ),
                        trailing: canEdit
                            ? IconButton(
                                tooltip: 'Sign out this session',
                                icon: const Icon(Icons.logout),
                                onPressed: () => _revoke(context, ref, s),
                              )
                            : null,
                      ),
                  ],
                ),
        ),
        if (canEdit && !isSelf && !deleted)
          SectionCard(
            title: 'Manage',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (u.isSuspended)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_open),
                    title: const Text('Unsuspend'),
                    subtitle: const Text('Let them sign in again.'),
                    trailing: OutlinedButton(onPressed: () => _unsuspend(context, ref), child: const Text('Unsuspend')),
                  )
                else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.block),
                    title: const Text('Suspend'),
                    subtitle: const Text('Sign them out everywhere and block sign-in.'),
                    trailing: OutlinedButton(onPressed: () => _suspend(context, ref), child: const Text('Suspend')),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
                  title: const Text('Delete account'),
                  subtitle: const Text('Remove the account from every app.'),
                  trailing: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    onPressed: () => _delete(context, ref),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ),
        if (isSelf)
          Text(
            'This is you. Manage your own account from the account centre.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  static IconData _providerIcon(String p) => switch (p) {
    'phone' => Icons.sms_outlined,
    'email' => Icons.alternate_email,
    'google' => Icons.g_mobiledata,
    'apple' => Icons.apple,
    'passkey' => Icons.fingerprint,
    _ => Icons.link,
  };

  static String _providerLabel(String p) => switch (p) {
    'phone' => 'Phone',
    'email' => 'Email',
    'google' => 'Google',
    'apple' => 'Apple',
    'passkey' => 'Passkey',
    _ => p,
  };
}
