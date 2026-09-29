import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../shared/widgets/common.dart';
import '../apps_repository.dart';
import '../models/app_models.dart';
import 'token_policy_editor.dart';

class AppPolicyTab extends ConsumerStatefulWidget {
  const AppPolicyTab({super.key, required this.app});
  final AppModel app;

  @override
  ConsumerState<AppPolicyTab> createState() => _AppPolicyTabState();
}

class _AppPolicyTabState extends ConsumerState<AppPolicyTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = widget.app;
    final canEdit = ref.watch(roleProvider).canEdit;
    final overrides = app.clients.where((c) => !c.tokenPolicyOverride.isEmpty).toList();
    return PageBody(
      children: [
        if (!canEdit) const ReadOnlyBanner(),
        SectionCard(
          title: 'Token policy',
          subtitle:
              'How long people stay signed in to ${app.name}. Applies to every client unless it overrides a field. '
              'Checked against public-client limits, since any client may be public.',
          child: TokenPolicyEditor(
            initial: app.tokenPolicy,
            inherited: TokenPolicy.defaults,
            enabled: canEdit,
            onSave: (policy) async {
              final updated = await runAction(
                context,
                () => ref.read(appsRepositoryProvider).setTokenPolicy(app.slug, policy),
                success: 'Token policy saved',
              );
              if (updated != null) ref.invalidate(appDetailProvider(app.slug));
              return updated != null;
            },
          ),
        ),
        if (overrides.isNotEmpty)
          SectionCard(
            title: 'Client overrides',
            subtitle: 'Effective policy for clients that override some fields.',
            child: Column(
              children: [
                for (final c in overrides)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.name),
                    subtitle: Text(c.effectiveTokenPolicy.summary),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
