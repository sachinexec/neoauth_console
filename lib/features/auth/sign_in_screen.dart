import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import 'sign_in_form.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final issuer = ref.watch(appConfigProvider).issuer;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text('NeoAuth Console', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to manage apps, clients and users.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  // Navigation happens in the router once the SDK reports the session.
                  SignInForm(onSignedIn: (_) {}),
                  const SizedBox(height: 32),
                  Text(
                    issuer,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
