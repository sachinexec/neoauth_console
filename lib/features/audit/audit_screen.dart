import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/router.dart';
import '../../shared/widgets/async_value_view.dart';
import '../admins/admins.dart' show uuidPattern;
import '../../shared/widgets/paged_list_view.dart';
import 'audit.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key, this.initialUserId, this.initialEvent});
  final String? initialUserId;
  final String? initialEvent;

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  late final _user = TextEditingController(text: widget.initialUserId);
  late AuditFilter _filter = (event: _blank(widget.initialEvent), userId: _blank(widget.initialUserId));
  late String _eventText = widget.initialEvent ?? '';
  String? _userError;

  static String? _blank(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

  @override
  void dispose() {
    _user.dispose();
    super.dispose();
  }

  void _apply() {
    final user = _blank(_user.text);
    if (user != null && !uuidPattern.hasMatch(user)) {
      setState(() => _userError = 'Enter a full user ID (UUID)');
      return;
    }
    setState(() {
      _userError = null;
      _filter = (event: _blank(_eventText), userId: user);
    });
  }

  void _clear() {
    _user.clear();
    setState(() {
      _eventText = '';
      _userError = null;
      _filter = (event: null, userId: null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = auditLogProvider(_filter);
    final filtered = _filter.event != null || _filter.userId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: Autocomplete<String>(
                      initialValue: TextEditingValue(text: _eventText),
                      optionsBuilder: (v) =>
                          AuditEvent.knownEvents.where((e) => e.contains(v.text.trim().toLowerCase())),
                      onSelected: (v) {
                        _eventText = v;
                        _apply();
                      },
                      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
                        controller: controller,
                        focusNode: focus,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Event',
                          hintText: 'e.g. user.suspended',
                          prefixIcon: Icon(Icons.filter_alt_outlined),
                          isDense: true,
                        ),
                        onChanged: (v) => _eventText = v,
                        onSubmitted: (_) => _apply(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: _user,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'User ID',
                        prefixIcon: const Icon(Icons.person_outline),
                        errorText: _userError,
                        isDense: true,
                      ),
                      onSubmitted: (_) => _apply(),
                    ),
                  ),
                  FilledButton.tonal(onPressed: _apply, child: const Text('Apply')),
                  if (filtered) TextButton(onPressed: _clear, child: const Text('Clear')),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: PagedListView<AuditEvent>(
              provider: provider,
              onRefresh: () => ref.read(provider.notifier).refresh(),
              onLoadMore: () => ref.read(provider.notifier).loadMore(),
              empty: EmptyView(
                title: filtered ? 'No matching events' : 'No events yet',
                icon: Icons.receipt_long_outlined,
              ),
              itemBuilder: (context, e) => AuditTile(event: e),
            ),
          ),
        ],
      ),
    );
  }
}

class AuditTile extends StatelessWidget {
  const AuditTile({super.key, required this.event});
  final AuditEvent event;

  IconData get _icon {
    final e = event.event;
    if (e.startsWith('admin.')) return Icons.shield_outlined;
    if (e.startsWith('user.')) return Icons.person_outline;
    if (e.startsWith('session.') || e.startsWith('grant.')) return Icons.devices_outlined;
    if (e.startsWith('token.')) return Icons.key_outlined;
    if (e.startsWith('attestation.')) return Icons.verified_user_outlined;
    return Icons.bolt_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = event;
    return ExpansionTile(
      leading: Icon(_icon),
      title: Text(e.event, style: const TextStyle(fontFamily: 'monospace')),
      subtitle: Text(
        [formatDateTime(e.at), if (e.clientId != null) e.clientId!].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (e.userId != null)
          Row(
            children: [
              Expanded(child: SelectableText('User ${e.userId}', style: theme.textTheme.bodySmall)),
              TextButton(onPressed: () => context.go(Routes.user(e.userId!)), child: const Text('Open user')),
            ],
          ),
        if (e.ip != null) SelectableText('IP ${e.ip}', style: theme.textTheme.bodySmall),
        if (e.userAgent != null) SelectableText(e.userAgent!, style: theme.textTheme.bodySmall),
        if (e.data.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(e.data),
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ],
    );
  }
}
