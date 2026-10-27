import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../shared/widgets/common.dart';
import '../../../ui/bottom_inset.dart';
import '../billing_repository.dart';
import '../widgets/billing_widgets.dart';

/// Owner only: register an app with the billing service.
class BillingAppCreateScreen extends ConsumerStatefulWidget {
  const BillingAppCreateScreen({super.key});

  @override
  ConsumerState<BillingAppCreateScreen> createState() => _BillingAppCreateScreenState();
}

class _BillingAppCreateScreenState extends ConsumerState<BillingAppCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _slug = TextEditingController();
  final _name = TextEditingController();
  final _audience = TextEditingController();
  bool _binding = true;
  bool _transfer = false;
  bool _busy = false;

  @override
  void dispose() {
    _slug.dispose();
    _name.dispose();
    _audience.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final app = await runAction(
      context,
      () => ref
          .read(billingRepositoryProvider)
          .createApp(
            slug: _slug.text.trim(),
            name: _name.text.trim(),
            apiAudience: _audience.text.trim(),
            requireAccountBinding: _binding,
            allowRestoreTransfer: _transfer,
          ),
      success: 'App created',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (app == null) return;
    ref.invalidate(billingAppsProvider);
    context.go(Routes.billingApp(app.slug));
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(billingRoleProvider);
    if (!role.isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('New billing app')),
        body: const NeedsRole(role: 'owners', what: 'register apps'),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('New billing app')),
      body: Form(
        key: _form,
        child: PageBody(
          padding: const EdgeInsets.all(16).safeBottom(context),
          children: [
            TextFormField(
              key: const Key('billing.app.slug'),
              controller: _slug,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Slug',
                helperText: 'Lowercase letters, digits and dashes. Same as the NeoAuth app slug.',
                helperMaxLines: 2,
              ),
              validator: (v) => billingAppSlugPattern.hasMatch((v ?? '').trim())
                  ? null
                  : '2 to 40 lowercase letters, digits or dashes, starting with a letter or digit',
            ),
            TextFormField(
              key: const Key('billing.app.name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) {
                final t = (v ?? '').trim();
                return t.isEmpty || t.length > 100 ? 'Enter a name (up to 100 characters)' : null;
              },
            ),
            TextFormField(
              key: const Key('billing.app.audience'),
              controller: _audience,
              autocorrect: false,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'API audience',
                helperText: 'The `aud` of the NeoAuth access tokens this app sends, e.g. https://api.example.com',
                helperMaxLines: 3,
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                return t.length < 3 || t.length > 300 ? 'Enter the audience (3 to 300 characters)' : null;
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Require account binding'),
              subtitle: const Text('Reject purchases that are not tied to the signed-in user. Keep this on.'),
              value: _binding,
              onChanged: (v) => setState(() => _binding = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow restore to transfer purchases'),
              subtitle: const Text(
                'Lets a restore move a purchase to the restoring account. Only for apps whose old purchases carry no account token.',
              ),
              value: _transfer,
              onChanged: (v) => setState(() => _transfer = v),
            ),
            BusyButton(onPressed: _submit, label: 'Create app', busy: _busy),
          ],
        ),
      ),
    );
  }
}
