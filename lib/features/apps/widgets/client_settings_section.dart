import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/json.dart';
import '../../../shared/validators.dart';
import '../../../shared/widgets/chip_list_editor.dart';
import '../../../shared/widgets/common.dart';
import '../apps_repository.dart';
import '../models/app_models.dart';

/// Name, redirect URIs, back-channel logout and native sign-in.
class ClientSettingsSection extends ConsumerStatefulWidget {
  const ClientSettingsSection({super.key, required this.client, required this.enabled});
  final ClientModel client;
  final bool enabled;

  @override
  ConsumerState<ClientSettingsSection> createState() => _ClientSettingsSectionState();
}

class _ClientSettingsSectionState extends ConsumerState<ClientSettingsSection> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _backchannel = TextEditingController();
  late List<String> _redirects;
  late List<String> _postLogout;
  late bool _nativeLogin;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load(widget.client);
    _name.addListener(() => setState(() {}));
    _backchannel.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(ClientSettingsSection old) {
    super.didUpdateWidget(old);
    if (!identical(old.client, widget.client) && !_dirty) _load(widget.client);
  }

  void _load(ClientModel c) {
    _name.text = c.name;
    _backchannel.text = c.backchannelLogoutUri ?? '';
    _redirects = [...c.redirectUris];
    _postLogout = [...c.postLogoutRedirectUris];
    _nativeLogin = c.nativeLogin;
  }

  @override
  void dispose() {
    _name.dispose();
    _backchannel.dispose();
    super.dispose();
  }

  Json get _changes {
    final c = widget.client;
    return {
      if (_name.text.trim() != c.name) 'name': _name.text.trim(),
      if (!listEquals(_redirects, c.redirectUris)) 'redirect_uris': _redirects,
      if (!listEquals(_postLogout, c.postLogoutRedirectUris)) 'post_logout_redirect_uris': _postLogout,
      if (trimmedOrNull(_backchannel.text) != c.backchannelLogoutUri)
        'backchannel_logout_uri': trimmedOrNull(_backchannel.text),
      if (_nativeLogin != c.nativeLogin) 'native_login': _nativeLogin,
    };
  }

  bool get _dirty => _changes.isNotEmpty;

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _redirects.isEmpty) return;
    setState(() => _saving = true);
    final updated = await runAction(
      context,
      () => ref.read(appsRepositoryProvider).updateClient(widget.client.clientId, _changes),
      success: 'Client saved',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (updated != null) _load(updated);
    });
    if (updated != null) refreshClient(ref, updated);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final enabled = widget.enabled && !_saving;
    return SectionCard(
      title: 'Settings',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              enabled: enabled,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 8),
            ChipListEditor(
              label: 'Redirect URIs',
              values: _redirects,
              enabled: enabled,
              validator: validateRedirectUri,
              errorText: _redirects.isEmpty ? 'At least one redirect URI is required' : null,
              onChanged: (v) => setState(() => _redirects = v),
            ),
            const SizedBox(height: 16),
            ChipListEditor(
              label: 'Post-logout redirect URIs',
              values: _postLogout,
              enabled: enabled,
              validator: validateRedirectUri,
              onChanged: (v) => setState(() => _postLogout = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _backchannel,
              enabled: enabled,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Back-channel logout URI'),
              validator: (v) => validateHttpUrl(v, required: false),
            ),
            const SizedBox(height: 8),
            MergeSemantics(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Native sign-in'),
                subtitle: Text(
                  c.firstParty
                      ? 'Browserless sign-in from the app with the SDK.'
                      : 'Only available to first-party clients.',
                ),
                value: _nativeLogin,
                onChanged: enabled && c.firstParty ? (v) => setState(() => _nativeLogin = v) : null,
              ),
            ),
            if (widget.enabled) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _dirty && !_saving ? () => setState(() => _load(c)) : null,
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 8),
                  BusyButton(onPressed: _dirty && _redirects.isNotEmpty ? _save : null, busy: _saving, label: 'Save'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
