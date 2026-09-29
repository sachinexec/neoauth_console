import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/common.dart';
import '../apps/apps_repository.dart';
import '../apps/models/app_models.dart';
import 'admins.dart';

/// Owner-only: users who opted in to hearing about our other apps, for
/// promoting one app to people who don't use it yet. Needs a recent sign-in.
class AudienceScreen extends ConsumerStatefulWidget {
  const AudienceScreen({super.key});

  @override
  ConsumerState<AudienceScreen> createState() => _AudienceScreenState();
}

class _AudienceScreenState extends ConsumerState<AudienceScreen> {
  String? _target;
  List<AudienceMember>? _members;
  bool _loading = false;

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await runAction(context, () => ref.read(adminsRepositoryProvider).audience(targetApp: _target));
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (list != null) _members = list;
    });
  }

  Future<void> _copyCsv() async {
    final rows = [
      'id,name,email,phone,apps',
      for (final m in _members!)
        [m.id, m.name ?? '', m.primaryEmail ?? '', m.phone ?? '', m.apps.join(' ')].map(_csv).join(','),
    ];
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (mounted) showSnack(context, '${_members!.length} rows copied as CSV');
  }

  static String _csv(String v) => v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(roleProvider).isOwner;
    final apps = ref.watch(appsListProvider);
    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Marketing audience')),
        body: const EmptyView(title: 'Owners only', icon: Icons.lock_outline),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketing audience'),
        actions: [
          if (_members != null && _members!.isNotEmpty)
            IconButton(tooltip: 'Copy as CSV', icon: const Icon(Icons.copy_all_outlined), onPressed: _copyCsv),
        ],
      ),
      body: PageBody(
        children: [
          SectionCard(
            title: 'Export',
            subtitle:
                'Only users who opted in to cross-app marketing. Pick an app to find people who do not use it yet. '
                'Exports are recorded in the audit log.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _target,
                  decoration: const InputDecoration(labelText: 'Promote app (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Any app')),
                    for (final a in apps.value ?? const <AppModel>[])
                      DropdownMenuItem(value: a.slug, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _target = v),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: BusyButton(onPressed: _load, busy: _loading, label: 'Load audience', icon: Icons.download),
                ),
              ],
            ),
          ),
          if (_members != null)
            SectionCard(
              title: '${_members!.length} people',
              child: _members!.isEmpty
                  ? const EmptyView(title: 'Nobody matches', icon: Icons.campaign_outlined)
                  : Column(
                      children: [
                        for (final m in _members!)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(m.name ?? m.primaryEmail ?? m.phone ?? m.id),
                            subtitle: Text([?m.primaryEmail, ?m.phone, 'uses ${m.apps.join(', ')}'].join(' · ')),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
