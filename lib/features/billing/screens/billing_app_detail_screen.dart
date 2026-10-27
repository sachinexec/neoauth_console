import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../billing_repository.dart';
import '../widgets/billing_catalog_tab.dart';
import '../widgets/billing_customers_tab.dart';
import '../widgets/billing_developers_tab.dart';
import '../widgets/billing_events_tab.dart';
import '../widgets/billing_settings_tab.dart';

const billingAppTabs = ['settings', 'catalog', 'customers', 'events', 'developers'];

class BillingAppDetailScreen extends ConsumerStatefulWidget {
  const BillingAppDetailScreen({super.key, required this.slug, this.initialTab});
  final String slug;
  final String? initialTab;

  @override
  ConsumerState<BillingAppDetailScreen> createState() => _BillingAppDetailScreenState();
}

class _BillingAppDetailScreenState extends ConsumerState<BillingAppDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: billingAppTabs.length,
    initialIndex: billingAppTabs.indexOf(widget.initialTab ?? '').clamp(0, billingAppTabs.length - 1),
    vsync: this,
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(billingAppProvider(widget.slug));
    return Scaffold(
      appBar: AppBar(
        title: Text(app.value?.name ?? widget.slug),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(billingAppProvider(widget.slug)),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.tune), text: 'Settings'),
            Tab(icon: Icon(Icons.sell_outlined), text: 'Catalog'),
            Tab(icon: Icon(Icons.person_search_outlined), text: 'Customers'),
            Tab(icon: Icon(Icons.swap_vert), text: 'Events'),
            Tab(icon: Icon(Icons.code), text: 'Developers'),
          ],
        ),
      ),
      body: AsyncValueView(
        value: app,
        onRetry: () => ref.invalidate(billingAppProvider(widget.slug)),
        data: (a) => TabBarView(
          controller: _tabs,
          children: [
            BillingSettingsTab(app: a),
            BillingCatalogTab(slug: a.slug),
            BillingCustomersTab(slug: a.slug),
            BillingEventsTab(slug: a.slug),
            BillingDevelopersTab(slug: a.slug),
          ],
        ),
      ),
    );
  }
}
