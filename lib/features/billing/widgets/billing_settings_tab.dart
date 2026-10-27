import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/copy_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../billing_models.dart';
import '../billing_repository.dart';
import 'billing_widgets.dart';

/// App settings and write-only store credentials. Only owners can change them;
/// everyone sees which store is set up and its non-secret identifiers.
class BillingSettingsTab extends ConsumerWidget {
  const BillingSettingsTab({super.key, required this.app});
  final BillingApp app;

  void _refresh(WidgetRef ref) {
    ref.invalidate(billingAppProvider(app.slug));
    ref.invalidate(billingAppsProvider);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({String name, String audience, String status})>(
      context: context,
      builder: (_) => _EditAppDialog(app: app),
    );
    if (result == null || !context.mounted) return;
    final updated = await runAction(
      context,
      () => ref
          .read(billingRepositoryProvider)
          .updateApp(
            app.slug,
            name: result.name == app.name ? null : result.name,
            apiAudience: result.audience == app.apiAudience ? null : result.audience,
            status: result.status == app.status ? null : result.status,
          ),
      success: 'Saved',
    );
    if (updated != null) _refresh(ref);
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, {bool? binding, bool? transfer}) async {
    if (binding == false) {
      final ok = await showConfirmDialog(
        context,
        title: 'Turn off account binding?',
        message:
            'Purchases without an account token could then be claimed by whoever submits them first. '
            'Only do this for apps whose old purchases carry none.',
        confirmLabel: 'Turn off',
        destructive: true,
      );
      if (!ok || !context.mounted) return;
    }
    if (transfer == true) {
      final ok = await showConfirmDialog(
        context,
        title: 'Allow restore to transfer purchases?',
        message: 'A restore will then move a purchase to the account that restores it, once per 24 hours.',
        confirmLabel: 'Allow',
        destructive: true,
      );
      if (!ok || !context.mounted) return;
    }
    final updated = await runAction(
      context,
      () => ref
          .read(billingRepositoryProvider)
          .updateApp(app.slug, requireAccountBinding: binding, allowRestoreTransfer: transfer),
      success: 'Saved',
    );
    if (updated != null) _refresh(ref);
  }

  Future<void> _setApple(BuildContext context, WidgetRef ref) async {
    final c = await showDialog<_AppleInput>(
      context: context,
      builder: (_) => _AppleDialog(current: app.apple),
    );
    if (c == null || !context.mounted) return;
    final saved = await runAction(
      context,
      () => ref
          .read(billingRepositoryProvider)
          .setApple(
            app.slug,
            bundleId: c.bundleId,
            issuerId: c.issuerId,
            keyId: c.keyId,
            privateKey: c.privateKey,
            appAppleId: c.appAppleId,
            allowSandbox: c.allowSandbox,
          ),
      success: 'Apple credentials saved',
    );
    if (saved != null) _refresh(ref);
  }

  Future<void> _setGoogle(BuildContext context, WidgetRef ref) async {
    final c = await showDialog<_GoogleInput>(
      context: context,
      builder: (_) => _GoogleDialog(current: app.google),
    );
    if (c == null || !context.mounted) return;
    final saved = await runAction(
      context,
      () => ref
          .read(billingRepositoryProvider)
          .setGoogle(
            app.slug,
            packageName: c.packageName,
            serviceAccountJson: c.serviceAccountJson,
            allowSandbox: c.allowSandbox,
          ),
      success: 'Google credentials saved',
    );
    if (saved != null) _refresh(ref);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, {required bool apple}) async {
    final store = apple ? 'Apple' : 'Google';
    final ok = await showConfirmDialog(
      context,
      title: 'Remove $store credentials?',
      message:
          'Purchases and notifications from $store can no longer be verified for ${app.name} until you add them again.',
      confirmLabel: 'Remove',
      destructive: true,
      typedConfirmation: app.slug,
    );
    if (!ok || !context.mounted) return;
    final done = await runAction(context, () async {
      final repo = ref.read(billingRepositoryProvider);
      await (apple ? repo.removeApple(app.slug) : repo.removeGoogle(app.slug));
      return true;
    }, success: '$store credentials removed');
    if (done == true) _refresh(ref);
  }

