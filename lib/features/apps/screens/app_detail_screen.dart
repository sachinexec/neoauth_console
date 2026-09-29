import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/router.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../apps_repository.dart';
import '../widgets/app_clients_tab.dart';
import '../widgets/app_details_tab.dart';
import '../widgets/app_policy_tab.dart';
import '../widgets/app_providers_tab.dart';
import '../widgets/app_webhooks_tab.dart';

const appTabs = ['details', 'sign-in', 'policy', 'clients', 'webhooks'];

class AppDetailScreen extends ConsumerStatefulWidget {
  const AppDetailScreen({super.key, required this.slug, this.initialTab});
  final String slug;
  final String? initialTab;

  @override
  ConsumerState<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends ConsumerState<AppDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialIndex = appTabs.indexOf(widget.initialTab ?? '').clamp(0, appTabs.length - 1);
    _tabController = TabController(length: appTabs.length, initialIndex: initialIndex, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appDetailProvider(widget.slug));
    final canEdit = ref.watch(roleProvider).canEdit;
    final onClientsTab = appTabs[_tabController.index] == 'clients';
    return Scaffold(
      appBar: AppBar(
        title: Text(app.value?.name ?? widget.slug),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(appDetailProvider(widget.slug)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Details'),
            Tab(icon: Icon(Icons.login), text: 'Sign-in providers'),
            Tab(icon: Icon(Icons.timer_outlined), text: 'Token policy'),
            Tab(icon: Icon(Icons.key_outlined), text: 'Clients'),
            Tab(icon: Icon(Icons.webhook_outlined), text: 'Webhooks'),
          ],
        ),
      ),
      floatingActionButton: onClientsTab && canEdit
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.newClient(widget.slug)),
              icon: const Icon(Icons.add),
              label: const Text('New client'),
            )
          : null,
      body: AsyncValueView(
        value: app,
        onRetry: () => ref.invalidate(appDetailProvider(widget.slug)),
        data: (a) => TabBarView(
          controller: _tabController,
          children: [
            AppDetailsTab(app: a),
            AppProvidersTab(app: a),
            AppPolicyTab(app: a),
            AppClientsTab(app: a),
            AppWebhooksTab(app: a),
          ],
        ),
      ),
    );
  }
}
