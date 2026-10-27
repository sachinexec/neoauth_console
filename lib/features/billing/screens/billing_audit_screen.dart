import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/router.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../billing_models.dart';
import '../billing_repository.dart';
import '../widgets/billing_events_tab.dart' show prettyJson;
import '../widgets/billing_widgets.dart';

/// What admins did in billing, and customer lookups. Admin role and up.
class BillingAuditScreen extends ConsumerWidget {
  const BillingAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(billingRoleProvider);
    if (!role.canEdit) {
      return Scaffold(
        appBar: AppBar(title: const Text('Billing audit log')),
        body: const NeedsRole(role: 'admins', what: 'read the audit log'),
      );
    }
    final apps = ref.watch(billingAppsProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing audit log'),
        leading: IconButton(icon: const BackButtonIcon(), tooltip: 'Back', onPressed: () => context.go(Routes.billing)),
      ),
      body: PagedListView<BillingAuditEvent>(
        provider: billingAuditProvider,
        onRefresh: () => ref.read(billingAuditProvider.notifier).refresh(),
        onLoadMore: () => ref.read(billingAuditProvider.notifier).loadMore(),
        empty: const EmptyView(title: 'No events yet', icon: Icons.receipt_long_outlined),
        itemBuilder: (context, e) =>
            _AuditTile(event: e, appName: apps?.where((a) => a.id == e.appId).firstOrNull?.name),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.event, this.appName});
  final BillingAuditEvent event;
  final String? appName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = event;
    return ExpansionTile(
      leading: Icon(e.event.startsWith('admin.') ? Icons.shield_outlined : Icons.bolt_outlined),
      title: Text(e.event, style: const TextStyle(fontFamily: 'monospace')),
      subtitle: Text(
        [formatDateTime(e.at), ?appName, ?e.actor].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (e.actor != null) SelectableText('Actor ${e.actor}', style: theme.textTheme.bodySmall),
        if (e.userSub != null) SelectableText('User ${e.userSub}', style: theme.textTheme.bodySmall),
        if (e.data.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              prettyJson(e.data),
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ],
    );
  }
}