  Future<void> _setNeoauthSecret(BuildContext context, WidgetRef ref) async {
    final secret = await showDialog<String>(context: context, builder: (_) => const _SecretDialog());
    if (secret == null || !context.mounted) return;
    final saved = await runAction(
      context,
      () => ref.read(billingRepositoryProvider).setNeoauthWebhookSecret(app.slug, secret),
      success: 'Secret saved',
    );
    if (saved != null) _refresh(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(billingRoleProvider);
    final owner = role.isOwner;
    final base = ref.watch(appConfigProvider).billingUrl;
    final theme = Theme.of(context);
    return PageBody(
      children: [
        if (!owner) const ReadOnlyBanner(),
        SectionCard(
          title: 'App',
          trailing: owner
              ? IconButton(
                  tooltip: 'Edit app',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(context, ref),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoRow(label: 'Name', value: app.name),
              InfoRow(label: 'Slug', value: app.slug, monospace: true),
              InfoRow(label: 'API audience', value: app.apiAudience, monospace: true),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const SizedBox(width: 140, child: Text('Status')),
                    StatusChip.status(app.status),
                  ],
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require account binding'),
                subtitle: const Text('Purchases must be tied to the signed-in user.'),
                value: app.requireAccountBinding,
                onChanged: owner ? (v) => _toggle(context, ref, binding: v) : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow restore to transfer purchases'),
                subtitle: const Text('A restore may move a purchase to the restoring account.'),
                value: app.allowRestoreTransfer,
                onChanged: owner ? (v) => _toggle(context, ref, transfer: v) : null,
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Apple App Store',
          subtitle: 'Key for the App Store Server API. Secrets are write-only.',
          trailing: credentialChip('Apple', app.apple.configured, sandbox: app.apple.allowSandbox),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (app.apple.configured) ...[
                InfoRow(label: 'Bundle ID', value: app.apple.bundleId ?? '—', monospace: true),
                InfoRow(label: 'Issuer ID', value: app.apple.issuerId ?? '—', monospace: true),
                InfoRow(label: 'Key ID', value: app.apple.keyId ?? '—', monospace: true),
                InfoRow(label: 'Apple app ID', value: app.apple.appAppleId?.toString() ?? '—'),
                const InfoRow(label: 'Private key', value: 'Stored encrypted. Not shown.'),
                if (app.apple.allowSandbox)
                  Text(
                    'Sandbox purchases are accepted. Turn this off once App Review and TestFlight are done.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
              ] else
                Text('Not set up: Apple purchases cannot be verified.', style: theme.textTheme.bodyMedium),
              if (owner) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _setApple(context, ref),
                      icon: const Icon(Icons.vpn_key_outlined),
                      label: Text(app.apple.configured ? 'Replace credentials' : 'Set credentials'),
                    ),
                    if (app.apple.configured)
                      TextButton(onPressed: () => _remove(context, ref, apple: true), child: const Text('Remove')),
                  ],
                ),
              ],
            ],
          ),
        ),
        SectionCard(
          title: 'Google Play',
          subtitle: 'Service account for the Play Developer API. Secrets are write-only.',
          trailing: credentialChip('Google', app.google.configured, sandbox: app.google.allowSandbox),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (app.google.configured) ...[
                InfoRow(label: 'Package', value: app.google.packageName ?? '—', monospace: true),
                InfoRow(label: 'Service account', value: app.google.serviceAccountEmail ?? '—', monospace: true),
                const InfoRow(label: 'Key', value: 'Stored encrypted. Not shown.'),
                if (app.google.allowSandbox)
                  Text(
                    'Test purchases are accepted. Turn this off when testing is done.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
              ] else
                Text('Not set up: Google purchases cannot be verified.', style: theme.textTheme.bodyMedium),
              if (owner) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _setGoogle(context, ref),
                      icon: const Icon(Icons.vpn_key_outlined),
                      label: Text(app.google.configured ? 'Replace credentials' : 'Set credentials'),
                    ),
                    if (app.google.configured)
                      TextButton(onPressed: () => _remove(context, ref, apple: false), child: const Text('Remove')),
                  ],
                ),
              ],
            ],
          ),
        ),
        SectionCard(
          title: 'NeoAuth account deletion',
          subtitle:
              'Signing secret of the NeoAuth webhook that reports deleted users, so their purchase links are erased.',
          trailing: StatusChip(
            label: app.neoauthWebhookConfigured ? 'Configured' : 'Not set',
            tone: app.neoauthWebhookConfigured ? ChipTone.success : ChipTone.warning,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (base.isNotEmpty)
                CopyField(label: 'NeoAuth webhook URL', value: '$base/v1/webhooks/neoauth/${app.slug}', dense: true),
              if (owner) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _setNeoauthSecret(context, ref),
                    icon: const Icon(Icons.vpn_key_outlined),
                    label: Text(app.neoauthWebhookConfigured ? 'Replace secret' : 'Set secret'),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (base.isNotEmpty)
          SectionCard(
            title: 'Store notification URLs',
            subtitle: 'Enter these in App Store Connect (production and sandbox, version 2) and in the Play Pub/Sub push subscription.',
            child: Column(
              children: [
                CopyField(label: 'Apple', value: '$base/v1/webhooks/apple', dense: true),
                const SizedBox(height: 12),
                CopyField(label: 'Google', value: '$base/v1/webhooks/google', dense: true),
              ],
            ),
          ),
      ],
    );
  }
}

