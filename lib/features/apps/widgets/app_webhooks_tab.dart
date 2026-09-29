import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/format.dart';
import '../../../shared/validators.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/dialogs.dart';
import '../apps_repository.dart';
import '../models/app_models.dart';

class AppWebhooksTab extends ConsumerWidget {
  const AppWebhooksTab({super.key, required this.app});
  final AppModel app;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({String url, List<String> events})>(
      context: context,
      builder: (_) => const _AddWebhookDialog(),
    );
    if (result == null || !context.mounted) return;
    final created = await runAction(
      context,
      () => ref.read(appsRepositoryProvider).createWebhook(app.slug, url: result.url, events: result.events),
    );
    if (created == null || !context.mounted) return;
    ref.invalidate(appDetailProvider(app.slug));
    if (created.secret != null) {
      await showSecretDialog(
        context,
        title: 'Webhook added',
        label: 'Signing secret',
        secret: created.secret!,
        explanation:
            'Verify each delivery: the Auth-Signature header is t=<unix>,v1=<hex HMAC-SHA256(secret, "<t>.<body>")>. '
            'Reject timestamps older than five minutes.',
      );
    }
  }

  Future<void> _ping(BuildContext context, WidgetRef ref, WebhookEndpoint w) async {
    final result = await runAction(context, () => ref.read(appsRepositoryProvider).pingWebhook(app.slug, w.id));
    if (result == null || !context.mounted) return;
    showSnack(
      context,
      result.ok
          ? 'Ping delivered (HTTP ${result.status})'
          : 'Ping failed: ${result.error ?? (result.status != null ? 'HTTP ${result.status}' : 'no response')}',
      error: !result.ok,
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, WebhookEndpoint w) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete webhook?',
      message: 'Events will no longer be sent to ${w.url}. Pending deliveries are dropped.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await runAction(context, () async {
      await ref.read(appsRepositoryProvider).deleteWebhook(app.slug, w.id);
      return true;
    }, success: 'Webhook deleted');
    if (done == true) ref.invalidate(appDetailProvider(app.slug));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(roleProvider).canEdit;
    final hooks = app.webhooks ?? const <WebhookEndpoint>[];
    final allowed = app.webhooksAllowed;
    final theme = Theme.of(context);

    return PageBody(
      children: [
        SectionCard(
          title: 'Webhooks',
          subtitle: 'Signed notifications to your backend when accounts change, retried with backoff.',
          trailing: canEdit && allowed
              ? FilledButton.icon(
                  onPressed: () => _add(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!allowed)
                Text(
                  'Webhooks carry internal user IDs, so they are only available to apps whose clients are all first-party.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              if (hooks.isEmpty && allowed) const EmptyView(title: 'No webhooks', icon: Icons.webhook_outlined),
              for (final w in hooks)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(w.url, style: const TextStyle(fontFamily: 'monospace')),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          StatusChip.status(w.status),
                          for (final e in w.events) StatusChip(label: e),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Added ${formatDate(w.createdAt)}'),
                    ],
                  ),
                  trailing: canEdit
                      ? Row(
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
                              onPressed: () => _delete(context, ref, w),
                            ),
                          ],
                        )
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddWebhookDialog extends StatefulWidget {
  const _AddWebhookDialog();

  @override
  State<_AddWebhookDialog> createState() => _AddWebhookDialogState();
}

class _AddWebhookDialogState extends State<_AddWebhookDialog> {
  final _form = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _events = WebhookEndpoint.allEvents.keys.toSet();
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
        .pop((url: _url.text.trim(), events: WebhookEndpoint.allEvents.keys.where(_events.contains).toList()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add webhook'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _url,
                autofocus: true,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Endpoint URL',
                  hintText: 'https://api.example.com/hooks/auth',
                  helperText: 'Must be https in production.',
                ),
                validator: validateHttpUrl,
              ),
              const SizedBox(height: 16),
              Text('Events', style: theme.textTheme.labelLarge),
              for (final e in WebhookEndpoint.allEvents.entries)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _events.contains(e.key),
                  title: Text(e.value),
                  subtitle: Text(e.key, style: const TextStyle(fontFamily: 'monospace')),
                  onChanged: (v) => setState(() => v == true ? _events.add(e.key) : _events.remove(e.key)),
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
