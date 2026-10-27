import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/copy_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../billing_models.dart';
import '../billing_repository.dart';
import 'billing_widgets.dart';

/// Look up one user's purchases, and grant or revoke an entitlement by hand.
/// Needs the admin role: the server audits every lookup.
class BillingCustomersTab extends ConsumerStatefulWidget {
  const BillingCustomersTab({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<BillingCustomersTab> createState() => _BillingCustomersTabState();
}

class _BillingCustomersTabState extends ConsumerState<BillingCustomersTab> {
  final _sub = TextEditingController();
  final _form = GlobalKey<FormState>();
  AsyncValue<BillingCustomer>? _customer;
  String? _looking;

  @override
  void dispose() {
    _sub.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (!_form.currentState!.validate()) return;
    final sub = _sub.text.trim();
    await _load(sub);
  }

  Future<void> _load(String sub) async {
    setState(() {
      _looking = sub;
      _customer = const AsyncLoading();
    });
    try {
      final c = await ref.read(billingRepositoryProvider).customer(widget.slug, sub);
      if (mounted && _looking == sub) setState(() => _customer = AsyncData(c));
    } catch (e, st) {
      if (mounted && _looking == sub) setState(() => _customer = AsyncError(e, st));
    }
  }

  Future<void> _grant(BuildContext context, BillingCustomer c) async {
    final entitlements = await ref.read(billingEntitlementsProvider(widget.slug).future);
    if (!context.mounted) return;
    final input = await showDialog<({String entitlement, DateTime? expiresAt, String reason})>(
      context: context,
      builder: (_) => _GrantDialog(entitlements: entitlements),
    );
    if (input == null || !context.mounted) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Grant ${input.entitlement}?',
      message:
          'This gives ${shortId(c.sub, keep: 12)} the "${input.entitlement}" entitlement '
          '${input.expiresAt == null ? 'with no end date' : 'until ${formatDate(input.expiresAt)}'}. '
          'It is recorded in the audit log with your name and the reason, and you will be asked to confirm it is you.',
      confirmLabel: 'Grant',
    );
    if (!ok || !context.mounted) return;
    final grant = await runAction(
      context,
      () => ref
          .read(billingRepositoryProvider)
          .grant(widget.slug, c.sub, entitlement: input.entitlement, reason: input.reason, expiresAt: input.expiresAt),
      success: 'Granted',
    );
    if (grant != null) await _load(c.sub);
  }

  Future<void> _revoke(BuildContext context, BillingCustomer c, BillingGrant g) async {
    final reason = await showTextInputDialog(
      context,
      title: 'Revoke ${g.entitlement ?? 'grant'}?',
      label: 'Reason',
      message: 'The user loses this manual grant now. The reason is recorded in the audit log, and you will be asked to confirm it is you.',
      confirmLabel: 'Revoke',
      destructive: true,
      validator: (v) => v.length < 3 ? 'At least 3 characters' : null,
    );
    if (reason == null || !context.mounted) return;
    final revoked = await runAction(
      context,
      () => ref.read(billingRepositoryProvider).revokeGrant(widget.slug, g.id, reason: reason),
      success: 'Revoked',
    );
    if (revoked != null) await _load(c.sub);
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(billingRoleProvider);
    if (!role.canEdit) {
      return const NeedsRole(role: 'admins', what: 'look up customers');
    }
    final theme = Theme.of(context);
    final customer = _customer;
    return PageBody(
      children: [
        SectionCard(
          title: 'Find a customer',
          subtitle: 'By NeoAuth user ID. Every lookup is recorded in the audit log.',
          child: Form(
            key: _form,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('billing.customer.sub'),
                    controller: _sub,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'User ID', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => isBillingSub((v ?? '').trim()) ? null : 'Enter a user ID',
                    onFieldSubmitted: (_) => _lookup(),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FilledButton(onPressed: _lookup, child: const Text('Look up')),
                ),
              ],
            ),
          ),
        ),
        if (customer != null)
          AsyncValueView(
            value: customer,
            onRetry: _looking == null ? null : () => _load(_looking!),
            data: (c) => _CustomerView(
              customer: c,
              theme: theme,
              onGrant: () => _grant(context, c),
              onRevoke: (g) => _revoke(context, c, g),
            ),
          ),
      ],
    );
  }
}

