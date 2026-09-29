import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/format.dart';
import '../../../shared/validators.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/copy_field.dart';
import '../../../shared/widgets/dialogs.dart';
import '../apps_repository.dart';
import '../models/app_models.dart';

class AppDetailsTab extends ConsumerStatefulWidget {
  const AppDetailsTab({super.key, required this.app});
  final AppModel app;

  @override
  ConsumerState<AppDetailsTab> createState() => _AppDetailsTabState();
}

class _AppDetailsTabState extends ConsumerState<AppDetailsTab> with AutomaticKeepAliveClientMixin {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController();
  late final _description = TextEditingController();
  late final _icon = TextEditingController();
  late final _marketing = TextEditingController();
  bool _saving = false;
  bool _toggling = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(widget.app);
    for (final c in [_name, _description, _icon, _marketing]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void didUpdateWidget(AppDetailsTab old) {
    super.didUpdateWidget(old);
    if (!identical(old.app, widget.app) && !_dirty) _load(widget.app);
  }

  void _load(AppModel a) {
    _name.text = a.name;
    _description.text = a.description ?? '';
    _icon.text = a.iconUrl ?? '';
    _marketing.text = a.marketingUrl ?? '';
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _icon, _marketing]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> get _changes {
    final a = widget.app;
    return {
      if (_name.text.trim() != a.name) 'name': _name.text.trim(),
      if (trimmedOrNull(_description.text) != a.description) 'description': trimmedOrNull(_description.text),
      if (trimmedOrNull(_icon.text) != a.iconUrl) 'icon_url': trimmedOrNull(_icon.text),
      if (trimmedOrNull(_marketing.text) != a.marketingUrl) 'marketing_url': trimmedOrNull(_marketing.text),
    };
  }

  bool get _dirty => _changes.isNotEmpty;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final updated = await runAction(
      context,
      () => ref.read(appsRepositoryProvider).update(widget.app.slug, _changes),
      success: 'Saved',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (updated != null) {
      _load(updated);
      ref.invalidate(appDetailProvider(widget.app.slug));
      ref.invalidate(appsListProvider);
    }
  }

  Future<void> _toggleStatus(bool active) async {
    final app = widget.app;
    if (!active) {
      final ok = await showConfirmDialog(
        context,
        title: 'Disable ${app.name}?',
        message:
            'Every client of this app stops working: nobody can sign in to it and its tokens are no longer accepted. '
            'You can enable it again later.',
        confirmLabel: 'Disable',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _toggling = true);
    final updated = await runAction(
      context,
      () => ref.read(appsRepositoryProvider).setStatus(app.slug, active: active),
      success: active ? 'App enabled' : 'App disabled',
    );
    if (!mounted) return;
    setState(() => _toggling = false);
    if (updated != null) {
      ref.invalidate(appDetailProvider(app.slug));
      ref.invalidate(appsListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = widget.app;
    final canEdit = ref.watch(roleProvider).canEdit;
    return Form(
      key: _form,
      child: PageBody(
        children: [
          if (!canEdit) const ReadOnlyBanner(),
          SectionCard(
            title: 'Identity',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CopyField(label: 'Slug', value: app.slug, dense: true),
                const SizedBox(height: 12),
                CopyField(label: 'API audience', value: app.apiAudience, dense: true),
                const SizedBox(height: 8),
                InfoRow(label: 'Created', value: formatDateTime(app.createdAt)),
                InfoRow(label: 'App ID', value: app.id, monospace: true),
              ],
            ),
          ),
          SectionCard(
            title: 'Listing',
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  enabled: canEdit,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _description,
                  enabled: canEdit,
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _icon,
                  enabled: canEdit,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Icon URL'),
                  validator: (v) => validateHttpUrl(v, required: false),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _marketing,
                  enabled: canEdit,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Marketing URL'),
                  validator: (v) => validateHttpUrl(v, required: false),
                ),
                if (canEdit) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _dirty && !_saving ? () => setState(() => _load(app)) : null,
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
          SectionCard(
            title: 'Status',
            child: MergeSemantics(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(app.isActive ? 'Enabled' : 'Disabled'),
                subtitle: Text(
                  app.isConsole
                      ? 'This is the console itself. It cannot be disabled.'
                      : app.isActive
                      ? 'Users can sign in to every active client of this app.'
                      : 'Sign-in and token refresh are blocked for all clients of this app.',
                ),
                value: app.isActive,
                onChanged: canEdit && !app.isConsole && !_toggling ? _toggleStatus : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
