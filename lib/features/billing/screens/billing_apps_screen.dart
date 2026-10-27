import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/router.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/common.dart';
import '../../../ui/bottom_inset.dart';
import '../../apps/screens/apps_screen.dart' show AppAvatar;
import '../billing_models.dart';
import '../billing_repository.dart';
import '../widgets/billing_widgets.dart';

/// Billing apps: what is sold, per app, and the stores it is sold in.
class BillingAppsScreen extends ConsumerWidget {
  const BillingAppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    if (!config.billingConfigured) {
      return Scaffold(
        appBar: AppBar(title: const Text('Billing')),
        body: const EmptyView(
          title: 'Billing is not set up',
          message:
              'Set BILLING_URL in this environment\'s config to the billing service (https). '
              'See the README.',
          icon: Icons.payments_outlined,
        ),
      );
    }
    final me = ref.watch(billingMeProvider);
    final role = ref.watch(billingRoleProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing'),
        actions: [
          if (role.canEdit)
            IconButton(
              tooltip: 'Billing audit log',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => context.go(Routes.billingAudit),
            ),
        ],
      ),
      floatingActionButton: role.isOwner
          ? FloatingActionButton.extended(
              onPressed: () => context.go(Routes.newBillingApp),
              icon: const Icon(Icons.add),
              label: const Text('New app'),
            )
          : null,
      body: !me.hasValue ? _gate(context, ref, me) : const _AppsList(),
    );
  }

  Widget _gate(BuildContext context, WidgetRef ref, AsyncValue<BillingMe> me) {
    final error = me.error;
    if (error is ApiException && error.isForbidden) {
      return EmptyView(
        title: 'No billing access',
        message: 'Your account has no billing role. Ask a billing owner to add your user ID.',
        icon: Icons.lock_outline,
        action: ref.watch(currentUserIdProvider) == null
            ? null
            : SelectableText(ref.watch(currentUserIdProvider)!, style: const TextStyle(fontFamily: 'monospace')),
      );
    }
    if (error != null) return ErrorView(error: error, onRetry: () => ref.invalidate(billingMeProvider));
    return const LoadingView();
  }
}

/// Only built once the caller's billing role is known, so a caller with none
/// never triggers the list request.
class _AppsList extends ConsumerWidget {
  const _AppsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(billingAppsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(billingAppsProvider.future),
      child: AsyncValueView(
        value: apps,
        onRetry: () => ref.invalidate(billingAppsProvider),
        isEmpty: (a) => a.isEmpty,
        empty: const EmptyView(
          title: 'No billing apps yet',
          message: 'Register an app, then its store credentials, products and entitlements.',
          icon: Icons.payments_outlined,
        ),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96).safeBottom(context),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: BillingAppTile(app: list[i]),
            ),
          ),
        ),
      ),
    );
  }
}

class BillingAppTile extends StatelessWidget {
  const BillingAppTile({super.key, required this.app});
  final BillingApp app;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: AppAvatar(name: app.name),
        title: Text(app.name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusChip.status(app.status),
              credentialChip('Apple', app.apple.configured, sandbox: app.apple.allowSandbox),
              credentialChip('Google', app.google.configured, sandbox: app.google.allowSandbox),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(Routes.billingApp(app.slug)),
      ),
    );
  }
}
