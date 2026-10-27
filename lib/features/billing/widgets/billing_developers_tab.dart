import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../shared/validators.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/dialogs.dart';
import '../billing_models.dart';
import '../billing_repository.dart';
import 'billing_widgets.dart';

/// API keys for the app's backend, and outbound webhooks. Owners only: the
/// server refuses everyone else, so the tab does not ask.
class BillingDevelopersTab extends ConsumerWidget {
  const BillingDevelopersTab({super.key, required this.slug});
  final String slug;

  Future<void> _createKey(BuildContext context, WidgetRef ref) async {
    final input = await showDialog<({String name, int? days})>(context: context, builder: (_) => const _KeyDialog());
    if (input == null || !context.mounted) return;
    final created = await runAction(
      context,
      () => ref.read(billingRepositoryProvider).createApiKey(slug, name: input.name, expiresInDays: input.days),
    );
    if (created == null || !context.mounted) return;
    ref.invalidate(billingApiKeysProvider(slug));
    await showSecretDialog(
      context,
      title: 'API key created',
      label: 'API key',
      secret: created.secret,
      explanation: 'Send it as the x-api-key header from your backend to read entitlements (scope entitlements:read).',
    );
  }

  Future<void> _revokeKey(BuildContext context, WidgetRef ref, BillingApiKey k) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Revoke ${k.name}?',
      message: 'Backends using this key stop working immediately.',
      confirmLabel: 'Revoke',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await runAction(context, () async {
      await ref.read(billingRepositoryProvider).revokeApiKey(slug, k.id);
      return true;
    }, success: 'Key revoked');
    if (done == true) ref.invalidate(billingApiKeysProvider(slug));
  }

  Future<void> _addWebhook(BuildContext context, WidgetRef ref) async {
    final input = await showDialog<({String url, List<String> events})>(
      context: context,
      builder: (_) => const _WebhookDialog(),
    );
    if (input == null || !context.mounted) return;
    final created = await runAction(
      context,
      () => ref.read(billingRepositoryProvider).createWebhook(slug, url: input.url, events: input.events),
    );
    if (created == null || !context.mounted) return;
    ref.invalidate(billingWebhooksProvider(slug));
    await showSecretDialog(
      context,
      title: 'Webhook added',
      label: 'Signing secret',
      secret: created.secret,
      explanation:
          'Verify each delivery: the neobilling-signature header is t=<unix>,v1=<hex HMAC-SHA256(secret, "<t>.<body>")>. '
          'Reject timestamps older than five minutes and dedupe on the payload id.',
    );
  }

  Future<void> _ping(BuildContext context, WidgetRef ref, BillingWebhook w) async {
    final result = await runAction(context, () => ref.read(billingRepositoryProvider).pingWebhook(slug, w.id));
    if (result == null || !context.mounted) return;
    showSnack(
      context,
      result.ok
          ? 'Ping delivered (HTTP ${result.status})'
          : 'Ping failed: ${result.error ?? (result.status != null ? 'HTTP ${result.status}' : 'no response')}',
      error: !result.ok,
    );
  }

  Future<void> _deleteWebhook(BuildContext context, WidgetRef ref, BillingWebhook w) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete webhook?',
      message: 'Events will no longer be sent to ${w.url}. Pending deliveries are dropped.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await runAction(context, () async {
      await ref.read(billingRepositoryProvider).deleteWebhook(slug, w.id);
      return true;
    }, success: 'Webhook deleted');
    if (done == true) ref.invalidate(billingWebhooksProvider(slug));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(billingRoleProvider).isOwner) {
      return const NeedsRole(role: 'owners', what: 'manage API keys and webhooks');
    }
    final keys = ref.watch(billingApiKeysProvider(slug));
    final hooks = ref.watch(billingWebhooksProvider(slug));
    return PageBody(
      children: [
        SectionCard(
          title: 'API keys',
          subtitle: 'For your backend to read a user\'s entitlements. The key is shown once.',
          trailing: FilledButton.icon(
            onPressed: () => _createKey(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
          child: AsyncValueView(
            value: keys,
            onRetry: () => ref.invalidate(billingApiKeysProvider(slug)),
            isEmpty: (k) => k.isEmpty,
            empty: const Text('No API keys.'),
            data: (list) => Column(
              children: [
                for (final k in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(k.name),
                    subtitle: Text(
                      [
                        '${k.prefix}…',
                        k.scopes.join(', '),
                        if (k.expiresAt != null) 'expires ${formatDate(k.expiresAt)}',
                        'last used ${formatRelative(k.lastUsedAt)}',
                      ].join(' · '),
                    ),
                    leading: StatusChip.status(k.isActive ? 'active' : 'disabled'),
                    trailing: k.isActive
                        ? IconButton(
                            tooltip: 'Revoke ${k.name}',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _revokeKey(context, ref, k),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ),
        SectionCard(
          title: 'Webhooks',
          subtitle:
              'Signed notifications to your backend when entitlements and subscriptions change, retried with backoff.',
          trailing: FilledButton.icon(
            onPressed: () => _addWebhook(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          child: AsyncValueView(
            value: hooks,
            onRetry: () => ref.invalidate(billingWebhooksProvider(slug)),
            isEmpty: (h) => h.isEmpty,
            empty: const Text('No webhooks.'),
            data: (list) => Column(
              children: [
                for (final w in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(w.url, style: const TextStyle(fontFamily: 'monospace')),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          StatusChip.status(w.status),
                          for (final e in w.events) StatusChip(label: e),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Send a test ping',
                          icon: const Icon(Icons.send_outlined),
                          onPressed: () => _ping(context, ref, w),
                        ),
                        IconButton(
                          tooltip: 'Delete webhook',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteWebhook(context, ref, w),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KeyDialog extends StatefulWidget {
  const _KeyDialog();

  @override
  State<_KeyDialog> createState() => _KeyDialogState();
}

class _KeyDialogState extends State<_KeyDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _days = TextEditingController(text: '365');

  @override
  void dispose() {
    _name.dispose();
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create API key'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('key.name'),
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'api-server'),
              validator: (v) {
                final t = (v ?? '').trim();
                return t.isEmpty || t.length > 100 ? 'Enter a name (up to 100 characters)' : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('key.days'),
              controller: _days,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Expires in (days)',
                helperText: 'Leave empty for no expiry.',
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final n = int.tryParse(t);
                return n == null || n < 1 || n > 3650 ? '1 to 3650' : null;
              },
            ),
            const SizedBox(height: 8),
            const Text('Scope: entitlements:read'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.of(context).pop((name: _name.text.trim(), days: int.tryParse(_days.text.trim())));
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _WebhookDialog extends StatefulWidget {
  const _WebhookDialog();

  @override
  State<_WebhookDialog> createState() => _WebhookDialogState();
}

class _WebhookDialogState extends State<_WebhookDialog> {
  final _form = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _events = <String>{'entitlement.granted', 'entitlement.updated', 'entitlement.revoked'};
  bool _triedSubmit = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _triedSubmit = true);
    if (!_form.currentState!.validate() || _events.isEmpty) return;
    Navigator.of(context)
        .pop((url: _url.text.trim(), events: BillingWebhook.allEvents.where(_events.contains).toList()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add webhook'),
      // bottom-inset-ok: dialog content, not the bottom edge of the window
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('webhook.url'),
                controller: _url,
                autofocus: true,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Endpoint URL',
                  hintText: 'https://api.example.com/hooks/billing',
                  helperText: 'Must be https in production.',
                ),
                validator: validateHttpUrl,
              ),
              const SizedBox(height: 16),
              Text('Events', style: theme.textTheme.labelLarge),
              for (final e in BillingWebhook.allEvents)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _events.contains(e),
                  title: Text(e, style: const TextStyle(fontFamily: 'monospace')),
                  onChanged: (v) => setState(() => v == true ? _events.add(e) : _events.remove(e)),
                ),
              if (_triedSubmit && _events.isEmpty)
                Text('Pick at least one event', style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