class _EditAppDialog extends StatefulWidget {
  const _EditAppDialog({required this.app});
  final BillingApp app;

  @override
  State<_EditAppDialog> createState() => _EditAppDialogState();
}

class _EditAppDialogState extends State<_EditAppDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.app.name);
  late final _audience = TextEditingController(text: widget.app.apiAudience);
  late String _status = widget.app.status;

  @override
  void dispose() {
    _name.dispose();
    _audience.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit app'),
      // bottom-inset-ok: dialog content, not the bottom edge of the window
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _audience,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'API audience',
                  helperText: 'Changing it stops tokens with the old audience from working.',
                  helperMaxLines: 3,
                ),
                validator: (v) => (v ?? '').trim().length < 3 ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  helperText: 'A disabled app rejects every request.',
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'disabled', child: Text('Disabled')),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
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
              Navigator.of(context).pop((name: _name.text.trim(), audience: _audience.text.trim(), status: _status));
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

typedef _AppleInput = ({
  String bundleId,
  String issuerId,
  String keyId,
  String privateKey,
  int? appAppleId,
  bool allowSandbox,
});

class _AppleDialog extends StatefulWidget {
  const _AppleDialog({required this.current});
  final AppleCredentialInfo current;

  @override
  State<_AppleDialog> createState() => _AppleDialogState();
}

class _AppleDialogState extends State<_AppleDialog> {
  final _form = GlobalKey<FormState>();
  late final _bundle = TextEditingController(text: widget.current.bundleId);
  late final _issuer = TextEditingController(text: widget.current.issuerId);
  late final _keyId = TextEditingController(text: widget.current.keyId);
  late final _appId = TextEditingController(text: widget.current.appAppleId?.toString());
  // Never pre-filled: the server does not return it.
  final _key = TextEditingController();
  late bool _sandbox = widget.current.allowSandbox;

