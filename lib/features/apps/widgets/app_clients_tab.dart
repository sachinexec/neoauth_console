import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/common.dart';
import '../models/app_models.dart';

class AppClientsTab extends ConsumerWidget {
  const AppClientsTab({super.key, required this.app});
  final AppModel app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (app.clients.isEmpty) {
      return EmptyView(
        title: 'No clients yet',
        message: 'Add a client for each website or mobile app that signs users in to ${app.name}.',
        icon: Icons.key_outlined,
      );
    }
    return PageBody(
      children: [
        for (final c in app.clients)
          ClientTile(client: c, onTap: () => context.push(Routes.client(app.slug, c.clientId))),
      ],
    );
  }
}

class ClientTile extends StatelessWidget {
  const ClientTile({super.key, required this.client, this.onTap});
  final ClientModel client;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = client;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                c.applicationType == ApplicationType.native ? Icons.phone_iphone : Icons.language,
                color: theme.colorScheme.primary,
                semanticLabel: c.applicationType.label,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      c.clientId,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusChip.status(c.status),
                        StatusChip(label: c.clientType.label),
                        StatusChip(
                          label: c.firstParty ? 'First-party' : 'Third-party',
                          tone: c.firstParty ? ChipTone.neutral : ChipTone.info,
                        ),
                        if (c.nativeLogin) const StatusChip(label: 'Native sign-in', tone: ChipTone.info),
                        if (c.loginMethods != null) const StatusChip(label: 'Custom methods'),
                        if (!c.tokenPolicyOverride.isEmpty) const StatusChip(label: 'Custom policy'),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
