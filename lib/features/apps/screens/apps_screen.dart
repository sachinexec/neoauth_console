import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/router.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/common.dart';
import '../apps_repository.dart';
import '../models/app_models.dart';

class AppsScreen extends ConsumerWidget {
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(appsListProvider);
    final canEdit = ref.watch(roleProvider).canEdit;
    return Scaffold(
      appBar: AppBar(title: const Text('Apps')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => context.go(Routes.newApp),
              icon: const Icon(Icons.add),
              label: const Text('New app'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(appsListProvider.future),
        child: AsyncValueView(
          value: apps,
          onRetry: () => ref.invalidate(appsListProvider),
          isEmpty: (a) => a.isEmpty,
          empty: const EmptyView(
            title: 'No apps yet',
            message: 'An app groups the websites and mobile clients of one product.',
            icon: Icons.apps_outlined,
          ),
          data: (list) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: AppTile(app: list[i]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.iconUrl, this.radius = 20});
  final String name;
  final String? iconUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase();
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: s.primaryContainer,
      foregroundColor: s.onPrimaryContainer,
      child: Text(initials),
    );
    if (iconUrl == null || iconUrl!.isEmpty) return ExcludeSemantics(child: fallback);
    return ExcludeSemantics(
      child: ClipOval(
        child: Image.network(
          iconUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

class AppTile extends StatelessWidget {
  const AppTile({super.key, required this.app});
  final AppModel app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = app.clients.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: AppAvatar(name: app.name, iconUrl: app.iconUrl),
        title: Text(app.name),
        subtitle: Text(
          '${app.slug} · $n ${n == 1 ? 'client' : 'clients'}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (app.isConsole) const StatusChip(label: 'Console', tone: ChipTone.info),
            StatusChip.status(app.status),
          ],
        ),
        onTap: () => context.go(Routes.app(app.slug)),
      ),
    );
  }
}
