import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import 'async_value_view.dart';

/// A titled card grouping related fields.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(header: true, child: Text(title, style: theme.textTheme.titleMedium)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Centers content and caps its width on tablets.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 840, this.padding = const EdgeInsets.all(16)});
  final List<Widget> children;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 16), children[i]],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum ChipTone { neutral, success, warning, danger, info }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.tone = ChipTone.neutral, this.icon});

  /// active → green, disabled/suspended → warning, deleted → red.
  factory StatusChip.status(String status) => StatusChip(
    label: status[0].toUpperCase() + status.substring(1),
    tone: switch (status) {
      'active' => ChipTone.success,
      'disabled' || 'suspended' => ChipTone.warning,
      'deleted' || 'failing' => ChipTone.danger,
      _ => ChipTone.neutral,
    },
  );

  final String label;
  final ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      ChipTone.success => (s.successContainer, s.onSuccessContainer),
      ChipTone.warning => (s.warningContainer, s.onWarningContainer),
      ChipTone.danger => (s.errorContainer, s.onErrorContainer),
      ChipTone.info => (s.primaryContainer, s.onPrimaryContainer),
      ChipTone.neutral => (s.surfaceContainerHighest, s.onSurfaceVariant),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

/// A label/value row for detail screens.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.monospace = false});
  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(fontFamily: monospace ? 'monospace' : null),
            ),
          ),
        ],
      ),
    );
  }
}

/// A banner for viewers, explaining why controls are disabled.
class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: s.secondaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, color: s.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You have view-only access. Ask an owner for the admin role to make changes.',
              style: TextStyle(color: s.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  final s = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: error ? TextStyle(color: s.onErrorContainer) : null),
        backgroundColor: error ? s.errorContainer : null,
      ),
    );
}

/// Runs a mutation: shows [success] on completion, a friendly error otherwise.
/// Returns the result, or null when it failed.
Future<T?> runAction<T>(BuildContext context, Future<T> Function() action, {String? success}) async {
  try {
    final result = await action();
    if (context.mounted && success != null) showSnack(context, success);
    return result;
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, e.friendly, error: true);
  } catch (e) {
    if (context.mounted) showSnack(context, describeError(e), error: true);
  }
  return null;
}

/// A primary button that shows a spinner while [busy].
class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.onPressed, required this.label, this.busy = false, this.icon});
  final VoidCallback? onPressed;
  final String label;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : (icon != null ? Icon(icon) : null);
    return child == null
        ? FilledButton(onPressed: busy ? null : onPressed, child: Text(label))
        : FilledButton.icon(onPressed: busy ? null : onPressed, icon: child, label: Text(label));
  }
}
