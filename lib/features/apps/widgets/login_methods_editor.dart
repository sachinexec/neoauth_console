import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../models/app_models.dart';

/// A switch per sign-in method. At least one must stay on: the last enabled
/// switch is locked. Each row says whether this server can run the method on
/// the web sign-in page and in native apps.
class LoginMethodsEditor extends StatelessWidget {
  const LoginMethodsEditor({
    super.key,
    required this.selected,
    required this.onChanged,
    this.support,
    this.allowed,
    this.enabled = true,
    this.notAllowedHint = 'Turned off for the app',
  });

  final Set<LoginMethod> selected;
  final ValueChanged<Set<LoginMethod>> onChanged;

  /// What the server is configured for; null while loading.
  final ProviderSupport? support;

  /// Methods that may be turned on (a client can only narrow its app's list).
  final Set<LoginMethod>? allowed;
  final bool enabled;
  final String notAllowedHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final m in LoginMethod.values) _row(context, m),
        if (support != null && selected.isNotEmpty && !selected.any((m) => support!.of(m).any))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _Hint(
              icon: Icons.warning_amber_rounded,
              text: 'None of the selected methods is configured on this server, so nobody could sign in.',
              warning: true,
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, LoginMethod m) {
    final theme = Theme.of(context);
    final on = selected.contains(m);
    final isLast = on && selected.length == 1;
    final isAllowed = allowed == null || allowed!.contains(m);
    final s = support?.of(m);
    final canToggle = enabled && !isLast && (isAllowed || on);

    String subtitle;
    if (!isAllowed) {
      subtitle = notAllowedHint;
    } else if (s == null) {
      subtitle = 'Checking server support…';
    } else if (!s.any) {
      subtitle = 'Not configured on this server. Users will not see it until it is set up.';
    } else if (!s.both) {
      subtitle = s.web
          ? 'Web sign-in only (not configured for native apps)'
          : 'Native apps only (not available on the web page)';
    } else {
      subtitle = 'Web and native apps';
    }

    return MergeSemantics(
      child: SwitchListTile(
        key: Key('method.${m.wire}'),
        contentPadding: EdgeInsets.zero,
        secondary: Icon(m.icon, color: on ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
        title: Text(m.label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if (s != null && isAllowed) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  _SurfaceTag(label: 'Web', supported: s.web),
                  _SurfaceTag(label: 'Native', supported: s.native),
                ],
              ),
            ],
            if (isLast && enabled)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'At least one method must stay on',
                  key: Key('method.${m.wire}.last'),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
          ],
        ),
        value: on,
        onChanged: canToggle
            ? (v) {
                final next = {...selected};
                v ? next.add(m) : next.remove(m);
                if (next.isEmpty) return;
                onChanged(next);
              }
            : null,
      ),
    );
  }
}

class _SurfaceTag extends StatelessWidget {
  const _SurfaceTag({required this.label, required this.supported});
  final String label;
  final bool supported;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final fg = supported ? s.success : s.onSurfaceVariant;
    return Semantics(
      label: '$label ${supported ? 'supported' : 'not supported'}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(supported ? Icons.check_circle_outline : Icons.remove_circle_outline, size: 14, color: fg),
          const SizedBox(width: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text, this.warning = false});
  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final bg = warning ? s.warningContainer : s.secondaryContainer;
    final fg = warning ? s.onWarningContainer : s.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: fg)),
          ),
        ],
      ),
    );
  }
}

/// Read-only chips of methods, e.g. a client's effective methods.
class MethodChips extends StatelessWidget {
  const MethodChips({super.key, required this.methods, this.emptyLabel = 'None'});
  final List<LoginMethod> methods;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (methods.isEmpty) {
      return Text(emptyLabel, style: TextStyle(color: Theme.of(context).colorScheme.error));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in methods)
          Chip(
            avatar: Icon(m.icon, size: 16),
            label: Text(m.label),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}
