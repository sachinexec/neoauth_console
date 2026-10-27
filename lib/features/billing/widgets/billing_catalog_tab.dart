import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/common.dart';
import '../billing_models.dart';
import '../billing_repository.dart';

/// Entitlements, products and which products unlock which entitlements.
/// Admins can change them; viewers read.
class BillingCatalogTab extends ConsumerWidget {
  const BillingCatalogTab({super.key, required this.slug});
  final String slug;

  Future<void> _addEntitlement(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({String key, String name})>(
      context: context,
      builder: (_) => const _EntitlementDialog(),
    );
    if (result == null || !context.mounted) return;
    final created = await runAction(
      context,
      () => ref.read(billingRepositoryProvider).createEntitlement(slug, key: result.key, name: result.name),
      success: 'Entitlement added',
    );
    if (created != null) ref.invalidate(billingEntitlementsProvider(slug));
  }

  Future<void> _addProduct(BuildContext context, WidgetRef ref, List<BillingEntitlement> entitlements) async {
    final input = await showDialog<_ProductInput>(
      context: context,
      builder: (_) => _ProductDialog(entitlements: entitlements),
    );
    if (input == null || !context.mounted) return;
    final created = await runAction(
      context,
      () => ref
          .read(billingRepositoryProvider)
          .createProduct(
            slug,
            productSlug: input.slug,
            name: input.name,
            kind: input.kind,
            appleProductId: input.appleId,
            googleProductId: input.googleId,
            periodDays: input.periodDays,
            entitlements: input.entitlements,
          ),
      success: 'Product added',
    );
    if (created != null) ref.invalidate(billingProductsProvider(slug));
  }

  Future<void> _editProduct(BuildContext context, WidgetRef ref, BillingProduct p) async {
    final input = await showDialog<_ProductInput>(
      context: context,
      builder: (_) => _ProductDialog(entitlements: const [], editing: p),
    );
    if (input == null || !context.mounted) return;
    final saved = await runAction(
      context,
      () => ref
          .read(billingRepositoryProvider)
          .updateProduct(
            slug,
            p.slug,
            name: input.name,
            active: input.active,
            periodDays: input.periodDays,
            appleProductId: input.appleId,
            googleProductId: input.googleId,
            clearAppleId: input.appleId == null && p.appleProductId != null,
            clearGoogleId: input.googleId == null && p.googleProductId != null,
          ),
      success: 'Saved',
    );
    if (saved != null) ref.invalidate(billingProductsProvider(slug));
  }

