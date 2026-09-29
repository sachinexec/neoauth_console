import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/copy_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../apps_repository.dart';
import '../models/app_models.dart';
import '../widgets/attestation_editor.dart';
import '../widgets/client_methods_section.dart';
import '../widgets/login_methods_editor.dart';
import '../widgets/client_settings_section.dart';
import '../widgets/token_policy_editor.dart';

class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.slug, required this.clientId});
  final String slug;
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientDetailProvider(clientId));
    final app = ref.watch(appDetailProvider(slug));
    return Scaffold(
      appBar: AppBar(
        title: Text(client.value?.name ?? 'Client'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(clientDetailProvider(clientId));
              ref.invalidate(appDetailProvider(slug));
            },
          ),
        ],
      ),
      body: AsyncValueView(
        value: client,
        onRetry: () => ref.invalidate(clientDetailProvider(clientId)),
        data: (c) => _ClientBody(client: c, app: app.value),
      ),
    );
  }
}

class _ClientBody extends ConsumerWidget {
  const _ClientBody({required this.client, required this.app});
  final ClientModel client;
  final AppModel? app;

  Future<void> _rotate(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Rotate client secret?',
      message:
          'A new secret is issued and the current one stops working immediately. '
          'Update your server with the new secret right away, or its sign-ins will fail.',
      confirmLabel: 'Rotate secret',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final secret = await runAction(context, () => ref.read(appsRepositoryProvider).rotateSecret(client.clientId));
    if (secret == null || !context.mounted) return;
    await showSecretDialog(
      context,
      title: 'New client secret',
      label: 'Client secret',
      secret: secret,
      extra: [('Client ID', client.clientId)],
    );
  }

  Future<void> _toggleStatus(BuildContext context, WidgetRef ref, bool active) async {
    if (!active) {
      final ok = await showConfirmDialog(
        context,
        title: 'Disable ${client.name}?',
        message: 'Nobody can sign in with this client until it is enabled again.',
        confirmLabel: 'Disable',
        destructive: true,
      );
      if (!ok || !context.mounted) return;
    }
    final updated = await runAction(
      context,
      () => ref.read(appsRepositoryProvider).updateClient(client.clientId, {'status': active ? 'active' : 'disabled'}),
      success: active ? 'Client enabled' : 'Client disabled',
    );
    if (updated != null) refreshClient(ref, updated);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = client;
    final canEdit = ref.watch(roleProvider).canEdit;
    final isConsoleClient = app?.isConsole ?? false;
    final theme = Theme.of(context);

    return PageBody(
      children: [
        if (!canEdit) const ReadOnlyBanner(),
        SectionCard(
          title: 'Overview',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CopyField(label: 'Client ID', value: c.clientId, dense: true),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusChip.status(c.status),
                  StatusChip(label: c.applicationType.label),
                  StatusChip(label: c.clientType.label),
                  StatusChip(
                    label: c.firstParty ? 'First-party' : 'Third-party',
                    tone: c.firstParty ? ChipTone.neutral : ChipTone.info,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InfoRow(
                label: 'User IDs',
                value: c.subjectType == 'pairwise' ? 'Pairwise (per client)' : 'Public (shared)',
              ),
              if (c.sectorIdentifierUri != null) InfoRow(label: 'Sector identifier', value: c.sectorIdentifierUri!),
              InfoRow(label: 'Created', value: formatDateTime(c.createdAt)),
            ],
          ),
        ),
        SectionCard(
          title: 'Effective settings',
          subtitle: 'What this client actually gets after app settings, overrides and server support.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Web sign-in page', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              MethodChips(methods: c.effectiveLoginMethods.web, emptyLabel: 'No method available'),
              const SizedBox(height: 12),
              Text('Native (SDK)', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              c.nativeLogin
                  ? MethodChips(methods: c.effectiveLoginMethods.native, emptyLabel: 'No method available')
                  : Text('Native sign-in is off for this client', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text('Token policy', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(c.effectiveTokenPolicy.summary),
            ],
          ),
        ),
        ClientSettingsSection(client: c, enabled: canEdit),
        ClientMethodsSection(client: c, app: app, enabled: canEdit),
        SectionCard(
          title: 'Token policy override',
          subtitle: 'Override single fields of the app policy for this client. Unset fields follow the app.',
          child: app == null
              ? const LoadingView()
              : TokenPolicyEditor(
                  initial: c.tokenPolicyOverride,
                  inherited: app!.resolvedPolicy,
                  clientType: c.clientType,
                  allowInherit: true,
                  enabled: canEdit,
                  onSave: (override) async {
                    final updated = await runAction(
                      context,
                      () => ref.read(appsRepositoryProvider).setClientTokenPolicy(c.clientId, override),
                      success: 'Token policy saved',
                    );
                    if (updated != null) refreshClient(ref, updated);
                    return updated != null;
                  },
                ),
        ),
        AttestationEditor(client: c, enabled: canEdit),
        if (canEdit)
          SectionCard(
            title: 'Manage',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (c.clientType == ClientType.confidential)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.autorenew),
                    title: const Text('Rotate client secret'),
                    subtitle: const Text('Issue a new secret. The old one stops working at once.'),
                    trailing: OutlinedButton(onPressed: () => _rotate(context, ref), child: const Text('Rotate')),
                  ),
                MergeSemantics(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.isActive ? 'Enabled' : 'Disabled'),
                    subtitle: Text(
                      isConsoleClient
                          ? 'Careful: disabling a console client can lock admins out.'
                          : 'Disabled clients cannot sign anyone in.',
                    ),
                    value: c.isActive,
                    onChanged: (v) => _toggleStatus(context, ref, v),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
