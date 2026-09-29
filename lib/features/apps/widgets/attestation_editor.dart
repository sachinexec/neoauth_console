import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/chip_list_editor.dart';
import '../../../shared/widgets/common.dart';
import '../apps_repository.dart';
import '../models/app_models.dart';

/// Device attestation: Play Integrity (Android) and App Attest (iOS).
class AttestationEditor extends ConsumerStatefulWidget {
  const AttestationEditor({super.key, required this.client, required this.enabled});
  final ClientModel client;
  final bool enabled;

  @override
  ConsumerState<AttestationEditor> createState() => _AttestationEditorState();
}

class _AttestationEditorState extends ConsumerState<AttestationEditor> {
  late AttestationMode _mode;
  late bool _android;
  late bool _ios;
  final _package = TextEditingController();
  final _teamId = TextEditingController();
  final _bundleId = TextEditingController();
  late List<String> _certs;
  late bool _allowDev;
  bool _saving = false;
  List<String> _errors = const [];

  @override
  void initState() {
    super.initState();
    _load(widget.client.attestation);
    for (final c in [_package, _teamId, _bundleId]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void didUpdateWidget(AttestationEditor old) {
    super.didUpdateWidget(old);
    if (!identical(old.client, widget.client) && !_dirty) _load(widget.client.attestation);
  }

  void _load(AttestationConfig a) {
    _mode = a.mode;
    _android = a.android != null;
    _ios = a.ios != null;
    _package.text = a.android?.packageName ?? '';
    _certs = [...?a.android?.certificateSha256];
    _teamId.text = a.ios?.teamId ?? '';
    _bundleId.text = a.ios?.bundleId ?? '';
    _allowDev = a.ios?.allowDevelopment ?? false;
    _errors = const [];
  }

  @override
  void dispose() {
    for (final c in [_package, _teamId, _bundleId]) {
      c.dispose();
    }
    super.dispose();
  }

  AttestationConfig get _draft => AttestationConfig(
    mode: _mode,
    android: _android ? AndroidAttestation(packageName: _package.text.trim(), certificateSha256: _certs) : null,
    ios: _ios
        ? IosAttestation(teamId: _teamId.text.trim(), bundleId: _bundleId.text.trim(), allowDevelopment: _allowDev)
        : null,
  );

  bool get _dirty {
    final a = widget.client.attestation;
    final d = _draft;
    return a.mode != d.mode ||
        (a.android == null) != (d.android == null) ||
        (a.ios == null) != (d.ios == null) ||
        (d.android != null &&
            (a.android!.packageName != d.android!.packageName ||
                a.android!.certificateSha256.join(',') != d.android!.certificateSha256.join(','))) ||
        (d.ios != null &&
            (a.ios!.teamId != d.ios!.teamId ||
                a.ios!.bundleId != d.ios!.bundleId ||
                a.ios!.allowDevelopment != d.ios!.allowDevelopment));
  }

  Future<void> _save() async {
    final draft = _draft;
    final errors = [
      ...draft.validate(),
      if (draft.mode == AttestationMode.enforce && draft.android == null && draft.ios == null)
        'Add Android or iOS details before enforcing.',
    ];
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    setState(() => _saving = true);
    final updated = await runAction(
      context,
      () => ref.read(appsRepositoryProvider).setAttestation(widget.client.clientId, draft),
      success: 'Attestation saved',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (updated != null) {
      setState(() => _load(updated.attestation));
      refreshClient(ref, updated);
    }
  }

  static String? _validateCert(String v) =>
      AndroidAttestation.sha256Pattern.hasMatch(v) ? null : 'A SHA-256 fingerprint: 32 hex bytes, e.g. AB:CD:…';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.enabled && !_saving;
    final isNative = widget.client.applicationType == ApplicationType.native;
    return SectionCard(
      title: 'Device attestation',
      subtitle: isNative
          ? 'Prove native sign-ins come from a genuine build of your app on a real device.'
          : 'Only applies to native sign-ins; this is a web client.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<AttestationMode>(
            segments: [for (final m in AttestationMode.values) ButtonSegment(value: m, label: Text(m.label))],
            selected: {_mode},
            onSelectionChanged: enabled ? (s) => setState(() => _mode = s.first) : null,
          ),
          const SizedBox(height: 4),
          Text(_mode.description, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          MergeSemantics(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.android),
              title: const Text('Android (Play Integrity)'),
              value: _android,
              onChanged: enabled ? (v) => setState(() => _android = v) : null,
            ),
          ),
          if (_android) ...[
            TextField(
              controller: _package,
              enabled: enabled,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Package name', hintText: 'in.neodiverse.app'),
            ),
            const SizedBox(height: 12),
            ChipListEditor(
              label: 'Signing certificate SHA-256',
              values: _certs,
              enabled: enabled,
              keyboardType: TextInputType.text,
              hintText: 'AB:CD:EF:…',
              helperText: 'From the Play Console app signing page. Add the upload key too for internal testing.',
              validator: _validateCert,
              onChanged: (v) => setState(() => _certs = v),
            ),
            const SizedBox(height: 8),
          ],
          MergeSemantics(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.apple),
              title: const Text('iOS (App Attest)'),
              value: _ios,
              onChanged: enabled ? (v) => setState(() => _ios = v) : null,
            ),
          ),
          if (_ios) ...[
            TextField(
              controller: _teamId,
              enabled: enabled,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
              decoration: const InputDecoration(labelText: 'Team ID', hintText: 'ABCDE12345'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bundleId,
              enabled: enabled,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Bundle ID', hintText: 'in.neodiverse.app'),
            ),
            MergeSemantics(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow development builds'),
                subtitle: const Text(
                  'Accept the App Attest development environment (Xcode builds). Turn off for production.',
                ),
                value: _allowDev,
                onChanged: enabled ? (v) => setState(() => _allowDev = v) : null,
              ),
            ),
          ],
          for (final e in _errors)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(e, style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (widget.enabled) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _dirty && !_saving ? () => setState(() => _load(widget.client.attestation)) : null,
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 8),
                BusyButton(onPressed: _dirty ? _save : null, busy: _saving, label: 'Save'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
