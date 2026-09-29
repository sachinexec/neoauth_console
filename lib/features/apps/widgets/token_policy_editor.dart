import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/duration_field.dart';
import '../models/app_models.dart';

/// Edits a token policy with duration pickers, presets and validation
/// against the server's bounds.
///
/// For an app ([allowInherit] false) every field is set. For a client
/// override ([allowInherit] true) each field can inherit the app's value
/// ([inherited]); only overridden fields are saved.
class TokenPolicyEditor extends StatefulWidget {
  const TokenPolicyEditor({
    super.key,
    required this.initial,
    required this.inherited,
    required this.onSave,
    this.clientType = ClientType.public,
    this.allowInherit = false,
    this.enabled = true,
  });

  final TokenPolicyInput initial;

  /// Values used for unset fields (app policy for clients, defaults for apps).
  final TokenPolicy inherited;
  final ClientType clientType;
  final bool allowInherit;
  final bool enabled;

  /// Returns true when saved, so the editor can take the saved values as its new baseline.
  final Future<bool> Function(TokenPolicyInput policy) onSave;

  @override
  State<TokenPolicyEditor> createState() => _TokenPolicyEditorState();
}

class _TokenPolicyEditorState extends State<TokenPolicyEditor> {
  late TokenPolicyInput _baseline;
  late TokenPolicyInput _draft;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reset(widget.initial);
  }

  @override
  void didUpdateWidget(TokenPolicyEditor old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial && !_dirty) _reset(widget.initial);
  }

  void _reset(TokenPolicyInput p) {
    _baseline = widget.allowInherit ? p : p.resolve(widget.inherited).toInput();
    _draft = _baseline;
  }

  bool get _dirty => _draft != _baseline;
  TokenPolicy get _effective => _draft.resolve(widget.inherited);
  List<PolicyError> get _errors => validatePolicy(_draft, clientType: widget.clientType);

  String? _errorFor(PolicyField f) {
    final e = _errors.where((e) => e.field == f).map((e) => e.message).toList();
    return e.isEmpty ? null : e.join(' ');
  }

  void _update(TokenPolicyInput Function(TokenPolicyInput d) fn) => setState(() => _draft = fn(_draft));

  void _applyPreset(PolicyPreset preset) => setState(() => _draft = preset.policy.toInput());

  Future<void> _save() async {
    if (_errors.isNotEmpty) return;
    setState(() => _saving = true);
    final ok = await widget.onSave(_draft);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _baseline = _draft;
    });
  }

  // Copy helpers: [TokenPolicyInput] is immutable.
  TokenPolicyInput _with({
    Object? accessTokenTtl = _keep,
    Object? refreshTokenMode = _keep,
    Object? refreshIdleTtl = _keep,
    Object? refreshAbsoluteTtl = _keep,
    Object? sessionMaxAge = _keep,
    bool? hasSessionMaxAge,
  }) {
    final d = _draft;
    return TokenPolicyInput(
      accessTokenTtl: identical(accessTokenTtl, _keep) ? d.accessTokenTtl : accessTokenTtl as int?,
      refreshTokenMode: identical(refreshTokenMode, _keep) ? d.refreshTokenMode : refreshTokenMode as RefreshTokenMode?,
      refreshIdleTtl: identical(refreshIdleTtl, _keep) ? d.refreshIdleTtl : refreshIdleTtl as int?,
      refreshAbsoluteTtl: identical(refreshAbsoluteTtl, _keep) ? d.refreshAbsoluteTtl : refreshAbsoluteTtl as int?,
      sessionMaxAge: identical(sessionMaxAge, _keep) ? d.sessionMaxAge : sessionMaxAge as int?,
      hasSessionMaxAge: hasSessionMaxAge ?? d.hasSessionMaxAge,
    );
  }

  /// Wraps a field with an "override" switch for client policies.
  Widget _field({
    required String title,
    required bool overridden,
    required String inheritedValue,
    required VoidCallback onOverride,
    required VoidCallback onInherit,
    required Widget child,
  }) {
    if (!widget.allowInherit) return child;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MergeSemantics(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(title),
            subtitle: Text(overridden ? 'Overridden for this client' : 'Inherits the app: $inheritedValue'),
            value: overridden,
            onChanged: widget.enabled ? (v) => v ? onOverride() : onInherit() : null,
          ),
        ),
        if (overridden) child else Divider(color: theme.colorScheme.outlineVariant),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _draft;
    final inh = widget.inherited;
    final eff = _effective;
    final noRefresh = eff.refreshTokenMode == RefreshTokenMode.none;
    final errors = _errors;
    final enabled = widget.enabled && !_saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Presets', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in PolicyPreset.all)
              Tooltip(
                message: p.description,
                child: ActionChip(
                  key: Key('preset.${p.name}'),
                  avatar: Icon(eff == p.policy ? Icons.check : Icons.tune, size: 18),
                  label: Text(p.name),
                  onPressed: enabled ? () => _applyPreset(p) : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),

        _field(
          title: 'Access token lifetime',
          overridden: d.accessTokenTtl != null,
          inheritedValue: formatSeconds(inh.accessTokenTtl),
          onOverride: () => _update((_) => _with(accessTokenTtl: inh.accessTokenTtl)),
          onInherit: () => _update((_) => _with(accessTokenTtl: null)),
          child: DurationField(
            key: const Key('policy.access'),
            label: 'Access token lifetime',
            seconds: eff.accessTokenTtl,
            enabled: enabled,
            units: const [DurationUnit.hours, DurationUnit.minutes],
            helperText:
                'How long an API token works. ${formatSeconds(PolicyBounds.accessMin)} to '
                '${formatSeconds(PolicyBounds.accessMax(widget.clientType))}.',
            errorText: _errorFor(PolicyField.accessTokenTtl),
            onChanged: (v) => _update((_) => _with(accessTokenTtl: v ?? 0)),
          ),
        ),
        const SizedBox(height: 16),

        _field(
          title: 'Refresh tokens',
          overridden: d.refreshTokenMode != null,
          inheritedValue: inh.refreshTokenMode.label,
          onOverride: () => _update((_) => _with(refreshTokenMode: inh.refreshTokenMode)),
          onInherit: () => _update((_) => _with(refreshTokenMode: null)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<RefreshTokenMode>(
                key: const Key('policy.mode'),
                segments: [for (final m in RefreshTokenMode.values) ButtonSegment(value: m, label: Text(m.label))],
                selected: {eff.refreshTokenMode},
                onSelectionChanged: enabled ? (s) => _update((_) => _with(refreshTokenMode: s.first)) : null,
              ),
              const SizedBox(height: 4),
              Text(eff.refreshTokenMode.description, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _field(
          title: 'Idle timeout',
          overridden: d.refreshIdleTtl != null,
          inheritedValue: formatSeconds(inh.refreshIdleTtl),
          onOverride: () => _update((_) => _with(refreshIdleTtl: inh.refreshIdleTtl)),
          onInherit: () => _update((_) => _with(refreshIdleTtl: null)),
          child: DurationField(
            key: const Key('policy.idle'),
            label: 'Idle timeout',
            seconds: eff.refreshIdleTtl,
            enabled: enabled && !noRefresh,
            helperText:
                'Signed out after this long without using the app. '
                '${formatSeconds(PolicyBounds.idleMin)} to ${formatSeconds(PolicyBounds.idleMax)}.',
            errorText: _errorFor(PolicyField.refreshIdleTtl),
            onChanged: (v) => _update((_) => _with(refreshIdleTtl: v ?? 0)),
          ),
        ),
        const SizedBox(height: 16),

        _field(
          title: 'Maximum session lifetime',
          overridden: d.refreshAbsoluteTtl != null,
          inheritedValue: formatSeconds(inh.refreshAbsoluteTtl),
          onOverride: () => _update((_) => _with(refreshAbsoluteTtl: inh.refreshAbsoluteTtl)),
          onInherit: () => _update((_) => _with(refreshAbsoluteTtl: null)),
          child: DurationField(
            key: const Key('policy.absolute'),
            label: 'Maximum session lifetime',
            seconds: eff.refreshAbsoluteTtl,
            enabled: enabled && !noRefresh,
            helperText:
                'Signed out this long after signing in, however active. '
                '${formatSeconds(PolicyBounds.absoluteMin)} to ${formatSeconds(PolicyBounds.absoluteMax)}.',
            errorText: _errorFor(PolicyField.refreshAbsoluteTtl),
            onChanged: (v) => _update((_) => _with(refreshAbsoluteTtl: v ?? 0)),
          ),
        ),
        const SizedBox(height: 16),

        _field(
          title: 'Force a fresh sign-in',
          overridden: d.hasSessionMaxAge,
          inheritedValue: inh.sessionMaxAge == null ? 'off' : formatSeconds(inh.sessionMaxAge!),
          onOverride: () => _update((_) => _with(sessionMaxAge: inh.sessionMaxAge, hasSessionMaxAge: true)),
          onInherit: () => _update((_) => _with(sessionMaxAge: null, hasSessionMaxAge: false)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MergeSemantics(
                child: SwitchListTile(
                  key: const Key('policy.maxAge.toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Session max age'),
                  subtitle: const Text(
                    'Ask users to sign in again when their sign-in is older than this, even if still signed in elsewhere.',
                  ),
                  value: eff.sessionMaxAge != null,
                  onChanged: enabled
                      ? (v) => _update(
                          (_) => _with(sessionMaxAge: v ? 12 * PolicyBounds.hour : null, hasSessionMaxAge: true),
                        )
                      : null,
                ),
              ),
              if (eff.sessionMaxAge != null)
                DurationField(
                  key: const Key('policy.maxAge'),
                  label: 'Session max age',
                  seconds: eff.sessionMaxAge,
                  enabled: enabled,
                  helperText: 'At least ${formatSeconds(PolicyBounds.sessionMaxAgeMin)}.',
                  errorText: _errorFor(PolicyField.sessionMaxAge),
                  onChanged: (v) => _update((_) => _with(sessionMaxAge: v ?? 0, hasSessionMaxAge: true)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('Result: ${eff.summary}', key: const Key('policy.summary')),
        ),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Fix ${errors.length == 1 ? 'the highlighted field' : '${errors.length} fields'} to save.',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        if (widget.enabled) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _dirty && !_saving ? () => setState(() => _draft = _baseline) : null,
                child: const Text('Reset'),
              ),
              const SizedBox(width: 8),
              BusyButton(
                key: const Key('policy.save'),
                busy: _saving,
                label: 'Save policy',
                onPressed: _dirty && errors.isEmpty ? _save : null,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

const _keep = Object();
