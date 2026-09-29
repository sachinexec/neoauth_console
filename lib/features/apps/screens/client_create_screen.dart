import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme.dart';
import '../../../shared/validators.dart';
import '../../../shared/widgets/chip_list_editor.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/dialogs.dart';
import '../apps_repository.dart';
import '../models/app_models.dart';

class ClientCreateScreen extends ConsumerStatefulWidget {
  const ClientCreateScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<ClientCreateScreen> createState() => _ClientCreateScreenState();
}

class _ClientCreateScreenState extends ConsumerState<ClientCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _backchannel = TextEditingController();
  ApplicationType _appType = ApplicationType.web;
  ClientType _clientType = ClientType.public;
  bool _firstParty = true;
  bool _nativeLogin = false;
  List<String> _redirects = [];
  List<String> _postLogout = [];
  bool _triedSubmit = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _backchannel.dispose();
    super.dispose();
  }

  void _setAppType(ApplicationType t) => setState(() {
    _appType = t;
    // Native apps can't keep a secret.
    if (t == ApplicationType.native) _clientType = ClientType.public;
    _nativeLogin = t == ApplicationType.native && _firstParty;
  });

  Future<void> _submit() async {
    setState(() => _triedSubmit = true);
    if (!_form.currentState!.validate() || _redirects.isEmpty) return;
    if (!_firstParty) {
      final ok = await showConfirmDialog(
        context,
        title: 'Create a third-party client?',
        message:
            'Third-party clients get pairwise user IDs (a different ID per client) and must ask users for consent. '
            'This cannot be changed after the client is created.',
        confirmLabel: 'Create third-party client',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    final client = await runAction(
      context,
      () => ref
          .read(appsRepositoryProvider)
          .createClient(
            widget.slug,
            name: _name.text.trim(),
            applicationType: _appType,
            clientType: _clientType,
            firstParty: _firstParty,
            redirectUris: _redirects,
            postLogoutRedirectUris: _postLogout,
            backchannelLogoutUri: trimmedOrNull(_backchannel.text),
            nativeLogin: _firstParty && _nativeLogin,
          ),
      success: 'Client created',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (client == null) return;
    ref.invalidate(appDetailProvider(widget.slug));
    ref.invalidate(appsListProvider);
    if (client.clientSecret != null) {
      await showSecretDialog(
        context,
        title: 'Client created',
        label: 'Client secret',
        secret: client.clientSecret!,
        extra: [('Client ID', client.clientId)],
        explanation: 'Store the secret in your server configuration. If it is lost, rotate it from the client page.',
      );
      if (!mounted) return;
    }
    context.pushReplacement(Routes.client(widget.slug, client.clientId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('New client')),
      body: Form(
        key: _form,
        child: PageBody(
          children: [
            SectionCard(
              title: 'Client',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Astro Graph iOS',
                      helperText: 'Shown to users on consent screens and in their devices list.',
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Text('Platform', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<ApplicationType>(
                    segments: const [
                      ButtonSegment(value: ApplicationType.web, icon: Icon(Icons.language), label: Text('Web')),
                      ButtonSegment(
                        value: ApplicationType.native,
                        icon: Icon(Icons.phone_iphone),
                        label: Text('Native'),
                      ),
                    ],
                    selected: {_appType},
                    onSelectionChanged: (s) => _setAppType(s.first),
                  ),
                  const SizedBox(height: 4),
                  Text(_appType.description, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 16),
                  Text('Client type', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<ClientType>(
                    segments: [
                      const ButtonSegment(value: ClientType.public, label: Text('Public')),
                      ButtonSegment(
                        value: ClientType.confidential,
                        label: const Text('Confidential'),
                        enabled: _appType == ApplicationType.web,
                      ),
                    ],
                    selected: {_clientType},
                    onSelectionChanged: (s) => setState(() => _clientType = s.first),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _appType == ApplicationType.native
                        ? 'Native apps are always public: a secret shipped in an app is not secret.'
                        : _clientType.description,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Who owns it',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RadioGroup<bool>(
                    groupValue: _firstParty,
                    onChanged: (v) => setState(() {
                      _firstParty = v ?? true;
                      if (!_firstParty) _nativeLogin = false;
                    }),
                    child: const Column(
                      children: [
                        RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          value: true,
                          title: Text('First-party (ours)'),
                          subtitle: Text(
                            'One of our own apps. Users share one user ID across all our apps; no consent screen.',
                          ),
                        ),
                        RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          value: false,
                          title: Text('Third-party (a partner)'),
                          subtitle: Text(
                            'Someone else\'s app using "Sign in with" us. It gets pairwise user IDs, so partners '
                            'cannot correlate users, and users are asked for consent.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: scheme.warningContainer, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, color: scheme.onWarningContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This choice is permanent: user IDs issued to a client can never change.',
                            style: TextStyle(color: scheme.onWarningContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_firstParty) ...[
                    const SizedBox(height: 8),
                    MergeSemantics(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Native sign-in'),
                        subtitle: const Text(
                          'Allow browserless sign-in from the app with the SDK (phone, email, passkey, Google, Apple). '
                          'First-party only.',
                        ),
                        value: _nativeLogin,
                        onChanged: (v) => setState(() => _nativeLogin = v),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SectionCard(
              title: 'Redirects',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ChipListEditor(
                    label: 'Redirect URIs',
                    values: _redirects,
                    hintText: _appType == ApplicationType.native
                        ? 'com.example.app:/oauth/callback'
                        : 'https://example.com/callback',
                    helperText: 'Where users return after signing in. Exact match; add each one.',
                    errorText: _triedSubmit && _redirects.isEmpty ? 'Add at least one redirect URI' : null,
                    validator: validateRedirectUri,
                    onChanged: (v) => setState(() => _redirects = v),
                  ),
                  const SizedBox(height: 16),
                  ChipListEditor(
                    label: 'Post-logout redirect URIs',
                    values: _postLogout,
                    hintText: 'https://example.com/',
                    helperText: 'Optional. Where users land after signing out.',
                    validator: validateRedirectUri,
                    onChanged: (v) => setState(() => _postLogout = v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _backchannel,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Back-channel logout URI (optional)',
                      hintText: 'https://example.com/backchannel-logout',
                      helperText: 'Your server is told here when a user signs out, so it can end their session.',
                      helperMaxLines: 2,
                    ),
                    validator: (v) => validateHttpUrl(v, required: false),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: BusyButton(onPressed: _submit, busy: _busy, label: 'Create client', icon: Icons.check),
            ),
          ],
        ),
      ),
    );
  }
}
