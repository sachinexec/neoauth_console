import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/dialogs.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../billing_models.dart';
import '../billing_repository.dart';
import 'billing_customers_tab.dart' show BillingSubscriptionTile;
import 'billing_widgets.dart';

enum _View { events, subscriptions }

/// Stored store events (with replay) and the app's subscriptions.
class BillingEventsTab extends ConsumerStatefulWidget {
  const BillingEventsTab({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<BillingEventsTab> createState() => _BillingEventsTabState();
}

class _BillingEventsTabState extends ConsumerState<BillingEventsTab> {
  _View _view = _View.events;
  String? _status;
  String? _state;

  @override
  Widget build(BuildContext context) {
    final events = _view == _View.events;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<_View>(
                segments: const [
                  ButtonSegment(value: _View.events, label: Text('Events'), icon: Icon(Icons.swap_vert)),
                  ButtonSegment(value: _View.subscriptions, label: Text('Subscriptions'), icon: Icon(Icons.autorenew)),
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
              ),
              if (events)
                DropdownButton<String?>(
                  key: const Key('billing.events.status'),
                  value: _status,
                  hint: const Text('Any status'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Any status')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                    DropdownMenuItem(value: 'received', child: Text('Received')),
                    DropdownMenuItem(value: 'processed', child: Text('Processed')),
                    DropdownMenuItem(value: 'ignored', child: Text('Ignored')),
                  ],
                  onChanged: (v) => setState(() => _status = v),
                )
              else
                DropdownButton<String?>(
                  key: const Key('billing.subs.state'),
                  value: _state,
                  hint: const Text('Any state'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Any state')),
                    for (final s in const [
                      'active',
                      'trial',
                      'grace',
                      'billing_retry',
                      'paused',
                      'pending',
                      'expired',
                      'revoked',
                    ])
                      DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' '))),
                  ],
                  onChanged: (v) => setState(() => _state = v),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: events ? _EventsList(slug: widget.slug, status: _status) : _SubsList(slug: widget.slug, state: _state),
        ),
      ],
    );
  }
}

class _EventsList extends ConsumerWidget {
  const _EventsList({required this.slug, required this.status});
  final String slug;
  final String? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = billingEventsProvider((slug: slug, status: status, storeKey: null));
    return PagedListView<BillingStoreEvent>(
      provider: provider,
      onRefresh: () => ref.read(provider.notifier).refresh(),
      onLoadMore: () => ref.read(provider.notifier).loadMore(),
      empty: const EmptyView(title: 'No events', icon: Icons.swap_vert),
      itemBuilder: (context, e) =>
          _EventTile(slug: slug, event: e, onReplayed: () => ref.read(provider.notifier).refresh()),
    );
  }
}

class _SubsList extends ConsumerWidget {
  const _SubsList({required this.slug, required this.state});
  final String slug;
  final String? state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = billingSubscriptionsProvider((slug: slug, state: state));
    return PagedListView<BillingSubscription>(
      provider: provider,
      onRefresh: () => ref.read(provider.notifier).refresh(),
      onLoadMore: () => ref.read(provider.notifier).loadMore(),
      empty: const EmptyView(title: 'No subscriptions', icon: Icons.autorenew),
      itemBuilder: (context, s) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: BillingSubscriptionTile(subscription: s),
      ),
    );
  }
}

class _EventTile extends ConsumerWidget {
  const _EventTile({required this.slug, required this.event, required this.onReplayed});
  final String slug;
  final BillingStoreEvent event;
  final VoidCallback onReplayed;

  Future<void> _replay(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Replay this event?',
      message:
          'The stored ${event.platform} notification is processed again and may change a subscription and the entitlements of its owner. '
          'It is recorded in the audit log, and you will be asked to confirm it is you.',
      confirmLabel: 'Replay',
    );
    if (!ok || !context.mounted) return;
    final result = await runAction(context, () => ref.read(billingRepositoryProvider).replayEvent(slug, event.id));
    if (result == null || !context.mounted) return;
    showSnack(context, 'Replayed: $result');
    onReplayed();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = event;
    final canEdit = ref.watch(billingRoleProvider).canEdit;
    final theme = Theme.of(context);
    return ExpansionTile(
      leading: Icon(e.platform == 'apple' ? Icons.apple : Icons.android),
      title: Text(
        [e.eventType, if (e.subtype != null) e.subtype!].join(' · '),
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      subtitle: Row(
        children: [
          eventStatusChip(e.status),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${e.source} · ${formatDateTime(e.receivedAt)}', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(label: 'Event ID', value: e.storeEventId ?? '—', monospace: true),
        if (e.storeKey != null) InfoRow(label: 'Store key', value: e.storeKey!, monospace: true),
        InfoRow(label: 'Event time', value: formatDateTime(e.eventTime)),
        InfoRow(label: 'Attempts', value: '${e.attempts}'),
        if (e.outcome != null) InfoRow(label: 'Outcome', value: e.outcome!),
        if (e.error != null) Text(e.error!, style: TextStyle(color: theme.colorScheme.error)),
        if (canEdit && e.canReplay) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: e.hasPayload ? () => _replay(context, ref) : null,
              icon: const Icon(Icons.replay),
              label: Text(e.hasPayload ? 'Replay' : 'Payload erased'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Pretty JSON for audit data.
String prettyJson(Object? value) => const JsonEncoder.withIndent('  ').convert(value);
