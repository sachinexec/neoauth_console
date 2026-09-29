import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../shared/widgets/common.dart';
import '../apps_repository.dart';
import '../models/app_models.dart';
import 'login_methods_editor.dart';

/// Which sign-in methods the app offers (e.g. phone OTP only, or several).
class AppProvidersTab extends ConsumerStatefulWidget {
  const AppProvidersTab({super.key, required this.app});
  final AppModel app;

  @override
  ConsumerState<AppProvidersTab> createState() => _AppProvidersTabState();
}

class _AppProvidersTabState extends ConsumerState<AppProvidersTab> with AutomaticKeepAliveClientMixin {
  late Set<LoginMethod> _selected = widget.app.loginMethods.toSet();
  bool _saving = false;

  @override
  bool get wantKeepAlive => true;

  bool get _dirty => !_sameSet(_selected, widget.app.loginMethods.toSet());

  static bool _sameSet(Set<LoginMethod> a, Set<LoginMethod> b) => a.length == b.length && a.containsAll(b);

  @override
  void didUpdateWidget(AppProvidersTab old) {
    super.didUpdateWidget(old);
    // Take the fresh server value unless the admin has unsaved changes.
    if (!identical(old.app, widget.app) && _sameSet(_selected, old.app.loginMethods.toSet())) {
      _selected = widget.app.loginMethods.toSet();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = await runAction(
      context,
      () => ref.read(appsRepositoryProvider).setLoginMethods(widget.app.slug, _selected),
      success: 'Sign-in methods saved',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (updated != null) {
      _selected = updated.loginMethods.toSet();
      ref.invalidate(appDetailProvider(widget.app.slug));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final support = ref.watch(providerSupportProvider);
    final canEdit = ref.watch(roleProvider).canEdit;
    final overriding = widget.app.clients.where((c) => c.loginMethods != null).toList();

    return PageBody(
      children: [
        if (!canEdit) const ReadOnlyBanner(),
        SectionCard(
          title: 'Sign-in methods',
          subtitle:
              'Choose how people sign in to ${widget.app.name}. Clients can narrow this list, never extend it. '
              'A method must also be configured on the server to appear.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (support.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Couldn't check which methods the server supports.",
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              LoginMethodsEditor(
                selected: _selected,
                support: support.value,
                enabled: canEdit && !_saving,
                onChanged: (s) => setState(() => _selected = s),
              ),
              if (canEdit) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _dirty && !_saving
                          ? () => setState(() => _selected = widget.app.loginMethods.toSet())
                          : null,
                      child: const Text('Reset'),
                    ),
                    const SizedBox(width: 8),
                    BusyButton(onPressed: _dirty ? _save : null, busy: _saving, label: 'Save'),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (overriding.isNotEmpty)
          SectionCard(
            title: 'Client overrides',
            subtitle: 'These clients use their own subset of the methods above.',
            child: Column(
              children: [
                for (final c in overriding)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.name),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: MethodChips(methods: c.loginMethods!),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
