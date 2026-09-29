import 'package:neoauth/neoauth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/router.dart';
import 'sign_in_form.dart';

/// Shows the re-authenticate sheet. Resolves to the signed-in user, or null
/// when dismissed. Signing in replaces the SDK session with a fresh one, so
/// the retried request carries a token with a new `auth_time`.
Future<NeoAuthUser?> showStepUpSheet(BuildContext context, {String? phone, String? email}) {
  return showModalBottomSheet<NeoAuthUser>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(header: true, child: Text("Confirm it's you", style: theme.textTheme.headlineSmall)),
                  const SizedBox(height: 8),
                  Text(
                    'This action needs a sign-in from the last 15 minutes. Sign in again and it will continue automatically.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  SignInForm(
                    initialPhone: phone,
                    initialEmail: phone == null ? email : null,
                    submitLabel: 'Confirm',
                    onSignedIn: (user) => Navigator.of(context).pop(user),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// The [StepUpHandler] the API client calls on `step_up_required`.
StepUpHandler createStepUpHandler(Ref ref) => () async {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return false;
  final before = ref.read(neoAuthClientProvider).currentUser?.id;
  final me = ref.read(meProvider).value;
  final user = await showStepUpSheet(context, phone: me?.phone, email: me?.email);
  if (user == null) return false;
  if (user.id != before) {
    // A different account signed in: never replay the action as them.
    final messenger = rootScaffoldMessengerKey.currentState;
    messenger?.showSnackBar(
      const SnackBar(content: Text('You signed in with a different account, so the action was not repeated.')),
    );
    return false;
  }
  ref.invalidate(meProvider);
  return true;
};
