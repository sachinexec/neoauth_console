import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../shared/widgets/copy_field.dart';

/// Shown when `/admin/me` answers 403: signed in, but without a console role.
class NoAccessScreen extends ConsumerWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final who = user?.phoneNumber ?? user?.email;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_person_outlined, size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(
                      'Ask an owner to grant you access',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You are signed in${who != null ? ' as $who' : ''}, but this account has no console role yet. '
                    'Send your user ID to an owner; they can add you under Settings → Admins.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  if (user != null) CopyField(label: 'Your user ID', value: user.id),
                  const SizedBox(height: 24),
                  FilledButton.tonalIcon(
                    onPressed: () => ref.invalidate(meProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('I have been granted access'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => ref.read(neoAuthClientProvider).signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
