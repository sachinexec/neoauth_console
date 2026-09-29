import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/common.dart';
import '../apps_repository.dart';
import '../models/app_models.dart';
import 'login_methods_editor.dart';

/// Per-client sign-in methods: inherit the app's, or a custom subset.
class ClientMethodsSection extends ConsumerStatefulWidget {
  const ClientMethodsSection({super.key, required this.client, required this.app, required this.enabled});
  final ClientModel client;
  final AppModel? app;
  final bool enabled;

  @override
  ConsumerState<ClientMethodsSection> createState() => _ClientMethodsSectionState();
}

class _ClientMethodsSectionState extends ConsumerState<ClientMethodsSection> {
  late bool _custom;
  late Set<LoginMethod> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ClientMethodsSection old) {
    super.didUpdateWidget(old);
    if (!identical(old.client, widget.client) && !_dirty) _load();
  }

  Set<LoginMethod> get _appMethods => (widget.app?.loginMethods ?? LoginMethod.values).toSet();

  void _load() {
    final own = widget.client.loginMethods;
    _custom = own != null;
    _selected = own?.toSet() ?? _appMethods;
  }

  bool get _dirty {
    final own = widget.client.loginMethods;
    if (_custom != (own != null)) return true;
    if (!_custom) return false;
    return _selected.length != own!.length || !_selected.containsAll(own);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = await runAction(
      context,
      () => ref.read(appsRepositoryProvider).setClientLoginMethods(widget.client.clientId, _custom ? _selected : null),
      success: 'Sign-in methods saved',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (updated != null) refreshClient(ref, updated);
  }

  @override
  Widget build(BuildContext context) {
    final support = ref.watch(providerSupportProvider).value;
    final enabled = widget.enabled && !_saving;
    final appName = widget.app?.name ?? 'the app';
    return SectionCard(
      title: 'Sign-in methods',
      subtitle: 'Use the app\'s methods, or offer only some of them on this client.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Inherit app')),
              ButtonSegment(value: true, label: Text('Custom')),
            ],
            selected: {_custom},
            onSelectionChanged: enabled
                ? (s) => setState(() {
                    _custom = s.first;
                    if (_custom) {
                      final narrowed = _selected.intersection(_appMethods);
                      _selected = narrowed.isEmpty ? _appMethods : narrowed;
                    }
                  })
                : null,
          ),
          const SizedBox(height: 12),
          if (!_custom)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Same as $appName:'),
                const SizedBox(height: 6),
                MethodChips(methods: widget.app?.loginMethods ?? const []),
              ],
            )
          else
            LoginMethodsEditor(
              selected: _selected,
              support: support,
              allowed: _appMethods,
              notAllowedHint: 'Turned off for $appName. Enable it on the app first.',
              enabled: enabled,
              onChanged: (s) => setState(() => _selected = s),
            ),
          if (widget.enabled) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _dirty && !_saving ? () => setState(_load) : null, child: const Text('Reset')),
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