  @override
  void dispose() {
    _bundle.dispose();
    _issuer.dispose();
    _keyId.dispose();
    _appId.dispose();
    _key.clear();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Apple credentials'),
      // bottom-inset-ok: dialog content, not the bottom edge of the window
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'App Store Connect, Users and Access, Integrations, In-App Purchase. The key replaces the stored one.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('apple.bundle'),
                controller: _bundle,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Bundle ID'),
                validator: (v) =>
                    RegExp(r'^[A-Za-z0-9.-]{3,155}$').hasMatch((v ?? '').trim()) ? null : 'Enter the bundle ID',
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('apple.issuer'),
                controller: _issuer,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Issuer ID'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  return t.length < 8 || t.length > 64 ? 'Enter the issuer ID' : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('apple.keyId'),
                controller: _keyId,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Key ID', helperText: '10 letters and digits'),
                validator: (v) =>
                    RegExp(r'^[A-Z0-9]{10}$').hasMatch((v ?? '').trim()) ? null : 'Enter the 10-character key ID',
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('apple.appId'),
                controller: _appId,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Apple app ID',
                  helperText: 'The numeric ID of the app. Required for production.',
                  helperMaxLines: 2,
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  final n = int.tryParse(t);
                  return n == null || n < 1 ? 'Digits only' : null;
                },
              ),
              const SizedBox(height: 16),
              SecretFormField(
                fieldKey: const Key('apple.privateKey'),
                controller: _key,
                label: 'Private key (.p8 text)',
                multiline: true,
                helper: 'Paste the whole file, including the BEGIN and END lines. Write-only: it is never shown again.',
                validator: (v) => (v ?? '').contains('PRIVATE KEY') ? null : 'Paste the .p8 file contents',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Accept sandbox purchases'),
                subtitle: const Text('Needed for TestFlight and App Review. Turn off afterwards.'),
                value: _sandbox,
                onChanged: (v) => setState(() => _sandbox = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.of(context).pop((
              bundleId: _bundle.text.trim(),
              issuerId: _issuer.text.trim(),
              keyId: _keyId.text.trim(),
              privateKey: _key.text,
              appAppleId: int.tryParse(_appId.text.trim()),
              allowSandbox: _sandbox,
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

typedef _GoogleInput = ({String packageName, String serviceAccountJson, bool allowSandbox});

class _GoogleDialog extends StatefulWidget {
  const _GoogleDialog({required this.current});
  final GoogleCredentialInfo current;

  @override
  State<_GoogleDialog> createState() => _GoogleDialogState();
}

class _GoogleDialogState extends State<_GoogleDialog> {
  final _form = GlobalKey<FormState>();
  late final _package = TextEditingController(text: widget.current.packageName);
  final _json = TextEditingController();
  late bool _sandbox = widget.current.allowSandbox;

  @override
  void dispose() {
    _package.dispose();
    _json.clear();
    _json.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Google credentials'),
      // bottom-inset-ok: dialog content, not the bottom edge of the window
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Play Console, Setup, API access: a service account with "View financial data" and "Manage orders and subscriptions". The key replaces the stored one.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('google.package'),
                controller: _package,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Package name'),
                validator: (v) =>
                    RegExp(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$').hasMatch((v ?? '').trim())
                    ? null
                    : 'Enter the package name, e.g. com.example.app',
              ),
              const SizedBox(height: 16),
              SecretFormField(
                fieldKey: const Key('google.json'),
                controller: _json,
                label: 'Service account key (JSON)',
                multiline: true,
                helper: 'Paste the whole JSON file. Write-only: it is never shown again.',
                validator: (v) => (v ?? '').contains('private_key') ? null : 'Paste the service account JSON',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Accept test purchases'),
                subtitle: const Text('For licence testers. Turn off when testing is done.'),
                value: _sandbox,
                onChanged: (v) => setState(() => _sandbox = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.of(context)
                .pop((packageName: _package.text.trim(), serviceAccountJson: _json.text, allowSandbox: _sandbox));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SecretDialog extends StatefulWidget {
  const _SecretDialog();

  @override
  State<_SecretDialog> createState() => _SecretDialogState();
}

class _SecretDialogState extends State<_SecretDialog> {
  final _form = GlobalKey<FormState>();
  final _secret = TextEditingController();

  @override
  void dispose() {
    _secret.clear();
    _secret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('NeoAuth webhook secret'),
      content: Form(
        key: _form,
        child: SecretFormField(
          fieldKey: const Key('neoauth.secret'),
          controller: _secret,
          label: 'Signing secret',
          helper: 'The secret of the NeoAuth webhook that points at this app. At least 16 characters. Write-only.',
          validator: (v) {
            final t = (v ?? '').trim();
            return t.length < 16 || t.length > 200 ? 'Enter the secret (16 to 200 characters)' : null;
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) Navigator.of(context).pop(_secret.text.trim());
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