  Future<void> _mapEntitlements(
    BuildContext context,
    WidgetRef ref,
    BillingProduct p,
    List<BillingEntitlement> all,
  ) async {
    final keys = await showDialog<List<String>>(
      context: context,
      builder: (_) => _MappingDialog(product: p, entitlements: all),
    );
    if (keys == null || !context.mounted) return;
    final saved = await runAction(
      context,
      () => ref.read(billingRepositoryProvider).setProductEntitlements(slug, p.slug, keys),
      success: 'Entitlements updated',
    );
    if (saved != null) ref.invalidate(billingProductsProvider(slug));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = ref.watch(billingRoleProvider).canEdit;
    final entitlements = ref.watch(billingEntitlementsProvider(slug));
    final products = ref.watch(billingProductsProvider(slug));
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(billingEntitlementsProvider(slug));
        ref.invalidate(billingProductsProvider(slug));
        await ref.read(billingProductsProvider(slug).future);
      },
      child: PageBody(
        children: [
          if (!canEdit) const ReadOnlyBanner(),
          SectionCard(
            title: 'Entitlements',
            subtitle: 'What a purchase unlocks in the app, e.g. "pro". Keys cannot be renamed or removed.',
            trailing: canEdit
                ? FilledButton.icon(
                    onPressed: () => _addEntitlement(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  )
                : null,
            child: AsyncValueView(
              value: entitlements,
              onRetry: () => ref.invalidate(billingEntitlementsProvider(slug)),
              isEmpty: (e) => e.isEmpty,
              empty: const Text('No entitlements yet.'),
              data: (list) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final e in list) Chip(label: Text('${e.key} · ${e.name}'))],
              ),
            ),
          ),
          SectionCard(
            title: 'Products',
            subtitle: 'One per store product. Map each to the entitlements it unlocks.',
            trailing: canEdit && entitlements.hasValue
                ? FilledButton.icon(
                    onPressed: () => _addProduct(context, ref, entitlements.requireValue),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  )
                : null,
            child: AsyncValueView(
              value: products,
              onRetry: () => ref.invalidate(billingProductsProvider(slug)),
              isEmpty: (p) => p.isEmpty,
              empty: const Text('No products yet.'),
              data: (list) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final p in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(p.name, style: theme.textTheme.titleSmall)),
                                  if (canEdit) ...[
                                    IconButton(
                                      tooltip: 'Edit ${p.name}',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _editProduct(context, ref, p),
                                    ),
                                    IconButton(
                                      tooltip: 'Entitlements of ${p.name}',
                                      icon: const Icon(Icons.link),
                                      onPressed: entitlements.hasValue
                                          ? () => _mapEntitlements(context, ref, p, entitlements.requireValue)
                                          : null,
                                    ),
                                  ],
                                ],
                              ),
                              SelectableText(
                                p.slug,
                                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  StatusChip(label: p.kind.label),
                                  StatusChip(
                                    label: p.active ? 'Active' : 'Inactive',
                                    tone: p.active ? ChipTone.success : ChipTone.warning,
                                  ),
                                  if (p.periodDays != null) StatusChip(label: '${p.periodDays} days'),
                                  for (final k in p.entitlements)
                                    StatusChip(label: k, tone: ChipTone.info, icon: Icons.lock_open),
                                  if (p.entitlements.isEmpty)
                                    const StatusChip(label: 'Unlocks nothing', tone: ChipTone.warning),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Apple: ${p.appleProductId ?? '—'}', style: theme.textTheme.bodySmall),
                              Text('Google: ${p.googleProductId ?? '—'}', style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntitlementDialog extends StatefulWidget {
  const _EntitlementDialog();

  @override
  State<_EntitlementDialog> createState() => _EntitlementDialogState();
}

class _EntitlementDialogState extends State<_EntitlementDialog> {
  final _form = GlobalKey<FormState>();
  final _key = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _key.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add entitlement'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('entitlement.key'),
              controller: _key,
              autofocus: true,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Key',
                hintText: 'pro',
                helperText: 'What the app checks. Lowercase, no spaces.',
              ),
              validator: (v) =>
                  billingKeyPattern.hasMatch((v ?? '').trim()) ? null : 'Lowercase letters, digits, . _ - (up to 64)',
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('entitlement.name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'Pro'),
              validator: (v) {
                final t = (v ?? '').trim();
                return t.isEmpty || t.length > 100 ? 'Enter a name (up to 100 characters)' : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.of(context).pop((key: _key.text.trim(), name: _name.text.trim()));
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

typedef _ProductInput = ({
  String slug,
  String name,
  ProductKind kind,
  String? appleId,
  String? googleId,
  int? periodDays,
  bool active,
  List<String> entitlements,
});

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({required this.entitlements, this.editing});
  final List<BillingEntitlement> entitlements;

  /// Null when adding.
  final BillingProduct? editing;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _form = GlobalKey<FormState>();
  late final _slug = TextEditingController(text: widget.editing?.slug);
  late final _name = TextEditingController(text: widget.editing?.name);
  late final _apple = TextEditingController(text: widget.editing?.appleProductId);
  late final _google = TextEditingController(text: widget.editing?.googleProductId);
  late final _period = TextEditingController(text: widget.editing?.periodDays?.toString());
  late ProductKind _kind = widget.editing?.kind ?? ProductKind.subscription;
  late bool _active = widget.editing?.active ?? true;
  final _keys = <String>{};

  bool get _editing => widget.editing != null;

  @override
  void dispose() {
    _slug.dispose();
    _name.dispose();
    _apple.dispose();
    _google.dispose();
    _period.dispose();
    super.dispose();
  }

  String? _blankToNull(String s) => s.trim().isEmpty ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Edit product' : 'Add product'),
      // bottom-inset-ok: dialog content, not the bottom edge of the window
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('product.slug'),
                controller: _slug,
                enabled: !_editing,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Slug',
                  helperText: 'Stable id used by the app and in events.',
                ),
                validator: (v) =>
                    billingSlugPattern.hasMatch((v ?? '').trim()) ? null : 'Lowercase letters, digits, _ - (up to 64)',
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('product.name'),
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  return t.isEmpty || t.length > 100 ? 'Enter a name (up to 100 characters)' : null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ProductKind>(
                initialValue: _kind,
                decoration: InputDecoration(labelText: 'Kind', helperText: _editing ? 'Cannot be changed.' : null),
                items: [for (final k in ProductKind.values) DropdownMenuItem(value: k, child: Text(k.label))],
                onChanged: _editing ? null : (k) => setState(() => _kind = k ?? _kind),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('product.apple'),
                controller: _apple,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Apple product ID'),
                validator: (v) => (v ?? '').trim().length > 200 ? 'Too long' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('product.google'),
                controller: _google,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Google product ID'),
                validator: (v) => (v ?? '').trim().length > 200 ? 'Too long' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('product.period'),
                controller: _period,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Billing period (days)',
                  helperText: '30, 365 ... Used for MRR.',
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  final n = int.tryParse(t);
                  return n == null || n < 1 || n > 3660 ? '1 to 3660' : null;
                },
              ),
              if (_editing)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text('Inactive products are hidden from apps. Existing purchases keep working.'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                )
              else if (widget.entitlements.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Unlocks', style: Theme.of(context).textTheme.labelLarge),
                for (final e in widget.entitlements)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _keys.contains(e.key),
                    title: Text(e.name),
                    subtitle: Text(e.key, style: const TextStyle(fontFamily: 'monospace')),
                    onChanged: (v) => setState(() => v == true ? _keys.add(e.key) : _keys.remove(e.key)),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.of(context).pop((
              slug: _slug.text.trim(),
              name: _name.text.trim(),
              kind: _kind,
              appleId: _blankToNull(_apple.text),
              googleId: _blankToNull(_google.text),
              periodDays: int.tryParse(_period.text.trim()),
              active: _active,
              entitlements: _keys.toList(),
            ));
          },
          child: Text(_editing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class _MappingDialog extends StatefulWidget {
  const _MappingDialog({required this.product, required this.entitlements});
  final BillingProduct product;
  final List<BillingEntitlement> entitlements;

  @override
  State<_MappingDialog> createState() => _MappingDialogState();
}

class _MappingDialogState extends State<_MappingDialog> {
  late final _keys = widget.product.entitlements.toSet();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Unlocks · ${widget.product.name}'),
      // bottom-inset-ok: dialog content, not the bottom edge of the window
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Buying this product grants exactly the checked entitlements. Existing buyers are updated.'),
            for (final e in widget.entitlements)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _keys.contains(e.key),
                title: Text(e.name),
                subtitle: Text(e.key, style: const TextStyle(fontFamily: 'monospace')),
                onChanged: (v) => setState(() => v == true ? _keys.add(e.key) : _keys.remove(e.key)),
              ),
            if (widget.entitlements.isEmpty) const Text('Add an entitlement first.'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(widget.entitlements.map((e) => e.key).where(_keys.contains).toList()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