class _CustomerView extends StatelessWidget {
  const _CustomerView({required this.customer, required this.theme, required this.onGrant, required this.onRevoke});
  final BillingCustomer customer;
  final ThemeData theme;
  final VoidCallback onGrant;
  final void Function(BillingGrant) onRevoke;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CopyField(label: 'User ID', value: c.sub, dense: true),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Entitlements now',
          child: c.entitlements.isEmpty
              ? const Text('Nothing active.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in c.entitlements)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lock_open),
                        title: Text(entitlementLabel(e)),
                        subtitle: Text(
                          e.expiresAt == null
                              ? 'No end date'
                              : 'Until ${formatDateTime(e.expiresAt)}${e.willRenew == false ? ' · will not renew' : ''}',
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Manual grants',
          trailing: FilledButton.icon(onPressed: onGrant, icon: const Icon(Icons.add), label: const Text('Grant')),
          child: c.grants.isEmpty
              ? const Text('None.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final g in c.grants)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(g.entitlement ?? 'grant'),
                        subtitle: Text(
                          [
                            g.isActive(now)
                                ? (g.expiresAt == null
                                      ? 'Active, no end date'
                                      : 'Active until ${formatDate(g.expiresAt)}')
                                : (g.revokedAt != null
                                      ? 'Revoked ${formatDate(g.revokedAt)}'
                                      : 'Ended ${formatDate(g.expiresAt)}'),
                            g.reason,
                            if (g.grantedBy != null) 'by ${g.grantedBy}',
                          ].join('\n'),
                        ),
                        isThreeLine: true,
                        trailing: g.isActive(now)
                            ? IconButton(
                                tooltip: 'Revoke grant',
                                icon: const Icon(Icons.block),
                                onPressed: () => onRevoke(g),
                              )
                            : null,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Subscriptions and purchases',
          child: c.subscriptions.isEmpty
              ? const Text('None.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final s in c.subscriptions) BillingSubscriptionTile(subscription: s)],
                ),
        ),
      ],
    );
  }
}

class BillingSubscriptionTile extends StatelessWidget {
  const BillingSubscriptionTile({super.key, required this.subscription});
  final BillingSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final s = subscription;
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Row(
        children: [
          Text(s.platform),
          const SizedBox(width: 8),
          subscriptionStateChip(s.state),
          if (s.isSandbox) ...[const SizedBox(width: 6), const StatusChip(label: 'sandbox', tone: ChipTone.warning)],
        ],
      ),
      subtitle: Text('${s.kind} · ${s.expiresAt == null ? 'no end' : 'ends ${formatDateTime(s.expiresAt)}'}'),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow(label: 'Store key', value: s.storeKey, monospace: true),
        InfoRow(label: 'Auto-renew', value: s.autoRenew ? 'on' : 'off'),
        InfoRow(label: 'Period start', value: formatDateTime(s.periodStart)),
        if (s.graceExpiresAt != null) InfoRow(label: 'Grace until', value: formatDateTime(s.graceExpiresAt)),
        if (s.revokedAt != null)
          InfoRow(label: 'Revoked', value: '${formatDateTime(s.revokedAt)} (${s.revokeReason ?? 'unknown'})'),
        InfoRow(label: 'Last event', value: formatDateTime(s.lastEventAt)),
        InfoRow(label: 'Last synced', value: formatDateTime(s.lastSyncedAt)),
        if (s.ackPending)
          Text('Waiting for the store acknowledgement.', style: TextStyle(color: theme.colorScheme.error)),
        if (s.erased) const Text('The account was deleted; this is kept as an accounting record.'),
      ],
    );
  }
}

class _GrantDialog extends StatefulWidget {
  const _GrantDialog({required this.entitlements});
  final List<BillingEntitlement> entitlements;

  @override
  State<_GrantDialog> createState() => _GrantDialogState();
}

class _GrantDialogState extends State<_GrantDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  String? _key;
  DateTime? _expires;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expires ?? now.add(const Duration(days: 30)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _expires = DateTime(picked.year, picked.month, picked.day, 23, 59));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Grant an entitlement'),
      // bottom-inset-ok: dialog content, not the bottom edge of the window
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('grant.entitlement'),
                initialValue: _key,
                decoration: const InputDecoration(labelText: 'Entitlement'),
                items: [
                  for (final e in widget.entitlements)
                    DropdownMenuItem(value: e.key, child: Text('${e.name} (${e.key})')),
                ],
                onChanged: (v) => setState(() => _key = v),
                validator: (v) => v == null ? 'Choose one' : null,
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Ends', contentPadding: EdgeInsets.fromLTRB(12, 4, 4, 4)),
                child: Row(
                  children: [
                    Expanded(child: Text(_expires == null ? 'Never' : formatDate(_expires))),
                    TextButton(onPressed: _pickDate, child: const Text('Pick date')),
                    if (_expires != null)
                      IconButton(
                        tooltip: 'No end date',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _expires = null),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('grant.reason'),
                controller: _reason,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Reason', helperText: 'Recorded in the audit log.'),
                validator: (v) => (v ?? '').trim().length < 3 ? 'At least 3 characters' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.of(context).pop((entitlement: _key!, expiresAt: _expires, reason: _reason.text.trim()));
            }
          },
          child: const Text('Review'),
        ),
      ],
    );
  }
}
