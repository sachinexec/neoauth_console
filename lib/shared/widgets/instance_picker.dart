import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/config.dart';
import '../../core/router.dart';

/// Switches to [instance] and starts over at its overview, or its sign-in
/// when there is no session there.
Future<void> switchInstance(BuildContext context, WidgetRef ref, ConsoleInstance instance) async {
  await ref.read(activeInstanceProvider.notifier).select(instance);
  if (context.mounted) GoRouter.maybeOf(context)?.go(Routes.overview);
}

/// A menu of the configured instances. Renders nothing when only the primary
/// instance is configured.
class InstancePicker extends ConsumerWidget {
  const InstancePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    if (!config.hasExtraInstances) return const SizedBox.shrink();
    final active = ref.watch(activeInstanceProvider);
    return PopupMenuButton<String>(
      key: const Key('instance.picker'),
      tooltip: 'Switch instance',
      initialValue: active.id,
      onSelected: (id) => switchInstance(context, ref, config.instanceById(id)),
      itemBuilder: (_) => [
        for (final i in config.instances)
          PopupMenuItem(
            key: Key('instance.${i.id}'),
            value: i.id,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(i.id == active.id ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(i.label),
              subtitle: Text(Uri.tryParse(i.issuer)?.host ?? i.issuer),
            ),
          ),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Switch'), Icon(Icons.arrow_drop_down)]),
      ),
    );
  }
}

/// A strip above [child] naming the instance every action goes to, with the
/// [InstancePicker]. Only [child] when only the primary instance is configured.
class InstanceBanner extends ConsumerWidget {
  const InstanceBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appConfigProvider).hasExtraInstances) return child;
    final active = ref.watch(activeInstanceProvider);
    final s = Theme.of(context).colorScheme;
    // The primary instance in the quiet colour; any other stands out.
    final (bg, fg) = active.isPrimary
        ? (s.secondaryContainer, s.onSecondaryContainer)
        : (s.tertiaryContainer, s.onTertiaryContainer);
    final host = Uri.tryParse(active.issuer)?.host ?? active.issuer;
    return Column(
      children: [
        Material(
          color: bg,
          child: SafeArea(
            bottom: false,
            child: IconTheme.merge(
              data: IconThemeData(color: fg),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: fg),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.dns_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          key: const Key('instance.current'),
                          TextSpan(
                            children: [
                              TextSpan(
                                text: active.label,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(text: '  $host'),
                            ],
                          ),
                          semanticsLabel: 'Instance: ${active.label}, $host',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const InstancePicker(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
        ),
      ],
    );
  }
}
